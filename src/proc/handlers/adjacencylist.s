# proc/handlers/adjacencylist.s - Handler for the adjacencylist command

.include	"common.inc"
.include	"structs.inc"

.globl	adjacencylist, adjacencylist_handler

.equ	ADJACENCY_LIST_DEFAULT_SIZE, 10
.section .rodata

.type	adjacencylist, @object
adjacencylist:
	.ascii	"adjacencylist\0"

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
bfs:
	.ascii	"bfs\0"
rdfs:
	.ascii	"rdfs\0"
dfs:
	.ascii	"dfs\0"
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
	.quad	bfs
	.quad	rdfs
	.quad	dfs
	.quad	0	# Sentinel

handlers:
	.quad	AdjacencyList_add_edge
	.quad	AdjacencyList_remove_edge
	.quad	AdjacencyList_has_edge
	.quad	AdjacencyList_in_edges
	.quad	AdjacencyList_out_edges
	.quad	AdjacencyList_bfs
	.quad	AdjacencyList_rdfs
	.quad	AdjacencyList_dfs

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

# @function	adjacencylist_handler
# @description	Handler for the adjacencylist command
# @param	%rdi	Pointer to use input
# @return	void
.equ	INPUT, -8
.equ	COUNTER, -16
.equ	ARG1, -24
.equ	ARG2, -32
.equ	ARR, -40
.equ	LEN, -48
.type	adjacencylist_handler, @function
adjacencylist_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$48, %rsp
	mov	%rdi, INPUT(%rbp)
	movq	$0, COUNTER(%rbp)

	cmpq	$NULL, this
	jne	1f

	mov	$ADJACENCY_LIST_DEFAULT_SIZE, %rdi
	call	AdjacencyList_ctor
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
	test	%rdi, %rdi
	jz	skip

	call	atoi
	mov	%rax, ARG2(%rbp)

skip:

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
	# Return value was NOT a simple TRUE/FALSE and was an ArrayStack
	mov	%rax, %rdi
	call	ArrayStack_slog

6:
	mov	$newline, %rdi
	call	log

	mov	$newline, %rdi
	call	log

7:
	mov	this, %rdi
	call	AdjacencyList_log

8:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp	8b
