# lib/linearhashtable.s - LinearHashTable

.include	"common.inc"

.globl	LinearHashTable_ctor, LinearHashTable_find, LinearHashTable_add, LinearHashTable_remove
.globl	LinearHashTable_log

# LinearHashTable
	.struct	0
LinearHashTable.data:
	.struct	LinearHashTable.data + 1<<3
LinearHashTable.len:
	.struct	LinearHashTable.len + 1<<3
LinearHashTable.siz:
	.struct	LinearHashTable.siz + 1<<3
LinearHashTable.use:
	.struct	LinearHashTable.use + 1<<2
LinearHashTable.dim:
	.struct	LinearHashTable.dim + 1<<2
	.equ	LINEARHASHTABLE_SIZE, .

.equ	START_DIM, 1
.equ	INT_SIZE, 1<<5	# 32 bits

.equ	NIL, 0
.equ	DEL, -1

.section .rodata

dim_label:
	.ascii	"Dimension => \0"
len_label:
	.ascii	"Length    => \0"
use_label:
	.ascii	"Used      => \0"
siz_label:
	.ascii	"Size      => \0"
raw_label:
	.ascii	"Raw       => \0"
spacer:
	.ascii	"  \0"
label:
	.ascii	"=> \0"
sdelim:
	.ascii	"[ \0"
mdelim:
	.ascii	", \0"
edelim:
	.ascii	" ]\0"
newline:
	.byte	LF, NULL
nil:
	.ascii	"NIL\0"
del:
	.ascii	"DEL\0"

.section .bss

tab0:
	.zero	1<<10	# 4 bytes * 256 rows
tab1:
	.zero	1<<10	# 4 bytes * 256 rows
tab2:
	.zero	1<<10	# 4 bytes * 256 rows
tab3:
	.zero	1<<10	# 4 bytes * 256 rows

.section .text

# @function	LinearHashTable_ctor
# @description	Constructor for a LinearHashTable
# @return	%rax	Pointer to the new LinearHashTable
.equ	DATA, -8
.equ	SIZE, -16
.type	LinearHashTable_ctor, @function
LinearHashTable_ctor:
	push	%rbp
	mov	%rsp, %rbp

	# Space for local variables
	sub	$16, %rsp

	# Calculate the table size
	movb	$START_DIM, %cl
	mov	$1, %rdi
	shl	%cl, %rdi
	mov	%rdi, SIZE(%rbp)

	# Allocation for the table
	imul	$8, %rdi
	call	alloc
	mov	%rax, DATA(%rbp)

	# Ensure ALL entries in the table are set to NIL
	mov	SIZE(%rbp), %rcx
1:
	dec	%rcx
	movq	$NIL, (%rax, %rcx, 1<<3)
	cmp	$0, %rcx
	jg	1b

	# Allocation for the struct
	mov	$LINEARHASHTABLE_SIZE, %rdi
	call	alloc

	# Assign attributes
	mov	DATA(%rbp), %rcx
	mov	%rcx, LinearHashTable.data(%rax)
	mov	SIZE(%rbp), %rcx
	mov	%rcx, LinearHashTable.siz(%rax)
	movq	$0, LinearHashTable.len(%rax)
	movl	$0, LinearHashTable.use(%rax)
	movl	$START_DIM, LinearHashTable.dim(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	LinearHashTable_find
# @description	Finds an element in the LinearHashTable
# @param	%rdi	Pointer to the LinearHashTable instance
# @param	%rsi	The element to find
# @return	%rax	The found element on success, NULL on failure
.equ	THIS, -8
.equ	CTR, -16
.type	LinearHashTable_find, @function
LinearHashTable_find:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	call	hash
	mov	%rax, CTR(%rbp)

	mov	LinearHashTable.data(%rdi), %r8
1:
	# Find loop
	mov	CTR(%rbp), %rcx
	mov	(%r8, %rcx, 1<<3), %rax
	cmp	$NIL, %rax
	je	3f

	cmp	$DEL, %rax
	je	2f

	mov	%rax, %rdi
	call	strcmp
	cmp	$0, %rax
	jne	2f
	
	# Value was found so return it
	mov	%rsi, %rax
	mov	THIS(%rbp), %rdi
	jmp	4f
	
2:
	# Increment the search index in modulo
	mov	THIS(%rbp), %rdi
	mov	CTR(%rbp), %rax
	inc	%rax
	xor	%rdx, %rdx
	divq	LinearHashTable.siz(%rdi)
	mov	%rdx, CTR(%rbp)
	jmp	1b

3:
	# If we exit this way the element was not found
	xor	%rax, %rax
4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	LinearHashTable_add
# @description	Adds an element to the LinearHashTable
# @param	%rdi	Pointer to the LinearHashTable instance
# @param	%rsi	The element to add
# @return	%rax	The added element
.equ	ELEM, -8
.type	LinearHashTable_add, @function
LinearHashTable_add:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$8, %rsp
	mov	%rsi, ELEM(%rbp)

	# First try to find the element and if it exists already return early
	call	LinearHashTable_find
	cmp	$NULL, %rax
	jne	6f

	mov	LinearHashTable.use(%rdi), %eax
	inc	%rax
	imul	$2, %rax
	cmp	LinearHashTable.siz(%rdi), %rax
	jle	2f

	call	resize

2:
	mov	ELEM(%rbp), %rsi
	call	hash
	mov	%rax, %rcx
	mov	LinearHashTable.data(%rdi), %r8
3:
	mov	(%r8, %rcx, 1<<3), %rax
	cmp	$NIL, %rax
	je	4f
	
	cmp	$DEL, %rax
	je	4f

	# Increment the search index in modulo
	inc	%rcx
	mov	%rcx, %rax
	xor	%rdx, %rdx
	divq	LinearHashTable.siz(%rdi)
	mov	%rdx, %rcx
	jmp	3b

4:
	# We found our insertion location (in %rcx)

	# Increment our usage counter if applicable
	cmp	$NIL, %rax
	jne	5f

	incl	LinearHashTable.use(%rdi)
5:
	incq	LinearHashTable.len(%rdi)
	mov	%rsi, (%r8, %rcx, 1<<3)
	mov	%rsi, %rax

6:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	LinearHashTable_remove
# @description	Remove an element from the table
# @param	%rdi	Pointer to the LinearHashTable
# @param	%rsi	The element to remove
# @return	%rax	The removed element (or NULL on failure)
.equ	THIS, -8
.equ	ELEM, -16
.equ	DATA, -24
.equ	CTR, -32
.type	LinearHashTable_remove, @function
LinearHashTable_remove:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, ELEM(%rbp)

	call	hash
	mov	%rax, CTR(%rbp)
	mov	LinearHashTable.data(%rdi), %rdx
	mov	%rdx, DATA(%rbp)

1:
	mov	CTR(%rbp), %rcx
	mov	DATA(%rbp), %rdx
	mov	(%rdx, %rcx, 1<<3), %rax
	cmp	$NIL, %rax
	je	4f

	cmp	$DEL, %rax
	je	2f

	mov	%rax, %rdi
	call	strcmp
	cmp	$0, %rax
	jne	2f

	# We found the element in question and need to remove it
	mov	CTR(%rbp), %rcx
	mov	DATA(%rbp), %rdx
	mov	THIS(%rbp), %rdi
	movq	$DEL, (%rdx, %rcx, 1<<3)
	decq	LinearHashTable.len(%rdi)

	# Check if we need a resize
	mov	LinearHashTable.len(%rdi), %rax
	imul	$8, %rax
	cmp	LinearHashTable.siz(%rdi), %rax
	jge	3f

	call	resize
	jmp	3f

2:
	# An element was found at the expected location but it was NOT our element so we increase
	# the search index ala modulo
	mov	CTR(%rbp), %rax
	mov	THIS(%rbp), %rdi
	inc	%rax
	xor	%rdx, %rdx
	divq	LinearHashTable.siz(%rdi)
	mov	%rdx, CTR(%rbp)
	jmp	1b

3:
	mov	ELEM(%rbp), %rax

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	LinearHashTable_log
# @description	Logs the innards of a LinearHashTable
# @param	%rdi	Pointer to the LinearHashTable
# @return	void
.equ	THIS, -8
.equ	ICTR, -16
.type	LinearHashTable_log, @function
LinearHashTable_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$len_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	LinearHashTable.len(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$siz_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	LinearHashTable.siz(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$use_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	LinearHashTable.use(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$dim_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	LinearHashTable.dim(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$raw_label, %rdi
	call	log

	mov	$sdelim, %rdi
	call	log

	movq	$0, ICTR(%rbp)
	jmp	6f

1:
	mov	LinearHashTable.data(%rdi), %rax
	mov	ICTR(%rbp), %rcx
	mov	(%rax, %rcx, 1<<3), %rdi

	cmp	$NIL, %rdi
	jne	3f

	mov	$nil, %rdi
	call	log
	jmp	5f

3:
	cmp	$DEL, %rdi
	jne	4f

	mov	$del, %rdi
	call	log
	jmp	5f

4:
	call	log
5:
	incq	ICTR(%rbp)
	mov	THIS(%rbp), %rdi
	mov	LinearHashTable.siz(%rdi), %rcx
	cmp	%rcx, ICTR(%rbp)
	je	6f

	mov	$mdelim, %rdi
	call	log

6:
	mov	THIS(%rbp), %rdi
	mov	LinearHashTable.siz(%rdi), %rcx
	cmp	%rcx, ICTR(%rbp)
	jl	1b

	mov	$edelim, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret
# @function	resize
# @description	File private function that performs a resize of the backing table, aiming for a
#		dimension value that produces at least 3x the length
# @param	%rdi	Pointer to the LinearHashTable
# @return	void
.equ	THIS, -8
.equ	DIM, -16
.equ	SIZ, -24
resize:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)

	# Calculate new dimension
	xor	%rcx, %rcx
	mov	LinearHashTable.len(%rdi), %rax
	imul	$3, %rax

1:
	inc	%rcx
	mov	$1, %rdi
	shl	%cl, %rdi
	cmp	%rax, %rdi
	jl	1b

	mov	%rcx, DIM(%rbp)
	mov	%rdi, SIZ(%rbp)

	# Allocate new table
	imul	$1<<3, %rdi
	call	alloc
	mov	%rax, %r12

	# Ensure ALL entries in the table are set to NIL
	mov	SIZ(%rbp), %rcx
1:
	dec	%rcx
	movq	$NIL, (%rax, %rcx, 1<<3)
	cmp	$0, %rcx
	jg	1b

	# Capture old values for data and siz
	mov	THIS(%rbp), %rdi
	mov	LinearHashTable.data(%rdi), %r11
	mov	LinearHashTable.siz(%rdi), %rcx

	# Store new values for dim, siz + use
	mov	DIM(%rbp), %rsi
	movl	%esi, LinearHashTable.dim(%rdi)
	mov	SIZ(%rbp), %rsi
	mov	%rsi, LinearHashTable.siz(%rdi)
	mov	LinearHashTable.len(%rdi), %rsi
	movl	%esi, LinearHashTable.use(%rdi)

2:
	# Migrate the data from old to new
	dec	%rcx
	cmp	$0, %rcx
	jl	5f

	mov	(%r11, %rcx, 1<<3), %rsi

	cmp	$NIL, %rsi
	je	2b

	cmp	$DEL, %rsi
	je	2b

	push	%rcx
	call	hash
	pop	%rcx

3:
	# Check for a free spot in the new table
	cmpq	$NIL, (%r12, %rax, 1<<3)
	je	4f

	# Spot is not free in the new table so increment i in modulo
	inc	%rax
	xor	%rdx, %rdx
	divq	LinearHashTable.siz(%rdi)
	mov	%rdx, %rax
	jmp	3b

4:
	mov	%rsi, (%r12, %rax, 1<<3)
	jmp	2b

5:

	# Assign new table
	mov	%r12, LinearHashTable.data(%rdi)

	# Free old table
	mov	%r11, %rdi
	call	free

	mov	THIS(%rbp), %rdi

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	hash
# @description	File private function that hashes a value to obtain the index into the table
# @param	%rdi	Pointer to the LinearHashTable
# @param	%rsi	The value
# @return	%rax	The index in the backing table for the specified value
.equ	THIS, -8
hash:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	# Lazy generate tabulations
	cmpq	$NULL, tab0
	jne	1f

	call	seed

1:
	mov	%rsi, %rdi
	call	hash_code

	mov	%rax, %rdx	# We need the value in a register supporting 8-bit extractions

	# Byte 0
	movzbl	%dl, %ecx
	mov	tab0(, %ecx, 4), %eax

	# Byte 1
	movzbl	%dh, %ecx
	xor	tab1(, %ecx, 4), %eax

	shr	$1<<4, %edx	# Shift right 16 bits to get the keys for tabs 3 + 4 in %dl + %dh

	# Byte 2
	movzbl	%dl, %ecx
	xor	tab2(, %ecx, 4), %eax

	# Byte 3
	movzbl	%dh, %ecx
	xor	tab3(, %ecx, 4), %eax

	mov	THIS(%rbp), %rdi
	mov	$INT_SIZE, %rcx
	sub	LinearHashTable.dim(%rdi), %rcx
	shr	%cl, %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	seed
# @description	File private function to load the tabulation table
# @return	void
seed:
	xor	%rcx, %rcx

1:
	rdrand	%rax
	jnc	1b

	mov	%rax, tab0(, %rcx, 1<<3)
	inc	%rcx

	cmp	$64, %rcx
	jl	1b

	ret
