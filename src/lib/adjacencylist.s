# lib/adjacencylist.s - AdjacencyList

.include	"common.inc"

.globl	AdjacencyList_ctor, AdjacencyList_add_edge, AdjacencyList_remove_edge
.globl	AdjacencyList_has_edge, AdjacencyList_out_edges, AdjacencyList_in_edges
.globl	AdjacencyList_log, AdjacencyList_bfs, AdjacencyList_rdfs, AdjacencyList_dfs

# AdjacencyList
	.struct	0
AdjacencyList.data:
	.struct	AdjacencyList.data + 1<<3
AdjacencyList.size:
	.struct	AdjacencyList.size + 1<<3
.equ	ADJACENCYLIST_SIZE, .

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
rlabel:
	.ascii	"Raw      => {\n\0"
rmdelim:
	.ascii	" => \0"
spacer:
	.byte	SPACE, SPACE, NULL
rend:
	.ascii	"}\0"

.section .text

# @function	AdjacencyList_ctor
# @description	Constructor for an AdjacencyList
# @param	%rdi	The size of the AdjacencyList (ie the number of the vertices)
# @return	%rax	Pointer to a new AdjacencyList
.equ	SIZE, -8
.equ	DATA, -16
.equ	TEMP, -24
.type	AdjacencyList_ctor, @function
AdjacencyList_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, SIZE(%rbp)

	shl	$3, %rdi
	call	alloc
	mov	%rax, DATA(%rbp)

	# Create an ArrayStack for each vertex
	movq	$0, TEMP(%rbp)
	jmp	2f

1:
	call	ArrayStack_ctor
	mov	TEMP(%rbp), %rcx
	mov	DATA(%rbp), %rdx
	mov	%rax, (%rdx, %rcx, 1<<3)
	incq	TEMP(%rbp)

2:
	mov	TEMP(%rbp), %rax
	cmp	SIZE(%rbp), %rax
	jl	1b

	mov	$ADJACENCYLIST_SIZE, %rdi
	call	alloc

	mov	DATA(%rbp), %rcx
	mov	%rcx, AdjacencyList.data(%rax)
	mov	SIZE(%rbp), %rcx
	mov	%rcx, AdjacencyList.size(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	AdjacencyList_add_edge
# @description	Adds an edge to an AdjacencyList
# @param	%rdi	Pointer to the AdjacencyList
# @param	%rsi	In edge
# @param	%rdx	Out edge
# @return	void
.equ	THIS, -8
.equ	OUT, -16
.equ	IN, -24
.type	AdjacencyList_add_edge, @function
AdjacencyList_add_edge:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, OUT(%rbp)
	mov	%rdx, IN(%rbp)

	xor	%rax, %rax
	cmp	AdjacencyList.size(%rdi), %rsi
	jge	1f

	cmp	AdjacencyList.size(%rdi), %rdx
	jge	1f

	mov	AdjacencyList.data(%rdi), %rdi
	mov	(%rdi, %rsi, 1<<3), %rdi
	call	ArrayStack_length
	mov	%rax, %rsi
	call	ArrayStack_add

	mov	THIS(%rbp), %rdi
	mov	OUT(%rbp), %rsi
	mov	IN(%rbp), %rdx
	mov	$TRUE, %rax

1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	AdjacencyList_remove_edge
# @description	Removes an edge from an AdjacencyList
# @param	%rdi	Pointer to the AdjacencyList
# @param	%rsi	in edge
# @param	%rdx	out edge
# @return	void
.equ	THIS, -8
.equ	OUT, -16
.equ	IN, -24
.equ	LEN, -32
.equ	RET, -40
.type	AdjacencyList_remove_edge, @function
AdjacencyList_remove_edge:
	push	%rbp
	mov	%rsp, %rbp

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, OUT(%rbp)
	mov	%rdx, IN(%rbp)
	movq	$FALSE, RET(%rbp)

	cmp	AdjacencyList.size(%rdi), %rsi
	jge	4f

	cmp	AdjacencyList.size(%rdi), %rdx
	jge	4f

	mov	AdjacencyList.data(%rdi), %rdi
	mov	(%rdi, %rsi, 1<<3), %rdi

	call	ArrayStack_length
	mov	%rax, LEN(%rbp)
	xor	%r8, %r8
	jmp	2f

1:
	mov	%r8, %rsi
	call	ArrayStack_get
	inc	%r8
	cmp	IN(%rbp), %rax
	jne	2f

	movq	$TRUE, RET(%rbp)
	call	ArrayStack_remove
	jmp	3f

2:
	cmp	LEN(%rbp), %r8
	jl	1b

3:
	mov	THIS(%rbp), %rdi
	mov	OUT(%rbp), %rsi
	mov	IN(%rbp), %rdx
	mov	$TRUE, %rax

4:
	mov	RET(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	AdjacencyList_has_edge
# @description	Returns whether an AdjacencyList has a particular edge
# @param	%rdi	Pointer to an AdjacencyList
# @param	%rsi	The in edge
# @param	%rdx	The out edge
# @return	%rax	TRUE if the edge exists, FALSE otherwise
.equ	THIS, -8
.equ	OUT, -16
.equ	IN, -24
.equ	LEN, -32
.type	AdjacencyList_has_edge, @function
AdjacencyList_has_edge:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, OUT(%rbp)
	mov	%rdx, IN(%rbp)

	xor	%rax, %rax
	cmp	AdjacencyList.size(%rdi), %rsi
	jge	5f

	cmp	AdjacencyList.size(%rdi), %rdx
	jge	5f

	mov	AdjacencyList.data(%rdi), %rdi
	mov	(%rdi, %rsi, 1<<3), %rdi

	call	ArrayStack_length
	mov	%rax, LEN(%rbp)
	xor	%r8, %r8
	jmp	3f

1:
	mov	%r8, %rsi
	call	ArrayStack_get
	cmp	IN(%rbp), %rax
	jne	2f

	mov	$TRUE, %rax
	jmp	4f

2:
	inc	%r8

3:
	cmp	LEN(%rbp), %r8
	jl	1b

	xor	%rax, %rax

4:
	mov	THIS(%rbp), %rdi
	mov	OUT(%rbp), %rsi
	mov	IN(%rbp), %rdx

5:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	AdjacencyList_out_edges
# @description	Returns a list of out edges for the given in edge
# @param	%rdi	Pointer to the AdjacencyList
# @param	%rsi	The vertex of an in edge
# @return	%rax	An ArrayStack of out edges
.type	AdjacencyList_out_edges, @function
AdjacencyList_out_edges:
	xor	%rax, %rax
	cmp	AdjacencyList.size(%rdi), %rsi
	jge	1f

	mov	AdjacencyList.data(%rdi), %rax
	mov	(%rax, %rsi, 1<<3), %rax

1:
	ret

# @function	AdjacencyList_in_edges
# @description	Returns a list of in edges for the given out edge
# @param	%rdi	Pointer to the AdjacencyList
# @param	%rsi	The vertex of an out edge
# @return	%rax	An ArrayStack of in edges
.equ	THIS, -8
.equ	OUT, -16
.equ	ARR, -24
.equ	IN, -32
.type	AdjacencyList_in_edges, @function
AdjacencyList_in_edges:
	push	%rbp
	mov	%rsp, %rbp

	xor	%rax, %rax
	cmp	AdjacencyList.size(%rdi), %rsi
	jge	4f

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, OUT(%rbp)

	call	ArrayStack_ctor
	mov	%rax, ARR(%rbp)

	mov	THIS(%rbp), %rdi
	movq	$0, IN(%rbp)
	mov	OUT(%rbp), %rdx
	jmp	3f

1:
	call	AdjacencyList_has_edge
	test	%rax, %rax
	jz	2f

	mov	ARR(%rbp), %rdi
	call	ArrayStack_length
	mov	%rax, %rsi
	mov	IN(%rbp), %rdx
	call	ArrayStack_add

2:
	mov	THIS(%rbp), %rdi
	mov	OUT(%rbp), %rdx
	incq	IN(%rbp)

3:
	mov	IN(%rbp), %rsi
	cmp	AdjacencyList.size(%rdi), %rsi
	jl	1b

	mov	ARR(%rbp), %rax

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	AdjacencyList_log
# @description	Logs the innards of an AdjacencyList
# @param	%rdi	Pointer to an AdjacencyList
# @return	void
.equ	THIS, -8
.equ	TEMP, -16
.type	AdjacencyList_log, @function
AdjacencyList_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$slabel, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	AdjacencyList.size(%rdi), %rdi
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
	cmp	AdjacencyList.size(%rdi), %rax
	je	2f

	mov	$vmdelim, %rdi
	call	log
	mov	THIS(%rbp), %rdi

2:
	mov	TEMP(%rbp), %rax
	cmp	AdjacencyList.size(%rdi), %rax
	jl	1b

	mov	$vedelim, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$rlabel, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	movq	$0, TEMP(%rbp)
	jmp	2f

1:
	mov	$spacer, %rdi
	call	log

	mov	TEMP(%rbp), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$rmdelim, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	AdjacencyList.data(%rdi), %rdi
	mov	TEMP(%rbp), %rcx
	mov	(%rdi, %rcx, 1<<3), %rdi
	call	ArrayStack_slog

	mov	$newline, %rdi
	call	log

	incq	TEMP(%rbp)
	mov	THIS(%rbp), %rdi

2:
	mov	TEMP(%rbp), %rax
	cmp	AdjacencyList.size(%rdi), %rax
	jl	1b

	mov	$rend, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	AdjacencyList_bfs
# @description	Performs a breadth-first search of an AdjacencyList starting at the specified
#		vertex
# @param	%rdi	Pointer to an AdjacencyList
# @param	%rsi	The start vertex
# @return	%rax	An ArrayStack tracing the path followed
.equ	THIS, -8
.equ	STRT, -16
.equ	SEEN, -24
.equ	Q, -32
.equ	EDGS, -40
.equ	LIM, -48
.equ	IDX, -56
.equ	VAL, -64
.equ	OUT, -72
.type	AdjacencyList_bfs, @function
AdjacencyList_bfs:
	push	%rbp
	mov	%rsp, %rbp

	xor	%rax, %rax
	cmp	AdjacencyList.size(%rdi), %rsi
	jge	5f

	sub	$72, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, STRT(%rbp)

	mov	AdjacencyList.size(%rdi), %rdi
	call	alloc
	mov	%rax, SEEN(%rbp)

	# Zero out the array using STOSB
	mov	THIS(%rbp), %rdi
	mov	AdjacencyList.size(%rdi), %rcx	# Number of repetitions for REP
	mov	%rax, %rdi			# STOSB destination
	mov	$FALSE, %rax			# Value to insert
	rep	stosb

	call	SLList_ctor
	mov	%rax, Q(%rbp)

	mov	%rax, %rdi
	mov	STRT(%rbp), %rsi
	call	SLList_add

	mov	SEEN(%rbp), %rcx
	movb	$TRUE, (%rcx, %rax)

	# Create output ArrayStack
	call	ArrayStack_ctor
	mov	%rax, OUT(%rbp)

	mov	Q(%rbp), %rdi
	jmp	4f

1:
	# Pop next item off of the queue
	call	SLList_remove
	mov	%rax, VAL(%rbp)

	mov	OUT(%rbp), %rdi
	call	ArrayStack_length
	mov	%rax, %rsi
	mov	VAL(%rbp), %rdx
	call	ArrayStack_add


	# Loop the out edges and add the ones we haven't seen yet to the queue
	mov	THIS(%rbp), %rdi
	mov	%rax, %rsi
	call	AdjacencyList_out_edges
	mov	%rax, EDGS(%rbp)
	mov	4(%rax), %ecx			# ArrayStack.len = Number of vertices to loop
	mov	%rcx, LIM(%rbp)
	movq	$-1, IDX(%rbp)			# Setting this to -1 saves us an extra label/jump
	jmp	3f

2:
	# Get the current vertex
	mov	EDGS(%rbp), %rdi
	call	ArrayStack_get

	# Check if the vertex has already been seen
	mov	SEEN(%rbp), %rcx
	cmpb	$0, (%rcx, %rax)
	jne	3f

	# Vertex has not been seen yet so add it to Q and SEEN
	mov	Q(%rbp), %rdi
	mov	%rax, %rsi
	call	SLList_add

	mov	SEEN(%rbp), %rcx
	movb	$TRUE, (%rcx, %rax)

3:
	incq	IDX(%rbp)
	mov	IDX(%rbp), %rsi
	cmp	LIM(%rbp), %rsi
	jl	2b

4:
	mov	Q(%rbp), %rdi
	cmpq	$0, (%rdi)			# Iterate until the length of Q is zero
	jg	1b

	mov	THIS(%rbp), %rdi
	mov	OUT(%rbp), %rax

5:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# Colors for depth-first search
.equ	WHITE, 0
.equ	GRAY, 1
.equ	BLACK, 2

# @function	AdjacencyList_rdfs
# @description	Performs a RECURSIVE depth-first search starting at the specified index
# @param	%rdi	Pointer to an AdjacencyList
# @param	%rsi	Start vertex
# @return	%rax	An ArrayStack with the path followed
.equ	THIS, -8
.equ	STRT, -16
.equ	CLRS, -24
.equ	OUTP, -32
.type	AdjacencyList_rdfs, @function
AdjacencyList_rdfs:
	push	%rbp
	mov	%rsp, %rbp

	cmp	AdjacencyList.size(%rdi), %rsi
	jge	5f

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, STRT(%rbp)

	mov	AdjacencyList.size(%rdi), %rdi
	call	alloc
	mov	%rax, CLRS(%rbp)

	# Set the entire colors array to white to indicate no vertexes have been visited yet
	mov	THIS(%rbp), %rdi
	mov	AdjacencyList.size(%rdi), %rcx
	mov	%rax, %rdi
	mov	$WHITE, %rax
	rep	stosb

	# Initialize the output array
	call	ArrayStack_ctor
	mov	%rax, OUTP(%rbp)

	# Call the private recursive helper
	mov	THIS(%rbp), %rdi
	mov	STRT(%rbp), %rsi
	mov	CLRS(%rbp), %rdx
	mov	OUTP(%rbp), %rcx
	call	rdfs

5:
	mov	OUTP(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	AdjacencyList_dfs
# @description	Performs a NON-RECURSIVE depth-first search starting at the specified index
# @param	%rdi	Pointer to an AdjacencyList
# @param	%rsi	Start vertex
# @return	%rax	An ArrayStack with the path followed
.equ	THIS, -8
.equ	STRT, -16
.equ	CLRS, -24
.equ	SLLQ, -32
.equ	EDGS, -40
.equ	CNTR, -48
.equ	OUTP, -56
.type	AdjacencyList_dfs, @function
AdjacencyList_dfs:
	push	%rbp
	mov	%rsp, %rbp

	cmp	AdjacencyList.size(%rdi), %rsi
	jge	5f

	sub	$56, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, STRT(%rbp)

	mov	AdjacencyList.size(%rdi), %rdi
	call	alloc
	mov	%rax, CLRS(%rbp)

	# Set the entire colors array to white to indicate no vertexes have been visited yet
	mov	THIS(%rbp), %rdi
	mov	AdjacencyList.size(%rdi), %rcx
	mov	%rax, %rdi
	mov	$WHITE, %rax
	rep	stosb

	# Initialize the queue to track visits
	call	SLList_ctor
	mov	%rax, SLLQ(%rbp)

	# Initialize the output array
	call	ArrayStack_ctor
	mov	%rax, OUTP(%rbp)

	mov	SLLQ(%rbp), %rdi
	mov	STRT(%rbp), %rsi
	call	SLList_push
	jmp	4f

1:
	call	SLList_pop
	mov	%rax, %rdx

	mov	OUTP(%rbp), %rdi
	call	ArrayStack_length
	mov	%rax, %rsi
	call	ArrayStack_add

	mov	CLRS(%rbp), %rcx
	cmpb	$WHITE, (%rcx, %rax)
	jne	2f

	movb	$GRAY, (%rcx, %rax)

	mov	THIS(%rbp), %rdi
	mov	%rax, %rsi
	call	AdjacencyList_out_edges
	mov	%rax, EDGS(%rbp)
	movq	$0, CNTR(%rbp)
	jmp	3f

2:
	mov	CNTR(%rbp), %rsi
	call	ArrayStack_get

	mov	SLLQ(%rbp), %rdi
	mov	%rax, %rsi
	call	SLList_push
	incq	CNTR(%rbp)

3:
	mov	EDGS(%rbp), %rdi
	call	ArrayStack_length
	cmp	%rax, CNTR(%rbp)
	jl	2b

4:
	mov	SLLQ(%rbp), %rdi
	cmpq	$0, (%rdi)			# Checks if SLList.size > 0
	jg	1b

	mov	OUTP(%rbp), %rax

5:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	rdfs
# @description	File private helper to implement a recursive depth-first search
# @param	%rdi	Pointer to an AdajacencyList
# @param	%rsi	The start vertex
# @param	%rdx	A colors array
# @param	%rcx	An output array to add all the vertexes to
# @return	void
.equ	THIS, -8
.equ	STRT, -16
.equ	CLRS, -24
.equ	OUTP, -32
.equ	EDGS, -40
.equ	CNTR, -48
rdfs:
	push	%rbp
	mov	%rsp, %rbp

	sub	$48, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, STRT(%rbp)
	mov	%rdx, CLRS(%rbp)
	mov	%rcx, OUTP(%rbp)

	# Color the current vertex gray to indicate that we are visiting it now ...
	movb	$GRAY, (%rdx, %rsi)

	mov	OUTP(%rbp), %rdi
	call	ArrayStack_length
	mov	%rsi, %rdx
	mov	%rax, %rsi
	call	ArrayStack_add

	mov	THIS(%rbp), %rdi
	mov	STRT(%rbp), %rsi
	call	AdjacencyList_out_edges
	mov	%rax, EDGS(%rbp)
	movq	$0, CNTR(%rbp)
	jmp	2f

1:
	mov	CNTR(%rbp), %rsi
	call	ArrayStack_get

	# Only recurse if the edge IS white
	mov	CLRS(%rbp), %rdx
	cmpb	$WHITE, (%rdx, %rax)
	jne	2f

	# TODO IS THIS NECESSARY?? It is set to gray in the function call ...
	movb	$GRAY, (%rdx, %rax)
	mov	THIS(%rbp), %rdi
	mov	%rax, %rsi
	mov	OUTP(%rbp), %rcx
	call	rdfs

	incq	CNTR(%rbp)

2:
	mov	EDGS(%rbp), %rdi
	call	ArrayStack_length
	cmp	%rax, CNTR(%rbp)
	jl	1b

	# Restore params and color the vertex black to indicate that we are done
	mov	THIS(%rbp), %rdi
	mov	STRT(%rbp), %rsi
	mov	CLRS(%rbp), %rdx
	mov	OUTP(%rbp), %rcx
	movb	$BLACK, (%rdx, %rsi)

	mov	%rbp, %rsp
	pop	%rbp
	ret
