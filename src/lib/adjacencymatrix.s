# lib/adjacencymatrix.s - AdjacencyMatrix

.include	"common.inc"

.globl	AdjacencyMatrix_ctor, AdjacencyMatrix_dtor, AdjacencyMatrix_log, AdjacencyMatrix_add_edge
.globl	AdjacencyMatrix_remove_edge, AdjacencyMatrix_has_edge, AdjacencyMatrix_out_edges
.globl	AdjacencyMatrix_in_edges

# AdjacencyMatrix
	.struct	0
AdjacencyMatrix.data:
	.struct	AdjacencyMatrix.data + 1<<3
AdjacencyMatrix.size:
	.struct	AdjacencyMatrix.size + 1<<3
.equ	ADJACENCYMATRIX_SIZE, .

# Array - User for return value of out_edges and in_edges
	.struct	0
Array.len:
	.struct	Array.len + 1<<3
Array.val:
	.struct	Array.val + 1<<3

.section .rodata

newline:
	.byte	LF, NULL
slabel:
	.ascii	"Size     => \0"
vlabel:
	.ascii	"Vertices => \0"
vsdelim:
	.ascii	"[ \0"
vmdelim:
	.ascii	", \0"
vedelim:
	.ascii	" ]\0"
glabel:
	.ascii	"Graph    => {\n\0"
spacer:
	.byte	SPACE, SPACE, NULL
gend:
	.ascii	"}\0"

.section .text

# @function	AdjacencyMatrix_ctor
# @description	Constructor for an AdjacencyMatrix
# @param	%rdi	The number of vertices
# @return	%rax	Pointer to a new AdjacencyMatrix
.equ	SIZE, -8
.equ	PNTS, -16
.equ	DATA, -24
.type	AdjacencyMatrix_ctor, @function
AdjacencyMatrix_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, SIZE(%rbp)

	# Allocate the matrix (AdjacencyMatrix.data)
	imul	%rdi, %rdi
	mov	%rdi, PNTS(%rbp)			# Save the number of points for zeroing

	shl	$3, %rdi
	call	alloc
	mov	%rax, DATA(%rbp)

	# Zero-out ALL the fields
	mov	%rax, %rdi
	mov	PNTS(%rbp), %rcx
	xor	%rax, %rax
	rep	stosq

	# Allocate the AdjacencyMatrix wrapper
	mov	$ADJACENCYMATRIX_SIZE, %rdi
	call	alloc

	mov	DATA(%rbp), %rcx
	mov	%rcx, AdjacencyMatrix.data(%rax)
	mov	SIZE(%rbp), %rcx
	mov	%rcx, AdjacencyMatrix.size(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	AdjacencyMatrix_dtor
# @description	Destructor for an AdjacencyMatrix
# @param	%rdi	Pointer to an AdjacencyMatrix
# @return	void
.equ	THIS, -8
.type	AdjacencyMatrix_dtor, @function
AdjacencyMatrix_dtor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	mov	AdjacencyMatrix.data(%rdi), %rdi
	call	free

	mov	THIS(%rbp), %rdi
	call	free

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	AdjacencyMatrix_log
# @description	Logs the innards of an adjacency matrix
# @param	%rdi	Pointer to an AdjacencyMatrix
# @return	void
.equ	THIS, -8
.equ	TEMP, -16
.equ	X, -24
.equ	Y, -32
.type	AdjacencyMatrix_log, @function
AdjacencyMatrix_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$slabel, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	AdjacencyMatrix.size(%rdi), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$vlabel, %rdi
	call	log

	mov	$vsdelim, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	movq	$0, TEMP(%rbp)
	jmp	2f

1:
	mov	%rax, %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	incq	TEMP(%rbp)

	mov	THIS(%rbp), %rdi
	mov	TEMP(%rbp), %rax
	cmp	AdjacencyMatrix.size(%rdi), %rax
	je	2f

	mov	$vmdelim, %rdi
	call	log
	mov	THIS(%rbp), %rdi

2:
	mov	TEMP(%rbp), %rax
	cmp	AdjacencyMatrix.size(%rdi), %rax
	jl	1b

	mov	$vedelim, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$glabel, %rdi
	call	log

	movq	$0, X(%rbp)
	movq	$0, Y(%rbp)
	jmp	3f

1:
	mov	$spacer, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	Y(%rbp), %rcx
	imul	AdjacencyMatrix.size(%rdi), %rcx
	add	X(%rbp), %rcx

	mov	THIS(%rbp), %rdi
	mov	AdjacencyMatrix.data(%rdi), %rdi
	mov	(%rdi, %rcx, 1<<3), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	incq	X(%rbp)

2:
	mov	THIS(%rbp), %rdi
	mov	X(%rbp), %rcx
	cmpq	AdjacencyMatrix.size(%rdi), %rcx
	jl	1b

	mov	$newline, %rdi
	call	log

	movq	$0, X(%rbp)
	incq	Y(%rbp)

3:
	mov	THIS(%rbp), %rdi
	mov	Y(%rbp), %rcx
	cmpq	AdjacencyMatrix.size(%rdi), %rcx
	jl	2b

	mov	$gend, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	AdjacencyMatrix_add_edge
# @description	Adds an edge at the specified coordinates
# @param	%rdi	Pointer to an AdjacencyMatrix
# @param	%rsi	Source of the edge (row)
# @param	%rdx	Target of the edge (column)
# return	void
.type	AdjacencyMatrix_add_edge, @function
AdjacencyMatrix_add_edge:
	cmp	AdjacencyMatrix.size(%rdi), %rsi
	jge	1f

	cmp	AdjacencyMatrix.size(%rdi), %rdx
	jge	1f

	push	%rsi
	imul	AdjacencyMatrix.size(%rdi), %rsi
	add	%rdx, %rsi
	mov	AdjacencyMatrix.data(%rdi), %rax
	movq	$TRUE, (%rax, %rsi, 1<<3)
	pop	%rsi

1:
	mov	$NULL, %rax
	ret

# @function	AdjacencyMatrix_remove_edge
# @description	Removes an edge at the specified coordinates
# @param	%rdi	Pointer to an AdjacencyMatrix
# @param	%rsi	Source of the edge (row)
# @param	%rdx	Target of the edge (column)
# return	void
.type	AdjacencyMatrix_remove_edge, @function
AdjacencyMatrix_remove_edge:
	cmp	AdjacencyMatrix.size(%rdi), %rsi
	jge	1f

	cmp	AdjacencyMatrix.size(%rdi), %rdx
	jge	1f

	push	%rsi
	imul	AdjacencyMatrix.size(%rdi), %rsi
	add	%rdx, %rsi
	mov	AdjacencyMatrix.data(%rdi), %rax
	movq	$FALSE, (%rax, %rsi, 1<<3)
	pop	%rsi

1:
	mov	$NULL, %rax
	ret

# @function	AdjacencyMatrix_has_edge
# @description	Returns whether an edge exists at the specified coordinates
# @param	%rdi	Pointer to an AdjacencyMatrix
# @param	%rsi	Source of the edge (row)
# @param	%rdx	Target of the edge (column)
# return	%rax	TRUE if the edge exists, FALSE otherwise
.type	AdjacencyMatrix_has_edge, @function
AdjacencyMatrix_has_edge:
	xor	%rax, %rax
	cmp	AdjacencyMatrix.size(%rdi), %rsi
	jge	1f

	cmp	AdjacencyMatrix.size(%rdi), %rdx
	jge	1f

	push	%rsi
	imul	AdjacencyMatrix.size(%rdi), %rsi
	add	%rdx, %rsi
	mov	AdjacencyMatrix.data(%rdi), %rax
	mov	(%rax, %rsi, 1<<3), %rax
	pop	%rsi

1:
	ret

# @function	AdjacencyMatrix_out_edges
# @description	Gets all the columns which have edges for the specified row
# @param	%rdi	Pointer to the AdjacencyMatrix
# @param	%rsi	The row to search through
# @return	%rax	Pointer to an Array of vertices
.equ	THIS, -8
.equ	ROW, -16
.equ	LEN, -24
.type	AdjacencyMatrix_out_edges, @function
AdjacencyMatrix_out_edges:
	cmp	AdjacencyMatrix.size(%rdi), %rsi
	jge	3f

	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, ROW(%rbp)
	movq	$0, LEN(%rbp)

	xor	%rcx, %rcx
	mov	%rsi, %rax
	imul	AdjacencyMatrix.size(%rdi), %rax	# Start index
	mov	AdjacencyMatrix.data(%rdi), %rdx
	lea	(%rdx, %rax, 1<<3), %rax
	jmp	3f

1:
	mov	(%rax, %rcx, 1<<3), %r8
	test	%r8, %r8
	jz	2f

	push	%rcx
	incq	LEN(%rbp)

2:
	inc	%rcx

3:
	cmp	AdjacencyMatrix.size(%rdi), %rcx
	jl	1b

	mov	LEN(%rbp), %rdi
	inc	%rdi
	shl	$3, %rdi
	call	alloc

	mov	LEN(%rbp), %rcx
	mov	%rcx, Array.len(%rax)
	jmp	2f

1:
	dec	%rcx
	pop	%rdx
	mov	%rdx, Array.val(%rax, %rcx, 1<<3)

2:
	test	%rcx, %rcx
	jnz	1b

	mov	THIS(%rbp), %rdi

3:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	AdjacencyMatrix_in_edges
# @description	Gets all the rows which have edges for the specified column
# @param	%rdi	Pointer to the AdjacencyMatrix
# @param	%rsi	The column to search through
# @return	%rax	Pointer to an Array of vertices
.equ	THIS, -8
.equ	COL, -16
.equ	LEN, -24
.type	AdjacencyMatrix_in_edges, @function
AdjacencyMatrix_in_edges:
	cmp	AdjacencyMatrix.size(%rdi), %rsi
	jge	3f

	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, COL(%rbp)
	movq	$0, LEN(%rbp)

	xor	%rcx, %rcx
	mov	%rsi, %rax
	mov	AdjacencyMatrix.data(%rdi), %rdx
	jmp	3f

1:
	mov	(%rdx, %rax, 1<<3), %r8
	test	%r8, %r8
	jz	2f

	push	%rcx
	incq	LEN(%rbp)

2:
	add	AdjacencyMatrix.size(%rdi), %rax
	inc	%rcx

3:
	cmp	AdjacencyMatrix.size(%rdi), %rcx
	jl	1b

	mov	LEN(%rbp), %rdi
	inc	%rdi
	shl	$3, %rdi
	call	alloc

	mov	LEN(%rbp), %rcx
	mov	%rcx, Array.len(%rax)
	jmp	2f

1:
	dec	%rcx
	pop	%rdx
	mov	%rdx, Array.val(%rax, %rcx, 1<<3)

2:
	test	%rcx, %rcx
	jnz	1b

	mov	THIS(%rbp), %rdi

3:
	mov	%rbp, %rsp
	pop	%rbp
	ret
