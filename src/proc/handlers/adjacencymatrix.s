# proc/handlers/adjacencymatrix.s - Handler for the adjacencymatrix command

.include	"common.inc"
.include	"structs.inc"

.globl	adjacencymatrix, adjacencymatrix_handler

.equ	ADJACENCY_MATRIX_DEFAULT_SIZE, 10
.section .rodata

.type	adjacencymatrix, @object
adjacencymatrix:
	.ascii	"adjacencymatrix\0"

add:
	.ascii	"add\0"
remove:
	.ascii	"remove\0"
has:
	.ascii	"has\0"
in:
	.ascii	"in\0"
out:
	.ascii	"out\0"
sdelim:
	.ascii	"[ \0"
mdelim:
	.ascii	", \0"
edelim:
	.ascii	" ]\0"


commands:
	.quad	add
	.quad	remove
	.quad	has
	.quad	in
	.quad	out
	.quad	0	# Sentinel

handlers:
	.quad	AdjacencyMatrix_add_edge
	.quad	AdjacencyMatrix_remove_edge
	.quad	AdjacencyMatrix_has_edge
	.quad	AdjacencyMatrix_in_edges
	.quad	AdjacencyMatrix_out_edges

newline:
	.ascii	"\n\0"
null:
	.ascii	"NULL\0"
malformed:
	.ascii	"Malformed command\n\0"
false:
	.ascii	"FALSE\0"
true:
	.ascii	"TRUE\0"

.section .bss

this:
	.zero	1<<3

.section .text

# @function	adjacencymatrix_handler
# @description	Handler for the adjacencymatrix command
# @param	%rdi	Pointer to use input
# @return	void
.equ	INPUT, -8
.equ	COUNTER, -16
.equ	ARG1, -24
.equ	ARG2, -32
.equ	ARR, -40
.equ	LEN, -48
.type	adjacencymatrix_handler, @function
adjacencymatrix_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$48, %rsp
	mov	%rdi, INPUT(%rbp)
	movq	$0, COUNTER(%rbp)

	cmpq	$NULL, this
	jne	1f

	mov	$ADJACENCY_MATRIX_DEFAULT_SIZE, %rdi
	call	AdjacencyMatrix_ctor
	mov	%rax, this

1:
	mov	INPUT(%rbp), %rax		# Input
	cmpq	$1, Input.argc(%rax)		# If only 1 argument, print the ArrayQueue
	je	7f

	mov	Input.argv + 8(%rax), %rdi	# Current command in %rdi
check:
	mov	COUNTER(%rbp), %rcx
	mov	commands(, %rcx, 1<<3), %rsi	# Current command being examined
	cmp	$0, %rsi			# Check for NULL sentinel which indicates no ...
	je	error				# matching command was found

	call	strcmp
	cmp	$0, %rax
	je	match

	incq	COUNTER(%rbp)
	jmp	check

match:
	mov	this, %rdi

	mov	INPUT(%rbp), %rax
	mov	Input.argv + 16(%rax), %rdi
	call	atoi
	mov	%rax, ARG1(%rbp)

	mov	INPUT(%rbp), %rax
	mov	Input.argv + 24(%rax), %rdi
	call	atoi
	mov	%rax, ARG2(%rbp)

	mov	this, %rdi
	mov	ARG1(%rbp), %rsi
	mov	ARG2(%rbp), %rdx
	mov	COUNTER(%rbp), %rcx
	call	*handlers(, %rcx, 1<<3)

	test	%rax, %rax
	jnz	1f

	mov	$false, %rdi
	jmp	2f

1:
	cmp	$TRUE, %rax
	jne	3f

	mov	$true, %rdi
2:
	call	log
	jmp	6f

3:
	# Return value was NOT a simple TRUE/FALSE and we need to iterate over the result
	mov	(%rax), %rcx	# Length of array
	mov	%rcx, LEN(%rbp)
	lea	8(%rax), %rcx	# Values of array
	mov	%rcx, ARR(%rbp)
	movq	$0, COUNTER(%rbp)
	mov	$sdelim, %rdi
	call	log
	jmp	5f

4:
	mov	ARR(%rbp), %rax
	mov	(%rax, %rcx, 1<<3), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	incq	COUNTER(%rbp)
	mov	COUNTER(%rbp), %rcx
	cmp	LEN(%rbp), %rcx
	jge	5f

	mov	$mdelim, %rdi
	call	log

5:
	mov	COUNTER(%rbp), %rcx
	cmp	LEN(%rbp), %rcx
	jl	4b

	mov	$edelim, %rdi
	call	log

6:
	mov	$newline, %rdi
	call	log

	mov	$newline, %rdi
	call	log

7:
	mov	this, %rdi
	call	AdjacencyMatrix_log

8:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp	8b
