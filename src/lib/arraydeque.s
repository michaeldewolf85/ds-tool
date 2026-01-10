# lib/arraydeque.s - ArrayDeque

.globl	ArrayDeque_ctor, ArrayDeque_get, ArrayDeque_set, ArrayDeque_add, ArrayDeque_remove
.globl	ArrayDeque_log

# ArrayDeque struct
	.struct	0
ArrayDeque.data:
	.struct	ArrayDeque.data + 1<<3
ArrayDeque.index:
	.struct	ArrayDeque.index + 1<<2
ArrayDeque.length:
	.struct	ArrayDeque.length + 1<<2
ArrayDeque.size:
	.struct	ArrayDeque.size + 1<<3
	.equ	ARRAYDEQUE_SIZE, .

.equ	ARRAYDEQUE_START_SIZE, 1

.section .rodata

start_delim:
	.ascii	"[ \0"

mid_delim:
	.ascii	", \0"

end_delim:
	.ascii	" ]\n\0"

newline:
	.ascii	"\n\0"

length:
	.ascii	"Length => \0"

size:
	.ascii	"Size   => \0"

index:
	.ascii	"Index  => \0"

raw:
	.ascii	"Raw    => \0"

.section .text

# @function	ArrayDeque_ctor
# @description	ArrayDeque constructor
# @return	%rax	Pointer to the ArrayDeque
.equ	THIS, -8
.equ	DATA, -16
.type	ArrayDeque_ctor, @function
ArrayDeque_ctor:
	push	%rbp
	mov	%rsp, %rbp

	mov	$ARRAYDEQUE_SIZE, %rdi
	call	alloc
	push	%rax

	mov	$ARRAYDEQUE_START_SIZE, %rdi
	imul	$8, %rdi
	call	alloc
	push	%rax

	mov	THIS(%rbp), %rax
	mov	DATA(%rbp), %rcx
	mov	%rcx, ArrayDeque.data(%rax)
	movl	$0, ArrayDeque.index(%rax)
	movl	$0, ArrayDeque.length(%rax)
	movq	$ARRAYDEQUE_START_SIZE, ArrayDeque.size(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	ArrayDeque_get
# @description	Get the element at the specified index
# @param	%rdi	Pointer to the ArrayDeque
# @param	%rsi	Index of the element to get
# @return	%rax	Pointer to the element or NULL if not found
.type	ArrayDeque_get, @function
ArrayDeque_get:
	# Validates the passed index
	mov	ArrayDeque.length(%rdi), %ecx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	call	actual_index			# Actual index in %rax
	mov	ArrayDeque.data(%rdi), %rcx	# Pointer to "data" in %rcx
	mov	(%rcx, %rax, 1<<3), %rax
	ret

# Error
1:
	xor	%rax, %rax
	ret

# @function	ArrayDeque_set
# @description	Set the element at the specified index to the specified value
# @param	%rdi	Pointer to the ArrayDeque
# @param	%rsi	Index of the element to set
# @param	%rdx	Pointer to the element to set
# @return	%rax	Pointer to the previous element
.type	ArrayDeque_set, @function
ArrayDeque_set:
	# Validates the passed index
	mov	ArrayDeque.length(%rdi), %ecx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	mov	%rdx, %r8			# Move new element to %r8 for safekeeping
	call	actual_index			# Actual index in %rax
	mov	ArrayDeque.data(%rdi), %rcx	# Pointer to "data" in %rcx
	mov	(%rcx, %rax, 1<<3), %r9		# Move previous element into %rax to return
	mov	%r8, (%rcx, %rax, 1<<3)		# Move new element into position
	mov	%r9, %rax
	ret

# Error
1:
	xor	%rax, %rax
	ret

# @function	ArrayDeque_add
# @description	Add an element to the ArrayDeque at the specified index
# @param	%rdi	Pointer to the ArrayDeque
# @param	%rsi	Index of the element to add
# @param	%rdx	Pointer to the element
# @return	%rax	Pointer to the element on success, NULL on failure
.equ	KEY, -8
.equ	VALUE, -16
.type	ArrayDeque_add, @function
ArrayDeque_add:
	# Validates the passed index
	mov	ArrayDeque.length(%rdi), %ecx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	7f				# If there's carry it's either too big or negative

	push	%rbp
	mov	%rsp, %rbp

	# Store some variables on the stack for safekeeping
	sub	$16, %rsp
	mov	%rsi, KEY(%rbp)			# Index of the element to add
	mov	%rdx, VALUE(%rbp)		# Pointer to the element to add

	# Check is a resize is needed
	mov	ArrayDeque.length(%rdi), %eax
	cmp	%rax, ArrayDeque.size(%rdi)
	jle	5f

6:
	# Determine which half of the backing array this operation is going to affect
	mov	ArrayDeque.length(%rdi), %eax	# Length in %rax
	mov	$2, %rcx			# DIV does not accept an immediate operand
	xor	%rdx, %rdx			# Zero out remainder
	div	%rcx				# Divide by two

	# TODO this does "integer" division but it would be really nice if it would "round" result
	cmp	%rax, %rsi			# Compare requested index to the midpoint
	jge	2f				# Jumps if index is in the second half

# Index in first half of the array. If this is the case we need to adjust the base index to be one
# to the left (potentially wrapping around to the end of the backing array)
	mov	$-1, %rsi			# This new base index can be obtained by requesting
	call	actual_index			# the "actual index" of negative one
	mov	%eax, ArrayDeque.index(%rdi)

	xor	%rcx, %rcx			# Loop counter
1:
	# We are finished when the requested index is equal (or less than) the loop counter
	mov	KEY(%rbp), %rsi			# Restore add index first bc %rsi gets clobbered
	cmp	%rcx, %rsi
	jle	4f

	# Determine destination index which is for the loop counter
	mov	%rcx, %rsi
	call	actual_index
	mov	%rax, %r8

	# Determine source index which is for the loop counter + 1
	mov	%rcx, %rsi
	inc	%rsi
	call	actual_index
	mov	%rax, %r9

	# Perform the move
	mov	ArrayDeque.data(%rdi), %rax	# Pointer to "data"
	mov	(%rax, %r9, 1<<3), %rdx		# Obtain source element and move it to the ...
	mov	%rdx, (%rax, %r8, 1<<3)		# destination

	# Prep for next loop iteration
	inc	%rcx
	cmp	%rcx, %rsi
	jmp	1b

# Index in second half of the array
2:
	mov	ArrayDeque.length(%rdi), %ecx	# Length is the loop counter and we decrement
	mov	KEY(%rbp), %rsi			# Restore add index first bc %rsi gets clobbered

3:
	# We are finished when the requested index is equal (or greater than) the loop counter
	cmp	%rcx, %rsi
	jge	4f

	# Determine destination index which is for the loop counter
	mov	%rcx, %rsi
	call	actual_index
	mov	%rax, %r8

	# Determine source index which is for the loop counter - 1
	mov	%rcx, %rsi
	dec	%rsi
	call	actual_index
	mov	%rax, %r9

	# Perform the move
	mov	ArrayDeque.data(%rdi), %rax	# Pointer to "data"
	mov	(%rax, %r9, 1<<3), %rdx		# Obtain source element and move it to the ...
	mov	%rdx, (%rax, %r8, 1<<3)		# destination

	# Prep for next loop iteration
	dec	%rcx
	mov	KEY(%rbp), %rsi			# Restore add index bc %rsi gets clobbered
	jmp	3b

# Space has been created for the new element. Insertion index is in %rsi
4:
	call	actual_index			# Puts "actual index" in %rax

	# Move the element into place
	mov	VALUE(%rbp), %rcx		# Pointer to the element to add
	mov	ArrayDeque.data(%rdi), %rdx	# Pointer to "data"
	mov	%rcx, (%rdx, %rax, 1<<3)	# Move the element into place

	# Increment the length
	incl	ArrayDeque.length(%rdi)

	# Return the new element
	mov	%rcx, %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# Resize needed
5:
	call	resize
	jmp	6b

# Error index
7:
	xor	%rax, %rax
	ret

# @function	ArrayDeque_remove
# @description	Remove the element at the requested index
# @param	%rdi	Pointer to the ArrayDeque
# @param	%rsi	Index of the element to remove
# @return	%rax	Pointer to the removed element
.equ	VALUE, -8
.type	ArrayDeque_remove, @function
ArrayDeque_remove:
	# Validates the passed index
	mov	ArrayDeque.length(%rdi), %ecx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	7f				# If there's carry it's either too big or negative
	jz	7f				# Also need to check for equals

	push	%rbp
	mov	%rsp, %rbp

	call	ArrayDeque_get		# Put's element to be removed on the stack for easy ...
	push	%rax			# returning later

	# Determine which half of the backing array this operation is going to affect
	mov	ArrayDeque.length(%rdi), %eax	# Length in %rax
	mov	$2, %rcx			# DIV does not accept an immediate operand
	xor	%rdx, %rdx			# Zero out remainder
	div	%rcx				# Divide by two

	# In either case the loop counter starts at the requested index
	mov	%rsi, %rcx			# Loop counter

	# TODO this does "integer" division but it would be really nice if it would "round" result
	cmp	%rax, %rsi			# Compare requested index to the midpoint
	jge	3f				# Jumps if index is in the second half

# The index of the element is in the FIRST half of the backing array
1:
	# We start at the requested index and decrement. The loop is over when we reach one
	cmp	$0, %rcx
	jle	2f

	# Determine destination index which is for the loop counter
	mov	%rcx, %rsi
	call	actual_index
	mov	%rax, %r8

	# Determine source index which is for the loop counter - 1
	mov	%rcx, %rsi
	dec	%rsi
	call	actual_index
	mov	%rax, %r9

	# Perform the move
	mov	ArrayDeque.data(%rdi), %rax	# Pointer to "data"
	mov	(%rax, %r9, 1<<3), %rdx		# Obtain source element and move it to the ...
	mov	%rdx, (%rax, %r8, 1<<3)		# destination

	# Prepare next iteration
	dec	%rcx
	jmp	1b

# We are still operating on the FIRST half of the backing array as there is one more operation
# We need to move the base index one to the right which can be achieved by finding the actual
# index of one
2:
	mov	$1, %rsi			# This new base index can be obtained by requesting
	call	actual_index			# the "actual index" of one
	mov	%eax, ArrayDeque.index(%rdi)
	jmp	4f

# The index of the element is in the SECOND half of the backing array
3:
	# We start at the requested index and we increment. The loop is over when we reach length
	# minus 2
	mov	ArrayDeque.length(%rdi), %eax
	dec	%rax
	cmp	%rax, %rcx
	jge	4f

	# Determine destination index which is for the loop counter
	mov	%rcx, %rsi
	call	actual_index
	mov	%rax, %r8

	# Determine source index which is for the loop counter + 1
	mov	%rcx, %rsi
	inc	%rsi
	call	actual_index
	mov	%rax, %r9

	# Perform the move
	mov	ArrayDeque.data(%rdi), %rax	# Pointer to "data"
	mov	(%rax, %r9, 1<<3), %rdx		# Obtain source element and move it to the ...
	mov	%rdx, (%rax, %r8, 1<<3)		# destination

	# Prep for next loop iteration
	inc	%rcx
	jmp	3b

# All moves are complete, now we only need to decrement the length and check if a resize is needed
4:
	decl	ArrayDeque.length(%rdi)
	mov	ArrayDeque.length(%rdi), %eax
	imul	$3, %rax
	cmp	ArrayDeque.size(%rdi), %rax
	jl	6f

5:
	pop	%rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# Resize needed
6:
	call	resize
	jmp	5b

# Error index
7:
	xor	%rax, %rax
	ret

# @function	ArrayDeque_log
# @description	Log an ArrayDeque
# @param	%rdi	Pointer to the ArrayDeque
# @return	void
.equ	THIS, -8
.equ	LEN, -16
.equ	CTR, -24
.type	ArrayDeque_log, @function
ArrayDeque_log:
	push	%rbp
	mov	%rsp, %rbp

	# Store some variables
	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	ArrayDeque.length(%rdi), %eax
	mov	%rax, LEN(%rbp)
	movq	$0, CTR(%rbp)

	mov	$start_delim, %rdi
	call	log

	cmpq	$0, LEN(%rbp)			# Check for zero length
	je	2f

# Print loop
1:
	mov	CTR(%rbp), %rsi			# Loop counter
	mov	THIS(%rbp), %rdi
	call	actual_index			# Put "actual index" of first value in %rax

	mov	ArrayDeque.data(%rdi), %rcx
	mov	(%rcx, %rax, 1<<3), %rdi
	call	log

	inc	%rsi
	cmp	%rsi, LEN(%rbp)
	jle	2f

	mov	%rsi, CTR(%rbp)

	mov	$mid_delim, %rdi
	call	log
	jmp	1b

2:
	mov	$end_delim, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$length, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	ArrayDeque.length(%rdi), %edi
	call	itoa

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$size, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	ArrayDeque.size(%rdi), %edi
	call	itoa

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$index, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	ArrayDeque.index(%rdi), %edi
	call	itoa

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$raw, %rdi
	call	log

	mov	$start_delim, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	ArrayDeque.size(%rdi), %r8
	sub	ArrayDeque.index(%rdi), %r8d
	movq	$0, CTR(%rbp)

# Print loop for "raw"
3:
	mov	CTR(%rbp), %rcx
	mov	THIS(%rbp), %rdi
	mov	ArrayDeque.size(%rdi), %rax
	sub	ArrayDeque.index(%rdi), %eax
	add	%rcx, %rax
	xor	%rdx, %rdx
	divq	ArrayDeque.size(%rdi)
	cmp	ArrayDeque.length(%rdi), %edx
	jge	4f

	mov	ArrayDeque.data(%rdi), %rax

	mov	(%rax, %rcx, 1<<3), %rdi
	call	log

4:
	incq	CTR(%rbp)
	mov	CTR(%rbp), %rcx
	mov	THIS(%rbp), %rdi
	cmp	ArrayDeque.size(%rdi), %rcx
	jge	5f

	mov	$mid_delim, %rdi
	call	log
	jmp	3b
	
5:
	mov	$end_delim, %rdi
	call	log

	mov	THIS(%rbp), %rdi

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	resize
# @description	Private function to resize the ArrayDeque to be two times its length. As a side
#		effect the index is reset. If the length is zero this is a no-op.
# @param	%rdi	Pointer to the ArrayDeque
# @return	void
.equ	THIS, -8
.equ	SIZE, -16
resize:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	mov	ArrayDeque.length(%rdi), %edi
	cmp	$1, %rdi			# We need to ensure size never drops below one as
	jl	3f				# that is unrecoverable with the current logic

	# Calculate the size and cache on the stack
	imul	$2, %rdi
	mov	%rdi, SIZE(%rbp)

	# Allocate a new backing array
	imul	$8, %rdi			# Requested size needs to be in bytes
	call	alloc

	mov	THIS(%rbp), %rdi		# Restore the ArrayDeque pointer in %rdi
	mov	ArrayDeque.data(%rdi), %r8	# Pointer to "old" data
	mov	%rax, %r9			# Pointer to "new" data
	xor	%rsi, %rsi			# Reset loop counter
# Move loop
1:
	cmp	ArrayDeque.length(%rdi), %esi
	jge	2f

	# Determine the source index for the loop counter
	call	actual_index
	mov	(%r8, %rax, 1<<3), %rcx		# Obtain element at "actual index" in "old" data
	mov	%rcx, (%r9, %rsi, 1<<3)		# Copy element at "zero-based" index to "new" data
	
	inc	%rsi
	jmp	1b

# Move is complete, now we just need to update the data pointer and the index
2:
	movl	$0, ArrayDeque.index(%rdi)	# Reset index
	mov	%r9, ArrayDeque.data(%rdi)

	# Set the updated size
	mov	SIZE(%rbp), %rax
	mov	%rax, ArrayDeque.size(%rdi)

	# Free the old space
	mov	%r8, %rdi
	call	free

	# Restore "this" pointer
	mov	THIS(%rbp), %rdi
3:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	actual_index
# @description	Private function to determine the "actual index" for the given storage key
# @param	%rdi	Pointer to the ArrayDeque
# @param	%rsi	The storage key
# @return	%rax	The "actual index" of the storage key
actual_index:
	mov	ArrayDeque.index(%rdi), %eax	# Start with the base index
	add	%rsi, %rax			# Add the storage key
	xor	%rdx, %rdx			# Zero out the remainder
	divq	ArrayDeque.size(%rdi)		# Divide by the size
	mov	%rdx, %rax			# Remainder is the "actual index"
	ret
