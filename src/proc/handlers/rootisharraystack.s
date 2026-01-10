# proc/handlers/rootisharraystack.s - Handlers for RootishArrayStack

.include	"structs.inc"

.globl	rootisharraystack, rootisharraystack_handler

	.struct	0
RootishArrayStack.blocks:
	.struct	RootishArrayStack.blocks + 1<<3
RootishArrayStack.length:
	.struct	RootishArrayStack.length + 1<<2
	.equ	ROOTISHARRAYSTACK_SIZE, .

.section .rodata

.type	rootisharraystack, @object
rootisharraystack:
	.ascii	"rootisharraystack\0"

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
	.quad	RootishArrayStack_get
	.quad	RootishArrayStack_set
	.quad	RootishArrayStack_add
	.quad	RootishArrayStack_remove

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

null:
	.ascii	"NULL\0"

length_label:
	.ascii	"Length => \0"

blocks_label:
	.ascii	"Blocks => \0"

raw_label:
	.ascii	"Raw => \0"

rs_delim:
	.ascii	"{\0"

re_delim:
	.ascii	"}\n\0"

ree_delim:
	.ascii	"]\n\0"

spacer:
	.ascii	"  \0"

divider:
	.ascii	" => \0"
.section .bss

this:
	.zero	1<<3

.section .text

# @function	rootisharraystack_handler
# @description	Handler for the "rootisharraystack" command
# @param	%rdi	Pointer to Input
# @return	void
.type	rootisharraystack_handler, @function
rootisharraystack_handler:
	push	%rbp
	mov	%rsp, %rbp

	cmpq	$0, this
	je	new

handler:
	mov	Input.argv + 8(%rbx), %rdi	# Second argument is the operation
	xor	%r12, %r12			# Index of found operation

	cmpq	$1, Input.argc(%rbx)		# If only one argument, print the arraystack ... 
	je	4f

	cmpq	$3, Input.argc(%rbx)		# Otherwise, we must have 3 arguments to be valid
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

	mov	this, %rdi			# Ensure instance is in place
	call	*handlers(, %r12, 8)		# Call the handler

	mov	$null, %r12
	mov	%rax, %rdi
	cmp	$0, %rax
	cmove	%r12, %rdi
	call	log

	mov	$newline, %rdi
	call	log

4:
	mov	this, %rdi
	call	RootishArrayStack_log
3:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp 3b

# Initialization
new:
	call	RootishArrayStack_ctor
	mov	%rax, this
	jmp	handler

# @function	RootishArrayStack_ctor
# @description	RootishArrayStack constructor
# @return	%rax	Pointer to the RootishArrayStack
.equ	THIS, -8
.equ	BLOCKS, -16
RootishArrayStack_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	$ROOTISHARRAYSTACK_SIZE, %rdi
	call	alloc
	mov	%rax, THIS(%rbp)

	call	ArrayStack_ctor
	mov	%rax, %rcx

	mov	THIS(%rbp), %rax
	mov	%rcx, RootishArrayStack.blocks(%rax)
	movl	$0, RootishArrayStack.length(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	RootishArrayStack_get
# @description	Gets the value at the specified index
# @param	%rdi	Pointer to the RootishArrayStack
# @param	%rsi	Index to get
# @return	%rax	Pointer to the element
.equ	THIS, -8
.equ	KEY, -16
.equ	BIDX, -24
RootishArrayStack_get:
	push	%rbp
	mov	%rsp, %rbp

	# Validates the passed index
	mov	RootishArrayStack.length(%rdi), %ecx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, KEY(%rbp)

	# Obtain which block the value is in
	mov	%rsi, %rdi
	call	i2b
	mov	%rax, BIDX(%rbp)

	# Now that we know which block, we need to figure which key in that block
	mov	%rax, %rcx	# Multiply block index by itself plus one
	inc	%rcx
	imul	%rcx, %rax
	xor	%rdx, %rdx	# Divide by two
	mov	$2, %rcx
	div	%rcx

	sub	%rax, KEY(%rbp)	# And subtract from the key that was passed in

	mov	THIS(%rbp), %rdi
	mov	RootishArrayStack.blocks(%rdi), %rdi
	mov	BIDX(%rbp), %rsi
	call	ArrayStack_get

	mov	KEY(%rbp), %rcx

	mov	THIS(%rbp), %rdi
	mov	(%rax, %rcx, 1<<3), %rax

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# Bad index error
1:
	xor	%rax, %rax
	jmp	2b

# @function	RootishArrayStack_set
# @description	Sets the value at the specified index
# @param	%rdi	Pointer to a RootishArrayStack
# @param	%rsi	The index to set
# @param	%rdx	Pointer to the value
# @return	%rax	Returns the previous value
.equ	THIS, -8
.equ	KEY, -16
.equ	VAL, -24
.equ	BIDX, -32
RootishArrayStack_set:
	push	%rbp
	mov	%rsp, %rbp

	# Validates the passed index
	mov	RootishArrayStack.length(%rdi), %ecx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, KEY(%rbp)
	mov	%rdx, VAL(%rbp)

	# Obtain which block the value is in
	mov	%rsi, %rdi
	call	i2b
	mov	%rax, BIDX(%rbp)

	# Now that we know which block, we need to figure which key in that block
	mov	%rax, %rcx	# Multiply block index by itself plus one
	inc	%rcx
	imul	%rcx, %rax
	xor	%rdx, %rdx	# Divide by two
	mov	$2, %rcx
	div	%rcx

	sub	%rax, KEY(%rbp)	# And subtract from the key that was passed in

	mov	THIS(%rbp), %rdi
	mov	RootishArrayStack.blocks(%rdi), %rdi
	mov	BIDX(%rbp), %rsi
	call	ArrayStack_get

	mov	%rax, %r8
	mov	KEY(%rbp), %rcx
	mov	VAL(%rbp), %rdx
	mov	(%r8, %rcx, 1<<3), %rax			# Set to return the previous value
	mov	%rdx, (%r8, %rcx, 1<<3)			# Set the new value

	mov	THIS(%rbp), %rdi			# Restore "this" pointer
	mov	VAL(%rbp), %rax

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# Bad index error
1:
	xor	%rax, %rax
	jmp	2b

# @function	RootishArrayStack_add
# @description	Adds an element at the specified index
# @param	%rdi	Pointer to the RootishArrayStack
# @param	%rsi	Index of the item
# @param	%rdx	Pointer to the item
# @return	%rax	Pointer to the item
.equ	THIS, -8
.equ	KEY, -16
.equ	VAL, -24
.equ	LEN, -32
.equ	BSIZE, -40
.equ	CTR, -48
RootishArrayStack_add:
	push	%rbp
	mov	%rsp, %rbp

	# Validates the passed index
	mov	RootishArrayStack.length(%rdi), %ecx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	5f				# If there's carry it's either too big or negative

	# Variables
	sub	$48, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, KEY(%rbp)
	mov	%rdx, VAL(%rbp)
	mov	RootishArrayStack.length(%rdi), %eax
	mov	%rax, LEN(%rbp)
	mov	RootishArrayStack.blocks(%rdi), %rdi
	call	ArrayStack_length
	mov	%rax, BSIZE(%rbp)

	# Check if we need to grow ...
	mov	%rax, %rcx				# Start with block size ...
	inc	%rcx					# Plus one it and ...
	imul	%rcx, %rax				# Multiply it by itself ...
	xor	%rdx, %rdx				# Then divide by 2
	mov	$2, %rcx
	div	%rcx

	cmp	LEN(%rbp), %rax				# If less than the length + 1 we grow
	jle	grow

2:
	mov	THIS(%rbp), %rdi
	incl	RootishArrayStack.length(%rdi)

	# Shift all elements higher than the specified index
	mov	RootishArrayStack.length(%rdi), %rsi
	mov	%rsi, CTR(%rbp)
	jmp	4f

# Shift loop
3:
	dec	%rsi
	call	RootishArrayStack_get
	mov	CTR(%rbp), %rsi
	mov	%rax, %rdx
	call	RootishArrayStack_set

4:
	decq	CTR(%rbp)
	mov	CTR(%rbp), %rsi
	cmp	KEY(%rbp), %rsi
	jg	3b

	# Done shifting, set the new value
	mov	KEY(%rbp), %rsi
	mov	VAL(%rbp), %rdx
	call	RootishArrayStack_set

6:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# Bad index error
5:
	xor	%rax, %rax
	jmp	6b

# Growth needed
grow:
	mov	BSIZE(%rbp), %rdi	
	inc	%rdi
	imul	$1<<3, %rdi
	call	alloc

	mov	THIS(%rbp), %rdi
	mov	RootishArrayStack.blocks(%rdi), %rdi
	mov	BSIZE(%rbp), %rsi
	mov	%rax, %rdx
	call	ArrayStack_add
	jmp	2b

# @function	RootishArrayStack_remove
# @description	Remove the element at the specified index
# @param	%rdi	Pointer to the RootishArrayStack
# @param	%rsi	Index to remove
# @return	%rax	Pointer to the removed element
.equ	THIS, -8
.equ	KEY, -16
.equ	VAL, -24
.equ	BSIZE, -32
.equ	CTR, -40
RootishArrayStack_remove:
	push	%rbp
	mov	%rsp, %rbp

	# Validates the passed index
	mov	RootishArrayStack.length(%rdi), %ecx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	4f				# If there's carry it's either too big or negative
	jz	4f				# Also need to check for equals

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, KEY(%rbp)
	mov	%rsi, CTR(%rbp)
	call	RootishArrayStack_get
	mov	%rax, VAL(%rbp)
	mov	RootishArrayStack.blocks(%rdi), %rdi
	call	ArrayStack_length
	mov	%rax, BSIZE(%rbp)

	# Shift the elements to the right of the index left by one position
	mov	THIS(%rbp), %rdi
	jmp	2f

# Shift loop
1:
	inc	%rsi
	call	RootishArrayStack_get
	mov	%rax, %rdx
	mov	CTR(%rbp), %rsi
	call	RootishArrayStack_set
	incq	CTR(%rbp)

2:
	mov	CTR(%rbp), %rsi
	mov	RootishArrayStack.length(%rdi), %rax
	dec	%rax
	cmp	%rax, %rsi
	jl	1b

	# Decrement length
	decl	RootishArrayStack.length(%rdi)
	mov	BSIZE(%rbp), %rax
	dec	%rax					# This is %rax (BSIZE) - 1 and ...
	mov	%rax, %rcx				# itself (BSIZE) ...
	dec	%rcx					# minus 2
	imul	%rcx, %rax				# multiplied
	mov	$2, %rcx				# Then divided by 2
	xor	%rdx, %rdx
	div	%rcx

	mov	THIS(%rbp), %rdi
	cmp	RootishArrayStack.length(%rdi), %eax
	jge	shrink

3:
	# Tee up return value
	mov	VAL(%rbp), %rax

5:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# Bad index error
4:
	xor	%rax, %rax
	jmp	5b

# Shrinking needed
shrink:
	mov	RootishArrayStack.length(%rdi), %r8d
	mov	RootishArrayStack.blocks(%rdi), %rdi
	mov	BSIZE(%rbp), %r9
	jmp	5f
4:
	call	ArrayStack_length
	mov	%rax, %rsi
	dec	%rsi
	call	ArrayStack_remove

	dec	%r9
5:
	mov	%r9, %rax
	dec	%rax
	mov	%r8, %rcx
	dec	%rcx
	imul	%rcx, %rax
	mov	$2, %rcx
	xor	%rdx, %rdx
	div	%rcx
	cmp	%r8, %rax
	jge	4b

	mov	THIS(%rbp), %rdi

	jmp	3b

# @function	RootishArrayStack_log
# @description	Log the innards of a RootishArrayStack
# @param	%rdi	Pointer to the RootishArrayStack
# @return	void
.equ	THIS, -8
.equ	LENGTH, -16
.equ	CTR, -24
.equ	ICTR, -32
.equ	ARGS, -40
RootishArrayStack_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	RootishArrayStack.length(%rdi), %eax
	mov	%rax, LENGTH(%rbp)
	movq	$0, CTR(%rbp)

	mov	$start_delim, %rdi
	call	log

	cmpq	$0, LENGTH(%rbp)
	je	2f

# Print loop
1:
	mov	THIS(%rbp), %rdi
	mov	CTR(%rbp), %rsi
	call	RootishArrayStack_get

	mov	%rax, %rdi
	call	log

	incq	CTR(%rbp)
	mov	CTR(%rbp), %rsi
	cmp	LENGTH(%rbp), %rsi
	jge	2f

	mov	$mid_delim, %rdi
	call	log
	jmp	1b

# Done printing values, still need to print the end delimiter
2:
	mov	$end_delim, %rdi
	call	log

	mov	$length_label, %rdi
	call	log

	mov	LENGTH(%rbp), %rdi
	call	itoa

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$blocks_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	RootishArrayStack.blocks(%rdi), %rdi
	call	ArrayStack_length

	mov	%rax, %rdi
	call	itoa

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$raw_label, %rdi
	call	log

	mov	$rs_delim, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	movq	$0, CTR(%rbp)
	movq	$0, ARGS(%rbp)
	jmp	4f

1:
	mov	$spacer, %rdi
	call	log

	mov	CTR(%rbp), %rdi
	inc	%rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$divider, %rdi
	call	log

	mov	$start_delim, %rdi
	call	log

	movq	$0, ICTR(%rbp)
	jmp	3f

2:
	mov	THIS(%rbp), %rdi
	mov	RootishArrayStack.length(%rdi), %rdi
	cmp	%rdi, ARGS(%rbp)
	jge	5f

	mov	THIS(%rbp), %rdi
	mov	RootishArrayStack.blocks(%rdi), %rdi
	mov	CTR(%rbp), %rsi
	call	ArrayStack_get

	incq	ARGS(%rbp)

	mov	ICTR(%rbp), %rcx
	mov	(%rax, %rcx, 1<<3), %rdi
	call	log


5:
	incq	ICTR(%rbp)
	mov	ICTR(%rbp), %rcx
	dec	%rcx
	cmp	CTR(%rbp), %rcx
	jge	3f

	mov	$mid_delim, %rdi
	call	log

3:
	mov	ICTR(%rbp), %rcx
	dec	%rcx
	cmp	CTR(%rbp), %rcx
	jl	2b

	mov	$ree_delim, %rdi
	call	log

	incq	CTR(%rbp)

4:
	mov	THIS(%rbp), %rdi
	mov	RootishArrayStack.blocks(%rdi), %rdi
	call	ArrayStack_length
	cmp	%rax, CTR(%rbp)
	jl	1b
	
	mov	$re_delim, %rdi
	call	log

	mov	THIS(%rbp), %rdi

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	i2b
# @description	Determine which block an index belongs to
# @param	%rdi	Any index
# @return	%rax	The index of the block
i2b:
	imul		$8, %rdi		# Multiply by 8
	add		$9, %rdi		# Add 9
	cvtsi2ss	%rdi, %xmm0		# Convert to scalar
	sqrtss		%xmm0, %xmm0		# Obtain square root
	mov		$3, %rdi		# We need to subtract 3 but first we need to ...
	cvtsi2ss	%rdi, %xmm1		# convert 3 to scalar
	subss		%xmm1, %xmm0		# Subtract 3
	mov		$2, %rdi		# We need to divide by 2 but first we need to ...
	cvtsi2ss	%rdi, %xmm1		# convert 2 to a scalar
	divss		%xmm1, %xmm0		# Divide by 2
	roundss		$10, %xmm0, %xmm0	# Round up (ceiling)
	cvttss2siq	%xmm0, %rax		# Convert back to integer
	ret
