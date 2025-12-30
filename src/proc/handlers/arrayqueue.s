# proc/handlers/arrayqueue.s - ArrayQueue handler

## Macros

### ArrayQueue
	.struct	0
# Backing array
ArrayQueue.data:
	.struct	ArrayQueue.data + 1<<3
# Current index
ArrayQueue.index:
	.struct	ArrayQueue.index + 1<<2
# Number of elements
ArrayQueue.length:
	.struct	ArrayQueue.length + 1<<2
# Size of backing array
ArrayQueue.size:
	.struct	ArrayQueue.size + 1<<2
	.equ	ARRAYQUEUE_SIZE, .

.equ	ARRAYQUEUE_START_SIZE, 1

.globl	arrayqueue_handler

.section .rodata

item:
	.ascii "Foobarbaz\0"

.section .text

# @function	arrayqueue_handler
# @description	Handler for the arrayqueue set of commands
# @param	%rdi	A pointer to an "Input" struct (argc, argv)
# @return	void
.equ	ARRAYQUEUE, -8
.type	arrayqueue_handler, @function
arrayqueue_handler:
	push	%rbp
	mov	%rsp, %rbp
	sub	$8, %rsp

	call	ArrayQueue_ctor
	mov	%rax, ARRAYQUEUE(%rbp)

	# Length 1
	mov	ARRAYQUEUE(%rbp), %rdi
	mov	$item, %rsi
	call	ArrayQueue_add

	# Resize 1 => 2
	# Length 2
	mov	ARRAYQUEUE(%rbp), %rdi
	mov	$item, %rsi
	call	ArrayQueue_add

	# Resize 2 => 4
	# Length 3
	mov	ARRAYQUEUE(%rbp), %rdi
	mov	$item, %rsi
	call	ArrayQueue_add

	# Length 4
	mov	ARRAYQUEUE(%rbp), %rdi
	mov	$item, %rsi
	call	ArrayQueue_add

	# Resize 4 => 8
	# Length 5
	mov	ARRAYQUEUE(%rbp), %rdi
	mov	$item, %rsi
	call	ArrayQueue_add

	# Length 4
	mov	ARRAYQUEUE(%rbp), %rdi
	call	ArrayQueue_remove

	# Length 3
	mov	ARRAYQUEUE(%rbp), %rdi
	call	ArrayQueue_remove

	# Resize 8 => 4
	# Length 2
	mov	ARRAYQUEUE(%rbp), %rdi
	call	ArrayQueue_remove

	# Length 3
	mov	ARRAYQUEUE(%rbp), %rdi
	mov	$item, %rsi
	call	ArrayQueue_add

	# Length 4
	mov	ARRAYQUEUE(%rbp), %rdi
	mov	$item, %rsi
	call	ArrayQueue_add

	# Resize 4 => 8
	# Length 5
	mov	ARRAYQUEUE(%rbp), %rdi
	mov	$item, %rsi
	call	ArrayQueue_add

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	ArrayQueue_ctor
# @description	Constructor for an ArrayQueue
# @return	%rax	Pointer to the ArrayQueue instance
.equ	ARRAYQUEUE, -8
ArrayQueue_ctor:
	push	%rbp
	mov	%rsp, %rbp

	# Allocate base struct
	mov	$ARRAYQUEUE_SIZE, %rdi
	call	alloc
	push	%rax

	# Allocate backing array
	mov	$ARRAYQUEUE_START_SIZE, %rdi
	imul	$8, %rdi
	call	alloc

	mov	ARRAYQUEUE(%rbp), %rcx
	mov	%rax, ArrayQueue.data(%rcx)
	movl	$0, ArrayQueue.index(%rcx)
	movl	$0, ArrayQueue.length(%rcx)
	movl	$ARRAYQUEUE_START_SIZE, ArrayQueue.size(%rcx)

	mov	%rcx, %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	ArrayQueue_add
# @description	Adds an item to the ArrayQueue
# @param	%rdi	Pointer to the ArrayQueue
# @param	%rsi	Pointer to the item to add
# @return	%rax	The length of the queue
.equ	ARRAYQUEUE, -8
.equ	NEW_ITEM, -16
ArrayQueue_add:
	push	%rbp
	mov	%rsp, %rbp

	# Store variables on the stack
	sub	$16, %rsp
	mov	%rdi, ARRAYQUEUE(%rbp)
	mov	%rsi, NEW_ITEM(%rbp)

	# Check if a resize might be needed
	mov	ArrayQueue.length(%rdi), %eax
	inc	%eax
	cmp	ArrayQueue.size(%rdi), %eax
	jg	2f

1:
	# Determine insertion index (remainder of (length + index) / size)
	mov	ARRAYQUEUE(%rbp), %rcx
	mov	ArrayQueue.index(%rcx), %eax
	add	ArrayQueue.length(%rcx), %eax
	xor	%edx, %edx
	divl	ArrayQueue.size(%rcx)

	# Insert data into backing array at index
	mov	ArrayQueue.data(%rcx), %rcx
	mov	NEW_ITEM(%rbp), %rsi
	mov	%rsi, (%rcx, %rdx, 1<<3)

	# Increment length and return it
	mov	ARRAYQUEUE(%rbp), %rcx
	incl	ArrayQueue.length(%rcx)
	mov	ArrayQueue.length(%rcx), %eax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# Resize
2:
	call	ArrayQueue_resize
	jmp	1b

# @function	ArrayQueue_remove
# @description	Remove an element. Elements are removed on a first-in first-out (FIFO) basis
# @param	%rdi	Pointer to the ArrayQueue
# @return	%rax	Pointer to the removed element
ArrayQueue_remove:
	push	%rbp
	mov	%rsp, %rbp

	# Remove element and load for return
	mov	ArrayQueue.index(%rdi), %eax
	mov	ArrayQueue.data(%rdi), %rcx
	mov	(%rcx, %rax, 1<<3), %rax
	push	%rax

	# Determine new index
	movl	ArrayQueue.index(%rdi), %eax
	inc	%eax
	xor	%edx, %edx
	divl	ArrayQueue.size(%rdi)
	mov	%edx, ArrayQueue.index(%rdi)

	# Decrement length
	decl	ArrayQueue.length(%rdi)

	# Check if resize is needed
	mov	ArrayQueue.length(%rdi), %eax
	imul	$3, %eax
	cmp	ArrayQueue.size(%rdi), %eax
	jle	2f

1:
	# Load return value
	pop	%rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# Resize
2:
	call	ArrayQueue_resize
	jmp	1b

# @function	ArrayQueue_resize
# @description	Resize the arrayqueue to be 2x the length, or 1, whichever is greater
# @param	%rdi	Pointer to the ArrayQueue
# @return	void
.equ	ARRAYQUEUE, -8
.equ	ARRAYQUEUE_DATA, -16
.equ	NEW_SIZE, -24
ArrayQueue_resize:
	push	%rbp
	mov	%rsp, %rbp

	# Store variables
	sub	$24, %rsp
	mov	%rdi, ARRAYQUEUE(%rbp)
	mov	ArrayQueue.data(%rdi), %rax
	mov	%rax, ARRAYQUEUE_DATA(%rbp)

	# Determine the new length: max(2 * length, 1)
	mov	$1, %eax			# Needs to be in a register for CMOVcc
	mov	ArrayQueue.length(%rdi), %edi
	imul	$2, %edi
	cmp	$1, %edi
	cmovl	%eax, %edi
	mov	%rdi, NEW_SIZE(%rbp)

	# Allocate a new block of memory, size is already in %rdi
	imul	$8, %rdi			# Need to transform size to be in bytes
	call	alloc

	# Prep for move loop
	mov	%rax, %rcx			# %rcx - Data (new)
	mov	ARRAYQUEUE_DATA(%rbp), %rsi	# %rsi - Data "old"
	mov	ARRAYQUEUE(%rbp), %r11
	mov	ArrayQueue.index(%r11), %edi	# %rdi - Index
	mov	ArrayQueue.size(%r11), %r8d	# %r8 - Size
	mov	ArrayQueue.length(%r11), %r9d	# %r9d - Length
	xor	%r10d, %r10d			# Loop counter

# Move loop
1:
	mov	%edi, %eax			# Start with index
	add	%r10d, %eax			# Add the loop counter
	xor	%edx, %edx			# Zero out remainder
	div	%r8d				# Divide by size
	mov	(%rsi, %rdx, 1<<3), %rax	# This is the element we are moving
	mov	%rax, (%rcx, %r10, 1<<3)	# This is where we are moving it
	
	inc	%r10d
	cmp	%r10d, %r9d
	jg	1b

	# Reset index
	mov	ARRAYQUEUE(%rbp), %rax
	mov	%rcx, ArrayQueue.data(%rax)
	movl	$0, ArrayQueue.index(%rax)
	mov	NEW_SIZE(%rbp), %ecx
	mov	%ecx, ArrayQueue.size(%rax)

	# Free data (old)
	mov	%rsi, %rdi
	call	free

	mov	%rbp, %rsp
	pop	%rbp
	ret
