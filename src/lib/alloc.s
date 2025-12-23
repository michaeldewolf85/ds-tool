# lib/alloc.s - Memory allocation utilities

.include	"common.inc"
.include	"linux.inc"

.globl	alloc, free

# Private
# Minimum bytes to request from SYS_BREAK
.equ	NALLOC, 1<<8			# 256 bytes

# Header for "alloc" memory block - 16 bytes
	.struct	0
Header.next:
	.struct	Header.next + 1<<3	# Pointer to next free block
Header.size:
	.struct	Header.size + 1<<3	# Size of the block
	.equ	HEADER_SIZE, .

.section .bss
.align	16

# Base of the block list. Declared with zeroes and initialized when "alloc" is first called
base:
	.zero	HEADER_SIZE

# Pointer to the "free list"
freep:
	.skip	1<<3

# Current system break
break:
	.skip	1<<3

.section .text

# Request a block of memory
# @param	%rdi	Size (in bytes) of the requested memory
# @return	%rax	Pointer to the allocated memory or NULL if there is no memory left
.type	alloc, @function
alloc:
	push	%rbp
	mov	%rsp, %rbp

	# Store requested bytes somewhere less volatile
	mov	%rdi, %rbx

	# Update the requested bytes to include size for a header and to be a multiple of header 
	# size. This uses a bit twiddle to transform the value to a multiple of the header size
	add	$(2 * HEADER_SIZE - 1), %rbx	# Add space for a header and header - 1 for bit op
	and	$~(HEADER_SIZE - 1), %rbx	# Bitwise trick (NOT with header - 1)

	# Checks to see if alloc has already been initialized
	cmpq	$0, base
	je	init

# Initialize vars for main loop
# %rax will be current block
# %rdx will be the previous block
1:
	mov	freep, %rdx			# Previous block initialized to the free pointer
2:
	mov	Header.next(%rdx), %rax		# Put current block being evaluated in %rax

	# Check current block for enough space. There are three scenarios to track here: more than
	# enough space, exactly enough space or not enough space
	# space, exactly enough space or more than enough space
	cmp	%rbx, Header.size(%rax)
	je	unlink
	jg	resize

	# If the current is equal to the free list pointer it means we have exhausted our search
	# and need to request more memory
	cmp	freep, %rax
	je	more

# Prepare for next loop iteration: set "previous" to "current"
3:
	mov	%rax, %rdx			# Set "previous" to "current"
	jmp	2b

# The current block has exactly the correct amount of space in which case we will unlink it from 
# the "free list" and return it
unlink:
	# Exact size match, unlink this block from the free list
	mov	Header.next(%rax), %rsi		# Move the "next" block's address into %rsi
	mov	%rsi, Header.next(%rdx)		# Set the "prev" block to point to the "next"
	jmp	6f				# effectively removing the current from rotation

# The current block as more than enough space in which case we will shrink it and a chunk at the 
# tail end to the caller
resize:
	# Block is greater than needed so we resize it and return the tail end
	mov	Header.size(%rax), %rsi		# Move header size into %rsi for subtraction
	sub	%rbx, %rsi			# Calculate the new size
	mov	%rsi, Header.size(%rax)		# Store the new size for the free block
	add	%rsi, %rax			# Move %rax pointer to the memory we will return
	mov	%rbx, Header.size(%rax)		# Set the size on the returned block

6:
	mov	%rdx, freep			# Store where we left off searching in freep
	add	$HEADER_SIZE, %rax		# Increment the returned pointer past the header
						# i.e. point it to the "useable" memory
7:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# Initialize alloc (if this is the first time it is being called)
init:
	movq	$base, base + Header.next	# Point the base pointer at itself
	movq	$base, freep			# Point the free pointer at the base

	# Obtains the current system break by calling SYS_BRK with 0
	mov	$SYS_BRK, %rax
	mov	$0, %rdi
	syscall	

	mov	%rax, break			# Store the location of the break
	jmp	1b

# Request more memory from the OS
more:
	# Move requested bytes into %rdx to manipulate it
	mov	%rbx, %rdi

	# Check the request against the minimum number of bytes and increase if necessary
	mov	$NALLOC, %rdx
	cmp	%rdx, %rdi
	cmovb	%rdx, %rdi

	# Preserve the requested bytes as we will need it later ...
	mov	%rdi, %rdx

	# Request the new break, add the requested size to the old break in rdi
	mov	$SYS_BRK, %rax
	add	break, %rdi
	syscall

	# SYS_BREAK returns negative one in the error case so we need to check for that and cast
	# %rax to NULL if this is so
	mov	$NULL, %rsi		# Necessary because we cannot cmov an immediate
	cmp	$-1, %rax
	cmove	%rsi, %rax
	je	7b

	# The old system break is the pointer to our new memory block. We move that into %rdi in
	# preparation for a call to free
	mov	break, %rdi

	# Update our break to the new value. We need to do this AFTER storing the old in %rdi
	mov	%rax, break

	# Set the "size" our new block in its header and increment the pointer to the useable
	# memory which is what "free" expects to receive. Call free which will insert the
	# block into the "free list". Finally return back to the scan loop so that the new block
	# can be discovered
	mov	%rdx, Header.size(%rdi)
	add	$HEADER_SIZE, %rdi
	call	free
	jmp	3b

# Free previously allocated memory and coallesce it into the "free list"
# @param	%rdi	Memory address of the block to free
# @return	Returns no value
.type	free, @function
free:
	push	%rbp
	mov	%rsp, %rbp

	sub	$HEADER_SIZE, %rdi	# Point %rdi at start of our block's header

	mov	freep, %rax		# Initialize %rax to the start of the "free list"

# Finds the preceding block in the "free list"
# %rax is the current block 
# %rdx is the next
1:
	mov	Header.next(%rax), %rdx	# Move "next" into %rdx

	# Checks if our block is less than or equal to the current. If it is we can skip the next
	# check
	cmp	%rax, %rdi
	jle	2f

	# If we are here, our block is greater than the current. If it is less than the next we
	# found our spot
	cmp	%rdx, %rdi
	jl	check_next

# We have not found our spot yet. We need to check if the "current" is the end of the list and if
# so, our block may preceed or succeed the list
2:
	# Checks if "current" is greater than the "next" it points to which means end of list
	cmp	%rdx, %rax
	jge	end_of_list

# Tee up the next iteration of the loop
3:
	mov	Header.next(%rax), %rax
	jmp	1b

# We've found our block in %rax. Next we need to insert it into the free list
check_next:
	# Put the end of our block in %rsi
	mov	%rdi, %rsi
	add	Header.size(%rdi), %rsi

	# Check if the end of out block adjoins with the "next" and join it with "next" if so
	cmp	%rdx, %rsi
	je	adjoin_next

	# If out block does not adjoin with "next" it should point at the "next" of current
	mov	%rdx, Header.next(%rdi)

# Check if our block adjoins with "current" and join it with "current" if so
check_prev:
	cmp	%rdi, %rax
	je	adjoin_prev

	# If our block does not adjoin "current" then current should point to our block
	mov	%rdi, Header.next(%rax)

# Done adding freed block to the "free list"
3:
	# Move the free pointer to the current block since we know there is now a free block after
	# it
	mov	%rax, freep

	mov	%rbp, %rsp
	pop	%rbp
	ret

# We are at the end of the list (ie it wraps around). We need to check if out block is either 
# BEFORE or AFTER the list
end_of_list:
	# Our block is BEFORE the "next" (which is the start of the list)
	cmp	%rdx, %rdi
	jl	check_next

	# Our block is AFTER the current (which is the end of the list)
	cmp	%rax, %rdi
	jg	check_next

	# Our block is somewhere in the middle of the list
	jmp	3b

# Our block adjoins with "next" (which is in %rsi) so we need to join the two
adjoin_next:
	# Puts the size of the "next" block in %rdx and adds that value to the size of our block
	mov	Header.size(%rsi), %rdx
	add	%rdx, Header.size(%rdi)

	# Move the "next" pointer of the "next" block into our block to complete the merge
	mov	Header.next(%rsi), %rdx
	mov	%rdx, Header.next(%rdi)
	jmp	check_prev

# Our block adjoins with "current" so we need to join the two
adjoin_prev:
	# Moves the size of our block into %rdx and adds it to the size of the "current"
	mov	Header.size(%rdi), %rdx
	add	%rdx, Header.size(%rax)

	# Moves the "next" pointer of our block to be the "next" pointer of "the current"
	mov	Header.next(%rdi), %rdx
	mov	%rdx, Header.next(%rax)
	jmp	3b
