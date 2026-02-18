# lib/arraystack.s - ArrayStack

.globl	ArrayStack_ctor, ArrayStack_length, ArrayStack_get, ArrayStack_set, ArrayStack_add, 
.globl	ArrayStack_remove, ArrayStack_log, ArrayStack_dtor, ArrayStack_slog

# ArrayStack struct
	.struct	0
ArrayStack.size:
	.struct	ArrayStack.size + 1<<2
ArrayStack.length:
	.struct	ArrayStack.length + 1<<2
ArrayStack.data:
	.struct	ArrayStack.data + 1<<3
	.equ	ARRAYSTACK_SIZE, .

.equ	ARRAYSTACK_START_SIZE, 1

.section .rodata


start_delim:
	.ascii	"[ \0"

mid_delim:
	.ascii	", \0"

end_delim:
	.ascii	" ]\n\n\0"

newline:
	.ascii	"\n\0"

## Labels
array:
	.ascii	"Raw    => \0"

length:
	.ascii	"Length => \0"

size:
	.ascii	"Size   => \0"

slog_start:
	.ascii	"ArrayStack[ \0"
slog_mid:
	.ascii	", \0"
slog_end:
	.ascii	" ]\0"

.section .text

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
	imul	$8, %rdi
	call	alloc
	# TODO: Error handling

	mov	%rax, ArrayStack.data(%rbx)
	movl	$ARRAYSTACK_START_SIZE, ArrayStack.size(%rbx)
	movl	$0, ArrayStack.length(%rbx)
	mov	%rbx, %rax

	pop	%rbx
	ret

# @function	ArrayStack_dtor
# @description	Destructor for the ArrayStack
# @param	%rdi	Pointer to the ArrayStack
# @return	void
.type	ArrayStack_dtor, @function
ArrayStack_dtor:
	push	%rdi
	mov	ArrayStack.data(%rdi), %rdi
	call	free

	pop	%rdi
	call	free
	ret

# @function	ArrayStack_length
# @description	Returns the length attribute of the ArrayStack so callers do not need to know 
#		internals
# @param	%rdi	Pointer to the ArrayStack
# @return	%rax	The length of the ArrayStack
.type	ArrayStack_length, @function
ArrayStack_length:
	mov	ArrayStack.length(%rdi), %eax
	ret

# @function	ArrayStack_get
# @description	Get the element at a position
# @param	%rdi	Address of the arraystack
# @param	%rsi	The index of the element to get
# @return	%rax	The address of the element or NULL
.type	ArrayStack_get, @function
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
# @param	%rax	The address of the previous element
.equ	THIS, -8
.equ	PREV, -16
.type	ArrayStack_set, @function
ArrayStack_set:
	push	%rbp
	mov	%rsp, %rbp
	
	# Validates the passed index
	mov	ArrayStack.length(%rdi), %ecx	# Length of array in %rcx
	cmp	%rsi, %rcx
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	# Stack variables
	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	mov	ArrayStack.data(%rdi), %rax	# %rax now holds the address of "data"

	# Get the previous element first since that will be the return value
	mov	(%rax, %rsi, 1<<3), %r8
	mov	%r8, PREV(%rbp)

	# Move the new element into place
	mov	%rdx, (%rax, %rsi, 1<<3)

	# Restore %rdi pointer
	mov	THIS(%rbp), %rdi

	# Put the previous element as the return value
	mov	PREV(%rbp), %rax

	mov	%rbp, %rsp
	pop	%rbp
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
.type	ArrayStack_add, @function
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
	call	resize
	jmp	1b


# @function	ArrayStack_remove
# @description	Remove an element at a position. The indexes of the existing data will shift to
#		accomodate the removal
# @param	%rdi	Address of the arraystack
# @param	%rsi	The index of the element to remove
# @return	%rax	The address of the element
.type	ArrayStack_remove, @function
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
	imul	$3, %eax			# We resize down when size is 3x the length
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
	call	resize
	jmp	1b

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

	# Log length
	mov	$length, %rdi
	call	log

	mov	ArrayStack.length(%rbx), %edi
	call	itoa

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	# Log size
	mov	$size, %rdi
	call	log

	mov	ArrayStack.size(%rbx), %edi
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

	mov	ArrayStack.size(%rbx), %r12d
	mov	ArrayStack.data(%rbx), %r13

	xor	%r14, %r14			# Zero out addressing index
# Loop all the items
3:
	cmp	%r14d, ArrayStack.length(%rbx)
	jle	4f

	mov	(%r13, %r14, 8), %rdi
	call	log

4:
	inc	%r14
	cmp	%r12, %r14
	jge	5f				# Skip middle delimiter for last iteration

	mov	$mid_delim, %rdi
	call	log

	jmp	3b

5:
	mov	$end_delim, %rdi
	call	log

	pop	%r14
	pop	%r13
	pop	%r12
	pop	%rbx
	ret

# @function	ArrayStack_slog
# @description	Short form log of an ArrayStack. This logs only numbers for the entries!!
# @param	%rdi	Pointer to the ArrayStack
# @return	void
.equ	THIS, -8
.equ	TEMP, -16
.type	ArrayStack_slog, @function
ArrayStack_slog:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$slog_start, %rdi
	call	log

	movq	$0, TEMP(%rbp)
	jmp	2f

1:
	call	ArrayStack_get
	mov	%rax, %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	incq	TEMP(%rbp)

	mov	THIS(%rbp), %rdi
	mov	TEMP(%rbp), %rsi
	cmp	ArrayStack.length(%rdi), %esi
	je	2f

	mov	$slog_mid, %rdi
	call	log

2:
	mov	THIS(%rbp), %rdi
	mov	TEMP(%rbp), %rsi
	cmp	ArrayStack.length(%rdi), %esi
	jl	1b

	mov	$slog_end, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	resize
# @description	Resize the arraystack, necessary when adding an element will cause it to overflow
#		its bounds or removing an element will leave too much wasted space
# @param	%rdi	Address of the ArrayStack
# @return	rax	Void
resize:
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
	mov	$2, %r13d
	imul	%r12d, %r13d

	# Allocate a new array, pointer to new memory location is in %rax
	mov	%r13, %rdi
	imul	$8, %rdi
	call	alloc
	# TODO: Error handling + Need to call FREE!!

	# Move current data to new allocation (movsq)
	mov	%r12, %rcx			# Count of moves
	mov	ArrayStack.data(%rbx), %rsi	# Source pointer
	mov	%rax, %rdi			# Destination pointer
	rep	movsq

	mov	ArrayStack.data(%rbx), %rdi	# Preserve old pointer to data

	mov	%rax, ArrayStack.data(%rbx)	# Update pointer to data
	mov	%r13d, ArrayStack.size(%rbx)

	# Free old pointer in %rdi
	call	free
1:
	pop	%r13
	pop	%r12
	pop	%rbx
	ret
