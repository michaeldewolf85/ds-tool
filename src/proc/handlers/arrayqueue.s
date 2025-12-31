# proc/handlers/arrayqueue.s - ArrayQueue handler

.include	"structs.inc"

.globl	arrayqueue, arrayqueue_handler

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

.section .rodata

# ArrayQueue command string
.type	arrayqueue, @object
arrayqueue:
	.ascii	"arrayqueue\0"

add:
	.ascii	"add\0"
remove:
	.ascii	"remove\0"

commands:
	.quad	add
	.quad	remove
	.quad	0	# Sentinel

handlers:
	.quad	ArrayQueue_add
	.quad	ArrayQueue_remove

start_delim:
	.ascii	"[ \0"

mid_delim:
	.ascii	", \0"

end_delim:
	.ascii	" ]\n\0"

newline:
	.ascii	"\n\0"

malformed:
	.ascii	"Malformed command\n\0"

null:
	.ascii	"NULL\0"

.section .bss

# One and only ArrayQueue instance
instance:
	.zero	1<<3

.section .text

# @function	arrayqueue_handler
# @description	Handler for the arrayqueue set of commands
# @param	%rdi	A pointer to an "Input" struct (argc, argv)
# @return	void
.equ	INPUT, -8
.equ	COUNTER, -16
.type	arrayqueue_handler, @function
arrayqueue_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, INPUT(%rbp)
	movq	$0, COUNTER(%rbp)

	# Check for initialization
	cmpq	$0, instance
	je	new

1:
	mov	INPUT(%rbp), %rax		# Input
	cmpq	$1, Input.argc(%rax)		# If only 1 argument, print the ArrayQueue
	je	3f

	mov	Input.argv + 8(%rax), %rdi	# Current command in %rdi
check:
	mov	COUNTER(%rbp), %rcx
	mov	commands(, %rcx, 1<<3), %rsi	# Current command being examined
	cmp	$0, %rsi			# Check for NULL sentinel which indicates no ...
	je	error				# matching command was found

	call	strcmp
	cmp	$0, %rax
	je	match

	incq	COUNTER(%rbp)
	jmp	check

match:
	mov	instance, %rdi

	mov	INPUT(%rbp), %rax		# Only "add" command takes an argument but argv ...
	mov	Input.argv + 16(%rax), %rsi	# passes zeroes in all the other slots

	mov	COUNTER(%rbp), %rcx
	call	*handlers(, %rcx, 1<<3)

	mov	$null, %rcx
	cmp	$0, %rax
	cmove	%rcx, %rax

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

3:
	mov	instance, %rdi
	call	ArrayQueue_log

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# Not initialized
new:
	call	ArrayQueue_ctor
	mov	%rax, instance
	jmp	1b

error:
	mov	$malformed, %rdi
	call	log
	jmp	2b


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
# @return	%rax	Pointer to the added item
.equ	ARRAYQUEUE, -8
.equ	NEW_ITEM, -16
ArrayQueue_add:
	push	%rbp
	mov	%rsp, %rbp

	# Store variables on the stack
	sub	$16, %rsp
	mov	%rdi, ARRAYQUEUE(%rbp)
	mov	%rsi, NEW_ITEM(%rbp)

	# Check for an empty item
	cmp	$0, %rsi
	je	3f

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

3:
	pop	%rax

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

	# Check for zero length
	mov	ArrayQueue.length(%rdi), %eax
	cmp	$0, %eax
	je	3f

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

# Empty ArrayQueue
3:
	push	$0
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

# @function	ArrayQueue_log
# @description	Log a visual representation of the current state of the ArrayQueue
# @param	%rdi	Pointer to the ArrayQueue
# @return	void
.equ	LENGTH, -8
.equ	SIZE, -16
.equ	INDEX, -24
.equ	DATA, -32
.equ	COUNTER, -40
ArrayQueue_log:
	push	%rbp
	mov	%rsp, %rbp

	# Store variables
	sub	$40, %rsp
	mov	ArrayQueue.length(%rdi), %eax
	mov	%rax, LENGTH(%rbp)
	mov	ArrayQueue.size(%rdi), %eax
	mov	%rax, SIZE(%rbp)
	mov	ArrayQueue.index(%rdi), %eax
	mov	%rax, INDEX(%rbp)
	mov	ArrayQueue.data(%rdi), %rax
	mov	%rax, DATA(%rbp)
	movq	$0, COUNTER(%rbp)

	mov	$start_delim, %rdi
	call	log

	# Check for zero length
	cmpq	$0, LENGTH(%rbp)
	je	2f

# Print loop
1:
	# Print current index
	mov	DATA(%rbp), %rax
	mov	INDEX(%rbp), %ecx
	mov	(%rax, %rcx, 1<<3), %rdi
	call	log

	# Increment loop counter and check for loop end
	incl	COUNTER(%rbp)
	mov	LENGTH(%rbp), %eax
	cmp	COUNTER(%rbp), %rax
	jle	2f

	mov	$mid_delim, %rdi
	call	log

	mov	INDEX(%rbp), %eax		# Index
	inc	%eax				# Increment index by one
	xor	%edx, %edx			# Clear remainder
	divq	SIZE(%rbp)			# Divide by size
	mov	%rdx, INDEX(%rbp)		# Update the index to be the remainder
	jmp	1b

2:
	mov	$end_delim, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret
