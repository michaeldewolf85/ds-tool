# proc/handlers/array-stack.s - ArrayStack handler

.include	"common.inc"

.globl	dickens

# ArrayStack
	.struct	0
ArrayStack.vtable:
	.struct	ArrayStack.vtable + 1<<3
ArrayStack.size:
	.struct	ArrayStack.size + 1<<3
ArrayStack.length:
	.struct	ArrayStack.length + 1<<3
ArrayStack.items:
	.struct	ArrayStack.items + 1<<3
	.equ	ARRAYSTACK_SIZE, .

# ArrayStack vtable
	.struct 0
ArrayStack.get:
	.struct	ArrayStack.get + 1<<3
ArrayStack.set:
	.struct	ArrayStack.set + 1<<3
ArrayStack.add:
	.struct	ArrayStack.add + 1<<3
ArrayStack.remove:
	.struct	ArrayStack.remove + 1<<3

.section .rodata

ArrayStack_vtable:
	.quad	ArrayStack_get
	.quad	ArrayStack_set
	.quad	ArrayStack_add
	.quad	ArrayStack_remove

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

instance:
	.skip	ARRAYSTACK_SIZE

items:
	.skip	1<<3 * 10

.section .text

.type	dickens, @function
dickens:
	call	ArrayStack_ctor
	mov	%rax, %r12

	# vtable in %rax
	mov	(%r12), %rbx

	mov	%r12, %rdi
	mov	$0, %rsi
	call	*ArrayStack.get(%rbx)

	mov	%r12, %rdi
	mov	$0, %rsi
	mov	$item1, %rdx
	call	*ArrayStack.add(%rbx)

	mov	%r12, %rdi
	mov	$0, %rsi
	mov	$item2, %rdx
	call	*ArrayStack.add(%rbx)

	mov	%r12, %rdi
	mov	$0, %rsi
	mov	$item3, %rdx
	call	*ArrayStack.add(%rbx)

	mov	%r12, %rdi
	mov	$0, %rsi
	call	*ArrayStack.get(%rbx)

	mov	%r12, %rdi
	mov	$3, %rsi
	call	*ArrayStack.get(%rbx)

	mov	%r12, %rdi
	mov	$4, %rsi
	call	*ArrayStack.get(%rbx)

	mov	%r12, %rdi
	mov	$0, %rsi
	call	*ArrayStack.get(%rbx)

	mov	%r12, %rdi
	mov	$-1, %rsi
	call	*ArrayStack.get(%rbx)

	mov	%r12, %rdi
	mov	$-2, %rsi
	call	*ArrayStack.get(%rbx)

	ret

# @function	constructor
# @public
# @description	Initializes an ArrayStack
# @return	%rax	A pointer to the ArrayStack

.type	ArrayStack_ctor, @function
ArrayStack_ctor:
	movq	$ArrayStack_vtable, instance + ArrayStack.vtable
	movq	$10, instance + ArrayStack.size
	movq	$0, instance + ArrayStack.length
	movq	$items, instance + ArrayStack.items
	mov	$instance, %rax
	ret

# @function	get
# @public
# @description	Get the element at a position
# @param	%rdi	Address of the arraystack
# @param	%rsi	The index of the element to get
# @return	%rax	The address of the element or NULL
ArrayStack_get:
	# Validates the passed index
	mov	ArrayStack.length(%rdi), %rcx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	mov	ArrayStack.items(%rdi), %rax	# %rax now holds the address of "items"
	mov	(%rax, %rsi, 1<<3), %rax
	ret
# Unhappy path, invalid index
1:
	xor	%rax, %rax			# Sets %rax to NULL
	ret

# @function	set
# @public
# @description	Set the element at a position
# @param	%rdi	Address of the arraystack
# @param	%rsi	The index of the element to set
# @param	%rdx	The address of the element to set
# @param	%rax	The address of the element
ArrayStack_set:
	# Validates the passed index
	mov	ArrayStack.length(%rdi), %rcx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	mov	ArrayStack.items(%rdi), %rax	# %rax now holds the address of "items"
	mov	%rdx, (%rax, %rsi, 1<<3)
	mov	%rdx, %rax
	ret
# Unhappy path, invalid index
1:
	xor	%rax, %rax			# Sets %rax to NULL
	ret

# @function	add
# @public
# @description	Add an element at a position. The indexes of existing items will shift to 
#		accomodate the new element
# @param	%rdi	Address of the arraystack
# @param	%rsi	The index of the element to add
# @param	%rdx	The address of the element
# @return	%rax	The address of the element
ArrayStack_add:
	# Validates the passed index. Equals is ok in ONLY this case since we are adding
	mov	ArrayStack.length(%rdi), %rcx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	1f				# If there's carry it's either too big or negative

	mov	ArrayStack.items(%rdi), %rax	# Pointer to "items"
	incq	ArrayStack.length(%rdi)		# Update length (plus one)

	mov	%rsi, %r8			# Preserve %rsi as it gets overwritten during movsq

	# movsq
	sub	%r8, %rcx			# Total number of moves needed
	lea	-8(%rax, %rcx, 1<<3), %rsi	# Source, minus 8 offset to account for zero index
	lea	(%rax, %rcx, 1<<3), %rdi	# Destination
	std					# IMPORTANT!! Decrement and move backwards. 
	rep	movsq				# Forward movement will make every entry the first
	cld

	mov	%rdx, (%rax, %r8, 1<<3)		# Insert element

	mov	%rdx, %rax
	ret
# Unhappy path, invalid index
1:
	xor	%rax, %rax			# Sets %rax to NULL
	ret

# @function	remove
# @public
# @description	Remove an element at a position. The indexes of the existing items will shift to
#		accomodate the removal
# @param	%rdi	Address of the arraystack
# @param	%rsi	The index of the element to remove
# @return	%rax	The address of the element
ArrayStack_remove:
	# Validates the passed index
	mov	ArrayStack.length(%rdi), %rcx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	mov	ArrayStack.items(%rdi), %rdx	# Pointer to "items"
	decq	ArrayStack.length(%rdi)		# Update length (minus one)
	mov	(%rax, %rsi, 1<<3), %rax	# Return value in %rax (element being removed)

	# movsq
	sub	%rsi, %rcx			# Total number of reps needed is one less than the
	dec	%rcx				# length bc in this case we are removing an item
	lea	(%rdx, %rsi, 1<<3), %rdi	# Destination
	lea	8(%rdx, %rsi, 1<<3), %rsi	# Source
	rep	movsq
	ret
# Unhappy path, invalid index
1:
	xor	%rax, %rax			# Sets %rax to NULL
	ret
