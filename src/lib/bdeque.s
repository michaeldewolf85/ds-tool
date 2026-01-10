# lib/bdeque.s - BDeque data structure

.include	"common.inc"

.globl	BDeque_ctor, BDeque_dtor, BDeque_length, BDeque_get, BDeque_set, BDeque_add, BDeque_remove
.globl	BDeque_log

# BDeque
	.struct	0
BDeque.data:
	.struct	BDeque.data + 1<<3
BDeque.len:
	.struct	BDeque.len + 1<<3
BDeque.idx:
	.struct BDeque.idx + 1<<3
BDeque.size:
	.struct	BDeque.size + 1<<3
	.equ	BDEQUE_SIZE, .

.section .rodata

s_delim:
	.ascii	"[ \0"
m_delim:
	.ascii	", \0"
e_delim:
	.ascii	" ]\0"
null:
	.ascii	"\0"

.section .text

# Calculates the "actual" index of the key in register %idx and puts it in %rdx
.macro	calc_index, idx
	mov	\idx, %rax
	add	BDeque.idx(%rdi), %rax
	xor	%rdx, %rdx
	divq	BDeque.size(%rdi)
.endm

# @function	BDeque_ctor
# @description	Creates a new BDeque instance
# @param	%rdi	Bounds of the BDeque (i.e. maximum size)
# @return	%rax	Pointer to the new BDeque instance or NULL on failure
.equ	SIZE, -8
.equ	DATA, -16
.type	BDeque_ctor, @function
BDeque_ctor:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$16, %rsp
	mov	%rdi, SIZE(%rbp)

	# Validate bounds
	cmp	$0, %rdi
	jle	1f

	mov	%rdi, %r9		# Preserve bounds

	# Allocate memory for "data"
	imul	$1<<3, %rdi
	call	alloc
	mov	%rax, DATA(%rbp)		# Preserve pointer to "data"


	# Allocate memory for the BDeque
	mov	$BDEQUE_SIZE, %rdi
	call	alloc

	# Assign properties
	mov	DATA(%rbp), %rcx
	movq	%rcx, BDeque.data(%rax)
	movq	$0, BDeque.len(%rax)
	movq	$0, BDeque.idx(%rax)
	mov	SIZE(%rbp), %rcx
	mov	%rcx, BDeque.size(%rax)

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret
# Invalid bounds
1:
	xor	%rax, %rax
	jmp	2b

# @function	BDeque_dtor
# @description	Free a BDeque
# @param	%rdi	Pointer to the BDeque to free
# @return	void
BDeque_dtor:
	push	%rdi

	mov	BDeque.data(%rdi), %rdi
	call	free

	pop	%rdi
	call	free

	ret

# @function	BDeque_length
# @description	Get the length of the BDeque
# @param	%rdi	Pointer to the BDeque
# @return	%rax	The length of the BDeque
.type	BDeque_length, @function
BDeque_length:
	mov	BDeque.len(%rdi), %rax
	ret

# @function	BDeque_get
# @description	Get the value at the specified key
# @param	%rdi	Pointer to the BDeque
# @param	%rsi	The key to set
# @return	%rax	The value or NULL if undefined
.type	BDeque_get, @function
BDeque_get:
	# Index checking (not greater than / equal to the length or less than zero)
	cmp	%rsi, BDeque.len(%rdi)
	jc	1f
	je	1f

	CALC_INDEX %rsi
	mov	BDeque.data(%rdi), %rax
	mov	(%rax, %rdx, 1<<3), %rax
	ret
# Out of bounds
1:
	xor	%rax, %rax
	ret

# @function	BDeque_set
# @description	Replace the value at the specified key
# @param	%rdi	Pointer to the BDeque
# @param	%rsi	The key to set
# @param	%rdx	The value to set
# @return	%rax	The PREVIOUS value or NULL if undefined
.type	BDeque_set, @function
BDeque_set:
	# Index checking (not greater than / equal to the length or less than zero)
	cmp	%rsi, BDeque.len(%rdi)
	jc	1f
	je	1f

	mov	%rdx, %rcx			# Preserve value as %rdx is clobbered by CALC_INDEX
	CALC_INDEX %rsi
	mov	BDeque.data(%rdi), %r8
	mov	(%r8, %rdx, 1<<3), %rax		# Populate return value
	mov	%rcx, (%r8, %rdx, 1<<3)
	ret
# Out of bounds
1:
	xor	%rax, %rax
	ret

# @function	BDeque_add
# @description	Insert a value at the specified key. Existing values will shift right.
# @param	%rdi	Pointer to the BDeque
# @param	%rsi	The key to insert at
# @param	%rdx	The value to insert
# @param	%rax	The value that was inserted or NULL if the insertion failed
.type	BDeque_add, @function
BDeque_add:
	# Bounds checking (check if the deque is full)
	mov	BDeque.len(%rdi), %rax
	cmp	BDeque.size(%rdi), %rax
	jge	1f

	# Index checking (not greater than length or less than zero)
	cmp	%rsi, %rax
	jc	1f			# In the case of "add" equals length is valid

	# Put "data" and value out of the way in %r8 and %r9  where they won't be clobbered
	mov	BDeque.data(%rdi), %r8
	mov	%rdx, %r9

	# Divides length by 2 to see which half of the backing array is impacted by the operation
	mov	BDeque.len(%rdi), %rax
	mov	$2, %rcx
	xor	%rdx, %rdx
	div	%rcx

	cmp	%rax, %rsi
	jge	3f

	# Key is in lower half of backing array so we are moving all preceding elements left
	# First we decrement the index
	mov	$-1, %rcx
	CALC_INDEX %rcx
	mov	%rdx, BDeque.idx(%rdi)

	xor	%rcx, %rcx		# Loop counter = 0
2:
	cmp	%rcx, %rsi
	je	5f

	# Destination index (%r10)
	CALC_INDEX %rcx
	mov	%rdx, %r10

	# Source index (%rdx)
	inc	%rcx
	CALC_INDEX %rcx

	# Move source (%rdx) => destination (%r10)
	mov	(%r8, %rdx, 1<<3), %rax	# Source value
	mov	%rax, (%r8, %r10, 1<<3)		# Move source value to destination
	jmp	2b
3:
	# Key is in upper half of backing array so we are moving all suceeding elements right
	mov	BDeque.len(%rdi), %rcx		# Loop counter = length
4:
	cmp	%rcx, %rsi
	je	5f

	# Destination index (%r10)
	CALC_INDEX %rcx
	mov	%rdx, %r10

	# Source index (%rdx)
	dec	%rcx
	CALC_INDEX %rcx

	# Move source (%rdx) => destination (%r10)
	mov	(%r8, %rdx, 1<<3), %rax		# Source value
	mov	%rax, (%r8, %r10, 1<<3)		# Move source value to destination
	jmp	4b
5:
	# Finally add the new element to the backing array, in either path KEY is already in %rsi
	CALC_INDEX %rsi
	mov	%r9, (%r8, %rdx, 1<<3)		# Move new item into place

	# Increment the length
	incq	BDeque.len(%rdi)

	mov	%r9, %rax			# Return value
	ret
# Out of bounds
1:
	xor	%rax, %rax
	ret

# @function	BDeque_remove
# @description	Remove the element at the specified index
# @param	%rdi	Pointer to the BDeque
# @param	%rsi	Index of the element to remove
# @return	%rax	Pointer to the removed element
.type	BDeque_remove, @function
BDeque_remove:
	# Index checking (not greater than / equal to the length or less than zero)
	cmp	%rsi, BDeque.len(%rdi)
	jc	1f
	je	1f

	# Put "data" and return value out of the way in %r8 iand $r9 where they won't be clobbered
	mov	BDeque.data(%rdi), %r8
	CALC_INDEX %rsi
	mov	(%r8, %rdx, 1<<3), %r9

	# Divides length by 2 to see which half of the backing array is impacted by the operation
	mov	BDeque.len(%rdi), %rax
	mov	$2, %rcx
	xor	%rdx, %rdx
	div	%rcx

	# Decrement the length
	decq	BDeque.len(%rdi)

	# Jump to the correct "move loop" (i.e. upper or lower)
	mov	%rsi, %rcx		# In either case, loop counter = key
	cmp	%rax, %rsi
	jge	4f

2:
	# Key is in lower half of backing array so we are moving all preceeding elements right
	cmp	$0, %rcx
	je	3f

	# Destination index (%r10)
	CALC_INDEX %rcx
	mov	%rdx, %r10

	# Source index (%rdx)
	dec	%rcx
	CALC_INDEX %rcx

	# Move source (%rdx) => destination (%r10)
	mov	(%r8, %rdx, 1<<3), %rax		# Source value
	mov	%rax, (%r8, %r10, 1<<3)		# Move source value to destination
	jmp	2b

3:
	# After moving all preceding elements, for the lower half we need to increment the index
	mov	$1, %rax
	CALC_INDEX %rax
	mov	%rdx, BDeque.idx(%rdi)
	jmp	5f

4:
	# Key is in upper half of backing array so we are moving all suceeding elements left
	cmp	BDeque.len(%rdi), %rcx
	je	5f

	# Destination index (%r10)
	CALC_INDEX %rcx
	mov	%rdx, %r10

	# Source index (%rdx)
	inc	%rcx
	CALC_INDEX %rcx

	# Move source (%rdx) => destination (%r10)
	mov	(%r8, %rdx, 1<<3), %rax		# Source value
	mov	%rax, (%r8, %r10, 1<<3)		# Move source value to destination
	jmp	4b

5:
	mov	%r9, %rax
	ret
# Out of bounds
1:
	xor	%rax, %rax
	ret

# @function	BDeque_log
# @description	Log the innards of a BDeque
# @param	%rdi	Pointer to the BDeque
# @return	void
.equ	THIS, -8
.equ	CTR, -16
.type	BDeque_log, @function
BDeque_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$s_delim, %rdi
	call	log

	movq	$0, CTR(%rbp)
	jmp	2f
1:
	call	BDeque_get
	movq	$null, %rdi
	cmp	$NULL, %rax
	cmovne	%rax, %rdi
	call	log

	incq	CTR(%rbp)
	mov	THIS(%rbp), %rdi
	mov	CTR(%rbp), %rsi
	cmp	BDeque.size(%rdi), %rsi
	je	2f

	mov	$m_delim, %rdi
	call	log
	
2:
	mov	THIS(%rbp), %rdi
	mov	CTR(%rbp), %rsi
	cmp	BDeque.size(%rdi), %rsi
	jl	1b

	mov	$e_delim, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret
