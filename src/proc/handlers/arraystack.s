# proc/handlers/array-stack.s - ArrayStack handler

.include	"common.inc"

.globl	dickens

# ArrayStack struct
	.struct	0
ArrayStack.size:
	.struct	ArrayStack.size + 1<<2
ArrayStack.length:
	.struct	ArrayStack.length + 1<<2
ArrayStack.data:
	.struct	ArrayStack.data + 1<<3
	.equ	ARRAYSTACK_SIZE, .

.equ	ARRAYSTACK_START_SIZE, 1<<3

.section .rodata

start_delim:
	.ascii	"[ \0"

mid_delim:
	.ascii	", \0"

end_delim:
	.ascii	" ]\0"

# TODO: REMOVE!!
item1:
	.ascii	"artichokes\0"
item2:
	.ascii	"broccoli\0"
item3:
	.ascii	"green peppers\0"
item4:
	.ascii	"hamburger\0"
item5:
	.ascii	"mushrooms\0"
item6:
	.ascii	"olives\0"
item7:
	.ascii	"onions\0"
item8:
	.ascii	"pepperoni\0"
item9:
	.ascii	"pineapple\0"
item10:
	.ascii	"sausage\0"

.section .bss

# Static pointer to the one and only ArrayStack instance
instance:
	.zero	1<<3

.section .text

.type	dickens, @function
dickens:
	mov	instance, %rdi
	cmp	$NULL, %rdi
	je	new

1:
	mov	$instance, %rdi
	mov	$item1, %rdx
	mov	$0, %rsi
	call	ArrayStack_add

	mov	$instance, %rdi
	mov	$item2, %rdx
	mov	$1, %rsi
	call	ArrayStack_add

	mov	$instance, %rdi
	mov	$item3, %rdx
	mov	$2, %rsi
	call	ArrayStack_add

	mov	$instance, %rdi
	mov	$item4, %rdx
	mov	$3, %rsi
	call	ArrayStack_add

	mov	$instance, %rdi
	mov	$item5, %rdx
	mov	$4, %rsi
	call	ArrayStack_add

	mov	$instance, %rdi
	mov	$item6, %rdx
	mov	$5, %rsi
	call	ArrayStack_add

	mov	$instance, %rdi
	mov	$item7, %rdx
	mov	$6, %rsi
	call	ArrayStack_add

	mov	$instance, %rdi
	mov	$item8, %rdx
	mov	$7, %rsi
	call	ArrayStack_add

	mov	$instance, %rdi
	mov	$item9, %rdx
	mov	$8, %rsi
	call	ArrayStack_add

	mov	$instance, %rdi
	mov	$0, %rsi
	call	ArrayStack_remove

	mov	$instance, %rdi
	mov	$0, %rsi
	call	ArrayStack_remove

	mov	$instance, %rdi
	mov	$0, %rsi
	call	ArrayStack_remove

	mov	$instance, %rdi
	mov	$0, %rsi
	call	ArrayStack_remove

	mov	$instance, %rdi
	mov	$0, %rsi
	call	ArrayStack_remove

	mov	$instance, %rdi
	call	ArrayStack_log
	call	print
	ret

# No instance yet, so create one
new:
	call	ArrayStack_ctor
	jmp	1b

# @function	constructor
# @public
# @description	Initializes an ArrayStack
# @return	%rax	A pointer to the ArrayStack

.type	ArrayStack_ctor, @function
ArrayStack_ctor:
	# Allocation for the arraystack's metadata
	mov	$ARRAYSTACK_SIZE, %rdi
	call	alloc
	# TODO: Error handling
	mov	%rax, instance

	# Allocation for the arraystack's data
	mov	$ARRAYSTACK_START_SIZE, %rdi
	call	alloc
	# TODO: Error handling

	mov	%rax, instance + ArrayStack.data
	movl	$ARRAYSTACK_START_SIZE, instance + ArrayStack.size
	movl	$0, instance + ArrayStack.length
	ret

# @function	ArrayStack_get
# @description	Get the element at a position
# @param	%rdi	Address of the arraystack
# @param	%rsi	The index of the element to get
# @return	%rax	The address of the element or NULL
ArrayStack_get:
	# Validates the passed index
	mov	ArrayStack.length(%rdi), %ecx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	mov	ArrayStack.data(%rdi), %rax	# %rax now holds the address of "data"
	mov	(%rax, %rsi, 1<<3), %rax
	ret
# Unhappy path, invalid index
1:
	xor	%rax, %rax			# Sets %rax to NULL
	ret

# @function	ArrayStack_set
# @description	Set the element at a position
# @param	%rdi	Address of the arraystack
# @param	%rsi	The index of the element to set
# @param	%rdx	The address of the element to set
# @param	%rax	The address of the element
ArrayStack_set:
	# Validates the passed index
	mov	ArrayStack.length(%rdi), %ecx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	mov	ArrayStack.data(%rdi), %rax	# %rax now holds the address of "data"
	mov	%rdx, (%rax, %rsi, 1<<3)
	mov	%rdx, %rax
	ret
# Unhappy path, invalid index
1:
	xor	%rax, %rax			# Sets %rax to NULL
	ret

# @function	ArrayStack_add
# @description	Add an element at a position. The indexes of existing data will shift to 
#		accomodate the new element
# @param	%rdi	Address of the arraystack
# @param	%rsi	The index of the element to add
# @param	%rdx	The address of the element
# @return	%rax	The address of the element
ArrayStack_add:
	push	%rbx				# The arraystack
	push	%r12				# The length
	push	%r13				# Index of element to add
	push	%r14				# The address of the element to add

	mov	%rdi, %rbx
	mov	%rsi, %r13
	mov	%rdx, %r14

	# Validates the passed index. Equals is ok in ONLY this case since we are adding
	mov	ArrayStack.length(%rbx), %r12d	# Length of array in %rcx
	cmp	%r13, %r12
	jc	2f				# If there's carry it's either too big or negative

	# Check if a resize is needed ...
	mov	%r12d, %eax
	imul	$8, %eax			# Size is in bytes
	cmp	ArrayStack.size(%rbx), %eax
	jge	3f

1:
	incl	ArrayStack.length(%rbx)		# Update length (plus one)

	# movsq
	mov	ArrayStack.data(%rbx), %rax	# Address of "data"
	mov	%r12, %rcx			# Total number of moves needed is length ...
	sub	%r13, %rcx			# Minus target index
	lea	-8(%rax, %r12, 8), %rsi		# Source is minus 8 offset bc array uses zero index
	lea	(%rax, %r12, 8), %rdi		# Destination
	std					# IMPORTANT!! This must copy  backwards ...
	rep	movsq				# As forwards will make every entry the first
	cld

	mov	%r14, (%rax, %r13, 1<<3)	# Finally, insert new element
	mov	%r14, %rax

	pop	%r14
	pop	%r13
	pop	%r12
	pop	%rbx
	ret

# Unhappy path, invalid index
2:
	xor	%rax, %rax			# Sets %rax to NULL
	ret

# Resize needed
3: 
	call	ArrayStack_resize
	jmp	1b


# @function	ArrayStack_remove
# @description	Remove an element at a position. The indexes of the existing data will shift to
#		accomodate the removal
# @param	%rdi	Address of the arraystack
# @param	%rsi	The index of the element to remove
# @return	%rax	The address of the element
ArrayStack_remove:
	push	%rbx				# The arraystack instance
	push	%r12				# The requested index
	push	%r13				# Return value (element being removed)

	mov	%rdi, %rbx
	mov	%rsi, %r12

	# Validates the passed index
	mov	ArrayStack.length(%rbx), %ecx	# Length of array in %rcx
	cmp	%r12, %rcx
	jc	2f				# If there's carry it's either too big or negative
	jz	2f				# Also need to check for equals

	decq	ArrayStack.length(%rbx)		# Update length (minus one)

	mov	ArrayStack.data(%rbx), %rdx	# Pointer to "data"
	mov	(%rdx, %r12, 1<<3), %r13	# Return value for %rax (element being removed)

	# movsq
	sub	%r12, %rcx			# Total number of reps needed is one less than the
	dec	%rcx				# length bc in this case we are removing an item
	lea	(%rdx, %r12, 1<<3), %rdi	# Destination
	lea	8(%rdx, %r12, 1<<3), %rsi	# Source
	rep	movsq

	# Check if a resize is needed ...
	mov	ArrayStack.length(%rbx), %eax
	imul	$24, %eax			# We resize down when size is 3x the length
	cmp	ArrayStack.size(%rbx), %eax
	jle	3f

1:
	mov	%r13, %rax
	pop	%r13
	pop	%r12
	pop	%rbx
	ret

# Unhappy path, invalid index
2:
	xor	%rax, %rax			# Sets %rax to NULL
	ret

# Resize needed
3: 
	mov	%rbx, %rdi
	call	ArrayStack_resize
	jmp	1b

# @function	ArrayStack_resize
# @description	Resize the arraystack, necessary when adding an element will cause it to overflow
#		its bounds or removing an element will leave too much wasted space
# @param	%rdi	Address of the ArrayStack
# @return	rax	Void
.type	ArrayStack_resize, @function
ArrayStack_resize:
	push	%rbx				# The arraystack
	push	%r12				# The length
	push	%r13				# The size

	mov	%rdi, %rbx
	mov	ArrayStack.length(%rbx), %r12d

	# NEVER go to zero length bc that is unrecoverable as size is a multiple of length
	cmp	$0, %r12d
	je	1f

	# We aim to have double the length available and each item is 8 bytes so the multiplier is
	# 16x
	mov	$16, %r13d
	imul	%r12d, %r13d

	# Allocate a new array, pointer to new memory location is in %rax
	mov	%r13, %rdi
	call	alloc
	# TODO: Error handling + Need to call FREE!!

	# Move current data to new allocation (movsq)
	mov	%r12, %rcx			# Count of moves
	mov	ArrayStack.data(%rbx), %rsi	# Source pointer
	mov	%rax, %rdi			# Destination pointer
	rep	movsq

	mov	%rax, ArrayStack.data(%rbx)	# Update pointer to data
	mov	%r13d, ArrayStack.size(%rbx)

1:
	pop	%r13
	pop	%r12
	pop	%rbx
	ret

# @function	ArrayStack_log
# @description	Log the arraystack as a string
# @param	%rdi	Address of the arraystack
# @return	void
.type	ArrayStack_log, @function
ArrayStack_log:
	push	%rbx				# ArrayStack instance
	push	%r12				# ArrayStack length minus one
	push	%r13				# ArrayStack data
	push	%r14				# Print index

	mov	%rdi, %rbx

	mov	$start_delim, %rdi
	call	log

	mov	ArrayStack.length(%rbx), %r12d
	mov	ArrayStack.data(%rbx), %r13

	xor	%r14, %r14			# Zero out addressing index
# Loop all the items
1:
	mov	(%r13, %r14, 8), %rdi
	call	log
	inc	%r14
	cmp	%r12, %r14
	jge	2f				# Skip middle delimiter for last iteration

	mov	$mid_delim, %rdi
	call	log
	jmp	1b
2:
	mov	$end_delim, %rdi
	call	log

	pop	%r14
	pop	%r13
	pop	%r12
	pop	%rbx
	ret
