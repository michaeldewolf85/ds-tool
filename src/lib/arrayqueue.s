# lib/arrayqueue.s - ArrayQueue

.globl	ArrayQueue_ctor, ArrayQueue_add, ArrayQueue_remove, ArrayQueue_log

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

start_delim:
	.ascii	"[ \0"

mid_delim:
	.ascii	", \0"

end_delim:
	.ascii	" ]\n\n\0"

newline:
	.ascii	"\n\0"

malformed:
	.ascii	"Malformed command\n\0"

array:
	.ascii	"Raw    => \0"

length:
	.ascii	"Length => \0"

size:
	.ascii	"Size   => \0"

index:
	.ascii	"Index  => \0"

.section .text

# @function	ArrayQueue_ctor
# @description	Constructor for an ArrayQueue
# @return	%rax	Pointer to the ArrayQueue instance
.equ	ARRAYQUEUE, -8
.type	ArrayQueue_ctor, @function
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
.type	ArrayQueue_add, @function
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
	call	resize
	jmp	1b

# @function	ArrayQueue_remove
# @description	Remove an element. Elements are removed on a first-in first-out (FIFO) basis
# @param	%rdi	Pointer to the ArrayQueue
# @return	%rax	Pointer to the removed element
.type	ArrayQueue_remove, @function
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
	call	resize
	jmp	1b

# Empty ArrayQueue
3:
	push	$0
	jmp	1b

# @function	ArrayQueue_log
# @description	Log a visual representation of the current state of the ArrayQueue
# @param	%rdi	Pointer to the ArrayQueue
# @return	void
.equ	LENGTH, -8
.equ	SIZE, -16
.equ	INDEX, -24
.equ	DATA, -32
.equ	COUNTER, -40
.equ	THIS, -48
.type	ArrayQueue_log, @function
ArrayQueue_log:
	push	%rbp
	mov	%rsp, %rbp

	# Store variables
	sub	$48, %rsp
	mov	ArrayQueue.length(%rdi), %eax
	mov	%rax, LENGTH(%rbp)
	mov	ArrayQueue.size(%rdi), %eax
	mov	%rax, SIZE(%rbp)
	mov	ArrayQueue.index(%rdi), %eax
	mov	%rax, INDEX(%rbp)
	mov	ArrayQueue.data(%rdi), %rax
	mov	%rax, DATA(%rbp)
	movq	$0, COUNTER(%rbp)
	mov	%rdi, THIS(%rbp)

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
	# For some reason the code above MODIFIES the index so we reset it here
	mov	THIS(%rbp), %rdi
	mov	ArrayQueue.index(%rdi), %eax
	mov	%rax, INDEX(%rbp)

	mov	$end_delim, %rdi
	call	log

	# Log length
	mov	$length, %rdi
	call	log

	mov	LENGTH(%rbp), %edi
	call	itoa

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	# Log size
	mov	$size, %rdi
	call	log

	mov	SIZE(%rbp), %edi
	call	itoa

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	# Log index
	mov	$index, %rdi
	call	log

	mov	INDEX(%rbp), %edi
	call	itoa

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	# Log backing array
	mov	$array, %rdi
	call	log

	mov	$start_delim, %rdi
	call	log

	mov	DATA(%rbp), %r8
	mov	SIZE(%rbp), %esi	# We use the size ...
	cmp	$0, %esi		# Check for zero length
	je	5f

	sub	INDEX(%rbp), %esi	# ... minus the index to calculate if a position has value
	xor	%rcx, %rcx		# Loop counter
# Print loop for backing array
3:
	mov	%esi, %eax		# Start with our size minus index ...
	add	%ecx, %eax		# ... add the current index being examined ...
	xor	%rdx, %rdx		# ... zero out the remainder ...
	divq	SIZE(%rbp)		# ... and divide by the size ...
	cmp	LENGTH(%rbp), %rdx	# ... if the remainder is ge to length
	jge	4f			# ... we have an empty spot

	mov	(%r8, %rcx, 1<<3), %rdi
	call	log

4:
	inc	%rcx
	cmp	SIZE(%rbp), %rcx
	jge	5f

	mov	$mid_delim, %rdi
	call	log

	jmp	3b

5:
	mov	$end_delim, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	resize
# @description	Private function to resize the arrayqueue to be 2x the length, or 1, whichever is 
#		greater
# @param	%rdi	Pointer to the ArrayQueue
# @return	void
.equ	ARRAYQUEUE, -8
.equ	ARRAYQUEUE_DATA, -16
.equ	NEW_SIZE, -24
resize:
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

