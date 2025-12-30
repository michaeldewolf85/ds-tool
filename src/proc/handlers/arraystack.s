# proc/handlers/array-stack.s - ArrayStack handler

.include	"common.inc"
.include	"structs.inc"

.globl	arraystack, arraystack_handler

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

# Arraystack command string
.type	arraystack, @object
arraystack:
	.ascii	"arraystack\0"

get:
	.ascii	"get\0"
set:
	.ascii	"set\0"
add:
	.ascii	"add\0"
remove:
	.ascii	"remove\0"

commands:
	.quad	get
	.quad	set
	.quad	add
	.quad	remove
	.quad	0	# Sentinel

handlers:
	.quad	ArrayStack_get
	.quad	ArrayStack_set
	.quad	ArrayStack_add
	.quad	ArrayStack_remove

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

# Static pointer to the one and only ArrayStack instance
instance:
	.zero	1<<3

.section .text

# @function	arraystack_handler
# @description	Handler for the arraystack set of commands
# @param	%rdi	Pointer to the Input struct
# @return	void
.type	arraystack_handler, @function
arraystack_handler:
	push	%rbx
	push	%r12
	mov	%rdi, %rbx

	mov	instance, %rdi
	cmp	$NULL, %rdi
	je	new

1:
	mov	Input.argv + 8(%rbx), %rdi	# Second argument is the operation
	xor	%r12, %r12			# Index of found operation

	cmp	$3, Input.argc(%rbx)		# Must be at least 3 arguments to be valid
	jl	error

check:
	mov	commands(, %r12, 8), %rsi
	cmp	$0, %rsi			# Check for the sentinel, if we match here the 
	je	error				# command was not found

	call	strcmp
	cmp	$0, %rax
	je	match

	inc	%r12
	jmp	check

match:
	mov	Input.argv + 16(%rbx), %rdi	# Third argument is always an index
	call	atoi
	cmp	$0, %rax
	jl	error

	mov	%rax, %rsi
	mov	Input.argv + 24(%rbx), %rdx	# Third argument may be a string pointer

	mov	instance, %rdi			# Ensure instance is in place
	call	*handlers(, %r12, 8)		# Call the handler

	mov	$null, %r12
	mov	%rax, %rdi
	cmp	$0, %rax
	cmove	%r12, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	instance, %rdi
	call	ArrayStack_log

3:
	pop	%r12
	pop	%rbx
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp 3b

# No instance yet, so create one
new:
	call	ArrayStack_ctor
	mov	%rax, instance
	jmp	1b

# @function	constructor
# @public
# @description	Initializes an ArrayStack
# @return	%rax	A pointer to the ArrayStack

.type	ArrayStack_ctor, @function
ArrayStack_ctor:
	push	%rbx

	# Allocation for the arraystack's metadata
	mov	$ARRAYSTACK_SIZE, %rdi
	call	alloc
	# TODO: Error handling
	mov	%rax, %rbx

	# Allocation for the arraystack's data
	mov	$ARRAYSTACK_START_SIZE, %rdi
	call	alloc
	# TODO: Error handling

	mov	%rax, ArrayStack.data(%rbx)
	movl	$ARRAYSTACK_START_SIZE, ArrayStack.size(%rbx)
	movl	$0, ArrayStack.length(%rbx)
	mov	%rbx, %rax

	pop	%rbx
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

4:
	pop	%r14
	pop	%r13
	pop	%r12
	pop	%rbx
	ret

# Unhappy path, invalid index
2:
	xor	%rax, %rax			# Sets %rax to NULL
	jmp	4b

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
	xor	%r13, %r13			# Sets %rax to NULL
	jmp	1b

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

	cmp	$0, %r12d
	je	2f

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
