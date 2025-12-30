# lib/alloc.s - Memory allocation utilities

.include	"common.inc"
.include	"linux.inc"

.globl	alloc, free, realloc

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

# @function	alloc
# @public
# @description	Request a block of memory
# @param	%rdi	Size (in bytes) of the requested memory
# @return	%rax	Pointer to the allocated memory or NULL if there is no memory left
.type	alloc, @function
alloc:
	push	%rbp
	push	%rbx
	mov	%rsp, %rbp

	# Store requested bytes somewhere less volatile
	mov	%rdi, %rbx

	# Check for a bad request (e.g. request less than 1 byte) and return NULL if so
	mov	$NULL, %rax
	cmp	$1, %rdi
	jl	7f

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
	# Calculate/retrieve updated block values. We will return the head end to the user
	mov	Header.size(%rax), %rsi		# Move header size into %rsi for subtraction
	sub	%rbx, %rsi			# Calculate the new size
	mov	Header.next(%rax), %rcx		# Retrieve the next pointer of the block

	mov	%rax, %r8			# Leave the return value for user block in %rax 
	add	%rbx, %r8			# Increment %r8 to the new location
	mov	%rcx, Header.next(%r8)		# Set the next
	mov	%rsi, Header.size(%r8)		# Set the size
	mov	%r8, Header.next(%rdx)		# Link to the free list

	mov	%rbx, Header.size(%rax)		# Set the size on the user returned block

6:
	mov	%rdx, freep			# Store where we left off searching in freep
	add	$HEADER_SIZE, %rax		# Increment the returned pointer past the header
						# i.e. point it to the "useable" memory
7:
	mov	%rbp, %rsp
	pop	%rbx
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
	mov	%rbx, %rdi
	call	morecore

	cmp	$NULL, %rax			# Check if the operation failed
	je	7b

	jmp	3b

# @function	free
# @public
# @description	Free previously allocated memory and coallesce it into the "free list"
# @param	%rdi	Memory address of the block to free
# @return	void
.type	free, @function
free:
	push	%rbp
	mov	%rsp, %rbp

	sub	$HEADER_SIZE, %rdi	# Point %rdi at start of our block's header

	# Puts the reference block (i.e. the block in the free list sequence that precedes ours)
	# into %rax
	call	find_in_free_list

	# Put the "next" (i.e. the block that follows ours) in %rdx
	mov	Header.next(%rax), %rdx

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

# @function	realloc
# @public
# @description	Resize a block previously returned by alloc and attempt to perform the resizing in
#		place. If this is not possible allocate a new region and copy the contents of old
#		to new
# @param	%rdi	The address of the block
# @param	%rsi	The new size
# @return	%rax	The address of the resized block
.type	realloc, @function
realloc:
	push	%rbp
	mov	%rsp, %rbp

	push	%rbx
	push	%r12
	push	%r13
	push	%r14

	# Update the requested bytes to include size for a header and to be a multiple of header 
	# size. This uses a bit twiddle to transform the value to a multiple of the header size
	add	$(2 * HEADER_SIZE - 1), %rsi	# Add space for a header and header - 1 for bit op
	and	$~(HEADER_SIZE - 1), %rsi	# Bitwise trick (NOT with header - 1)

	sub	$HEADER_SIZE, %rdi	# Point %rdi at start of our block's header
	mov	%rdi, %rbx		# Store out block's address somewhere less volatile
	mov	%rsi, %r14		# Store the requested size somewhere less volatile

	# Check to see if the requested size matches the current size (no-op) or if the requested
	# size is less than the current size
	mov	%rsi, %r13		# Move the request to %r13 because %rsi gets clobbered
	mov	Header.size(%rbx), %r12
	cmp	%r12, %r13
	je	3f
	jl	5f

	# This is an UPSIZE operation. Update %r13 to hold the "differential"
	sub	%r12, %r13

	# Check if we are up against the system break. If so we can resize in-place if we request
	# more memory first ...
	add	%r12, %rdi
	cmp	break, %rdi
	jge	6f

1:
	# Puts the reference block (i.e. the block in the free list sequence that precedes ours)
	# into %rax
	mov	%rbx, %rdi
	call	find_in_free_list

	# Moves the address of the adjoining block into %r9
	mov	Header.next(%rax), %r9

	# Check if our block borders the "next". Adds the size of our block to its address and 
	# compares the result with "next"
	add	%rbx, %r12
	cmp	%r9, %r12
	jne	2f

	# Our block borders next, next we need to  ensure there is sufficient size to complete the
	# operation. There are three outcomes to track here:
	# Block is too small, so we need to request more space anyhow
	# Block is EXACTLY the correct size, so we need to unlink it
	# Block has ample room so we need to resize it can merge the head end with our block
	mov	Header.size(%r9), %rdx
	cmp	%r13, %rdx
	jl	2f
	je	7f

	# Next we will merge the two blocks. First we update "next" ...
	mov	Header.next(%r9), %rcx	# We need to preserve the "next" pointer of "next"
	mov	Header.size(%r9), %rdx	# Preserve the size 
	sub	%r13, %rdx		# Subtract the differential from the "next" blocks size

	add	%r13, %r9		# Increment/decrement "next" according to the differential
	mov	%rcx, Header.next(%r9)	# Reapply the "next" pointer to "next
	mov	%rdx, Header.size(%r9)	# Reapply the "size" pointer to "next"
	mov	%r9, Header.next(%rax)	# Update the prev block to point to new location for "next"

	# Last we will apply the differential to our blocks size
	add	%r13, Header.size(%rbx)
	jmp	3f

# Either our block is NOT immediately followed by "next" or the "next" has insufficient space which 
# means an "in-place" resize is not possible
2: 
	# Call alloc to obtain the new space
	mov	%r14, %rdi
	call	alloc

	# %rcx already holds the size of our block. To use rep movsb only requires us to set source
	# and destination
	mov	%rbx, %rsi		# Source
	mov	%rax, %rdi		# Destination
	rep	movsb

	mov	%rax, %rbx		# Put the destination into %rax which is expected 
3:
	# Increment the pointer returned to the user back past the header and put return in %rax
	add	$HEADER_SIZE, %rbx
	mov	%rbx, %rax

4:
	# Restore registers
	pop	%r14
	pop	%r13
	pop	%r12
	pop	%rbx

	mov	%rbp, %rsp
	pop	%rbp
	ret

# Downsize operation. If we get here we know that the requested memory in %rsi is less than the
# size in %r8
5:
	# Obtain the differential
	sub	%r14, %r12

	# Update the size of our block
	mov	%r14, Header.size(%rbx)

	# Create a small block using the freed space and call free to merge it with the list
	mov	%rbx, %rdi		# Start with the address of our block ...
	add	%r14, %rdi		# And add our blocks size, %rdi now points at the new area
	mov	%r12, Header.size(%rdi)	# Give the new area a size

	# Call free to join it with the free list
	add	$HEADER_SIZE, %rdi	# Free expects the value past the header
	call	free

	# Jump to function end
	jmp	3b

# If we are here it means we can achieve an "in-place" resizing if we request more memory from the
# OS first ...
6:
	mov	%r13, %rdi

	call	morecore

	cmp	$NULL, %rax			# Check if the operation failed
	je	4b				# Return early if so

	jmp	1b				# Otherwise, resume the search ...

# An adjacent block exists with EXACTLY the correct amount of space and it merely needs to be 
# unlinked from the free list and merged into our block
7:
	mov	Header.next(%r9), %rcx		# Retrieve the next of %r9
	mov	%rcx, Header.next(%rax)		# Update the previous to unlink %r9
	mov	%r14, Header.size(%rbx)		# Update the size of our block

	jmp	3b

# @function	morecore
# @private
# @description	Request a chunk of memory from the operating system and update the system break
# @param	%rdi	The size of the requested chunk
# @return	%rax	The address of the free pointer or NULL if the operation failed
morecore:
	push	%rbp
	mov	%rsp, %rbp

	# Check the request against the minimum number of bytes and increase if necessary
	mov	$NALLOC, %rax		# This is necessary because we cannot cmovcc an immediate
	cmp	%rax, %rdi
	cmovb	%rax, %rdi

	# Preserve the requested bytes so we can set the size of our new block later as "free" 
	# requires %rdi to be a pointer to the region
	mov	%rdi, %rdx

	# Request the new break, add the requested size to the old break in rdi
	mov	$SYS_BRK, %rax
	add	break, %rdi
	syscall

	# SYS_BREAK returns negative one in the error case so we need to check for that and cast
	# %rax to NULL if this is so
	mov	$NULL, %rsi		# Necessary because we cannot cmovcc an immediate
	cmp	$-1, %rax
	cmove	%rsi, %rax
	je	1f

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

	# Return the free pointer, mostly so that the caller can determine if the op was successful
	mov	freep, %rax
1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	find_in_free_list
# @private
# @description	Find the preceding block in the free list for the specified allocation
# @param	%rdi	The address of a block previously returned by alloc
# @return	%rax	The address of the immediately preceeding block in the "free list"
find_in_free_list:
	push	%rbp
	mov	%rsp, %rbp

	# Setup for main loop, %rax holds the address of the free pointer, %rdx holds the "next"
	mov	freep, %rax
	mov	Header.next(%rax), %rdx

	# Jump to loop conditional
	jmp 1f

# Loop body. Checks to see if our block is at the beginning or end of the list
2:
	# Checks to see if the free pointer is less than the "next" pointer, if so the loop should
	# continue
	cmp	%rdx, %rax
	jl	3f

	# If we arrive here it is because the free pointer is greater than (or equal to) the next
	# which indicates the end of the list. We next check if our block is greater than the free
	# pointer (i.e. at the end of the list)
	cmp	%rax, %rdi
	jg	4f

	# Our block is not greater than the free pointer, so next we check if it is less than the
	# "next" pointer, which in this case is the beginning of the list
	cmp	%rdx, %rdi
	jl	4f

# Setup for the next loop iteration. Increments the free pointer and the next
3:
	mov	%rdx, %rax
	mov	Header.next(%rax), %rdx

# Loop conditional. Checks if our block is after the current free pointer and before its "next"
1:
	# Check to see if our block less than (or equal to) the free pointer, in which case the
	# loop should continue
	cmp	%rax, %rdi
	jle	2b

	# Check to see if our block is greater than (or equal to) the "next" pointer, in which case
	# the loop should continue
	cmp	%rdx, %rdi
	jge	2b
	
# Our block is found in %rax so we can return
4:
	mov	%rbp, %rsp
	pop	%rbp
	ret
