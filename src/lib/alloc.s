# lib/alloc.s - Memory allocation utilities

.include	"linux.inc"

.globl	alloc, free, realloc

# Private struct (used only in this file)
	.struct	0
Header.next:
	.struct	Header.next + 1<<3	# Pointer to next block
Header.size:
	.struct	Header.size + 1<<3	# Size of this block
	.equ	HEADER_SIZE, .

.equ	MIN_BRK_REQ, 1<<7			# Min break request (256 bytes) to save on syscalls

.section .bss

base:
	.zero	HEADER_SIZE	# Reserved space for the base of the list

freep:
	.zero	HEADER_SIZE	# Reserved space to keep track of where we stopped searching last

break:
	.zero	1<<3		# Reserved space to track the current location of the break

.section .text

# Request a block of memory
# @param	%rdi	Size (in bytes) of the requested memory
# @return	%rax	Pointer to the allocated memory or NULL if there is no memory left
.type	alloc, @function
alloc:
	push	%rbp
	mov	%rsp, %rbp

	# Determine the size needed for the requested space (in header size multiples). Note that 
	# this can use a bitwise trick to round to the nearest multiple of the header size as it is
	# a multiple of 2
	add	$(2 * HEADER_SIZE - 1), %rdi	# Add space for a header and the aligment
	and	$~(HEADER_SIZE - 1), %rdi	# Bitwise trick

	# Checks to see if the base has already been initialized or if this is the first call
	cmpq	$0, base
	jne	.Lstart

	mov	%rdi, %r12			# Save %rdi in %r12 for safekeeping. TODO 
	call	alloc_init

	mov	%r12, %rdi
.Lstart:
	# We will use %rcx to represent the previous block and %rax to represent the current block
	movq	freep, %rcx			# previous pointer, address of previous block

.Lscan:
	movq	Header.next(%rcx), %rax		# Move the next (current) block into %rax

	# Check current block for space
	cmp	%r12, Header.size(%rax)		# Check size against the memory requested
	je	.Lexact
	jg	.Lresize

	cmpq	freep, %rax			# Check if we are back at freep, if so we exhausted
	jne	.Lnext				# all the options

	call	morecore
.Lnext:
	mov	%rax, %rcx			# Move "curr" to "prev"
	mov	Header.next(%rax), %rax		# Move "next" to "curr"
	jmp	.Lscan

.Lexact:
	# Exact size match, unlink this block from the free list
	movq	Header.next(%rax), %rdx		# Move the "next" block's address into %rdx
	movq	%rdx, Header.next(%rcx)		# Set the "prev" block to point to the "next"
	jmp	.Ldone				# effectively removing the current from rotation

.Lresize:
	# Block is greater than needed so we resize it and return the tail end
	sub	%r12, Header.size(%rax)		# Subtract requested from size of current block
	add	Header.size(%rax), %rax		# Move %rax pointer to the start of the returned
	mov	%r12, Header.size(%rax)		# Set the size on the new block

.Ldone:
	movq	%rcx, freep			# Store where we left off searching in freep
	add	$HEADER_SIZE, %rax		# %rax has the return value but we want to skip
						# the header
	mov	%rbp, %rsp
	pop	%rbp
	ret

# Free previously allocated memory and coallesce it into the "free list"
# @param	%rdi	Memory address of the block to free
# @return	Returns no value
.type	free, @function
free:
	push	%rbp
	mov	%rsp, %rbp

	sub	$HEADER_SIZE, %rdi		# Point rdi at start of block

	mov	freep, %rax			# Sets "current" search block to free pointer

	# Find adjoining block
.Lfind:
	cmp	%rax, %rdi			# Compare our blocks address to "curr"
	jle	.Lcontinue			# If our block is less than the "curr" go to "next"

	cmp	Header.next(%rax), %rdi		# Compare our blocks address to "next" of "curr"
	jge	.Lfound

.Lcontinue:
	mov	Header.next(%rax), %rax		# Increment "curr" to next item
	jmp	.Lfind

.Lfound:
	# We now have the adjoining "found" block in %rax

	mov	%rdi, %rdx			# Point %rdx to the "end" of our block
	add	Header.size(%rdi), %rdx

	movq	Header.next(%rax), %r8		# Store next in r8 so we can use it
	cmp	%rdx, %r8			# If the end of the our block abuts the "next" of
	je	.Ljoin_next			# "found" the two blocks will be joined

.Lset_next:
	# Otherwise we know that our block points the the "next" of "found"
	movq	%r8, Header.next(%rdi)

.Lcheck_prev:
	cmp	%rdi, %rax			# If the start of the new block abuts "found" the
	je	.Ljoin_prev			# two blocks will be joined

	# Otherwise "found" will have its "next" pointing to our block
	mov	%rdi, Header.next(%rax)
	jmp	.Lend

.Ljoin_next:
	mov	Header.size(%rax), %rsi			# Puts size of "next" into %rsi
	add	%rsi, Header.size(%rdi)			# Adds size of "next" to our block
	movq	%r8, Header.next(%rdi)			# Adjust next pointer of our block to after
	jmp	.Lcheck_prev

.Ljoin_prev:
	mov	Header.size(%rdi), %rsi			# Puts size of our block in %rsi
	add	%rsi, Header.size(%rax)			# Adds size of out block to "prev"
	movq	%r8, Header.next(%rax)			# Adjust next pointer of "found" to point
							# After our block
.Lend:
	mov	%rax, freep				# Save "found" as the free pointer

	mov	%rbp, %rsp
	pop	%rbp
	ret

# Resize an allocation previously allocated with "alloc". Will make every attempt to perform the
# reallocation "in-place" without relocating the block. If the memory needs to be relocated the 
# existing contents of the block are moved to the new location
# @param	%rdi	Address of the memory block to reallocate
# @param	$rsi	The new size to allocate
# @param	%rax	Address of the resized memory block
.type	realloc, @function
realloc:
	push	%rbp
	mov	%rsp, %rbp

	mov	%rbp, %rsp
	pop	%rbp
	ret

# Private function to initialize alloc
# @return	void
.type	alloc_init, @function
alloc_init:
	push	%rbp
	mov	%rsp, %rbp

	# Intialization logic ... only runs if this is the first time alloc is called
	movq	$base, base			# Set base pointer to point to itself
	movq	$base, freep			# Initialize the free pointer to the base

	# Obtain the current break ...
	mov	$SYS_BRK, %rax			# Make the break syscall...
	mov	$0, %rdi			# With parameter 0
	syscall					# Which returns the current location of the break

	mov	%rax, break			# Store the location of the break

	mov	%rbp, %rsp
	pop	%rbp
	ret

# Privaet function to request more memory from OS and insert into the "free list"
# @param	%rdi	Amount of memory to request
# @return	???
.type	morecore, @function
morecore:
	push	%rbp
	mov	%rsp, %rbp

	push	%r12				# Preserve r12

	cmp	$MIN_BRK_REQ, %rdi
	jge	.Lrequest

	mov	$MIN_BRK_REQ, %rdi		# Ensures we request at LEAST the min bytes
	mov	%rdi, %r12			# Save the size we requested in %r12

.Lrequest:
	mov	$SYS_BRK, %rax			# Make the break syscall...
	add	break, %rdi			# calculate the new break
	syscall					# Which returns the current location of the break

	mov	break, %rdi			# Move the "old" break into %rdi because it points
	mov	%r12, Header.size(%rdi)		# Set the header size of the block
	mov	%rax, break			# Keep track of the "new" break

	add	$HEADER_SIZE, %rdi		# and point past the header as that is what "free"
	call	free				# expects. Free will add new memory to "free list"

	pop	%r12				# Restore r12

	mov	%rbp, %rsp
	pop	%rbp
	ret
