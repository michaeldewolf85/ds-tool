# proc/handlers/binarytree.s - Handler for the "binarytree" command

.include	"common.inc"
.include	"structs.inc"

.globl	binarytree, binarytree_handler

.section .rodata

binarytree:
	.ascii	"binarytree\0"

traverse_delim:
	.ascii	" -> \0"
sdelim:
	.ascii	"{ \0"
edelim:
	.ascii	" }\0"
idx_label:
	.ascii	"idx => \0"
depth_label:
	.ascii	", depth => \0"
size_label:
	.ascii	"Size (non-recursive)         => \0"
rsize_label:
	.ascii	"Size (recursive)             => \0"
rheight_label:
	.ascii	"Height (recursive)           => \0"
traversal_label:
	.ascii	"Traversal (non-recursive)    => \0"
rtraversal_label:
	.ascii	"Traversal (recursive)        => \0"
traversal_sdelim:
	.ascii	"[ \0"
traversal_mdelim:
	.ascii	", \0"
traversal_edelim:
	.ascii	" ]\0"
bftraversal_label:
	.ascii	"Breadth traversal            => {\0"
bftraversal_end:
	.ascii	"}\0"
spacer:
	.ascii	"  \0"

malformed:
	.ascii	"Malformed command\n\0"

newline:
	.byte	LF, NULL

.section .bss

this:
	.zero	1<<3

.section .text

# @function	binarytree_handler
# @description	Handler for the "binarytree" command
# @param	%rdi	Pointer to the input data
# @return	void
.type	binarytree_handler, @function
binarytree_handler:
	push	%rbp
	mov	%rsp, %rbp

	cmpq	$2, Input.argc(%rdi)		# Requires 2 arguments
	jne	error

	mov	Input.argv + 8(%rdi), %rdi	# Seconds arg is always an int
	call	atoi
	cmp	$0, %rax
	je	error

	mov	%rax, %rdi
	call	BinaryTree_ctor
	mov	%rax, this

	mov	$newline, %rdi
	call	log

	mov	$size_label, %rdi
	call	log

	mov	this, %rdi
	call	BinaryTree_size
	mov	%rax, %rdi
	call	itoa
	mov	%rax, %rdi
	call	 log

	mov	$newline, %rdi
	call	log

	mov	$rsize_label, %rdi
	call	log

	mov	this, %rdi
	call	BinaryTree_rsize
	mov	%rax, %rdi
	call	itoa
	mov	%rax, %rdi
	call	 log

	mov	$newline, %rdi
	call	log

	mov	$rheight_label, %rdi
	call	log

	mov	this, %rdi
	call	BinaryTree_rheight
	mov	%rax, %rdi
	call	itoa
	mov	%rax, %rdi
	call	 log

	mov	$newline, %rdi
	call	log

	mov	$bftraversal_label, %rdi
	call	log

	mov	this, %rdi
	mov	$log_bftraverse, %rsi
	call	BinaryTree_bftraverse

	mov	$newline, %rdi
	call	log

	mov	$bftraversal_end, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$traversal_label, %rdi
	call	log

	mov	$traversal_sdelim, %rdi
	call	log

	mov	this, %rdi
	mov	$log_traverse, %rsi
	call	BinaryTree_traverse

	mov	$traversal_edelim, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$rtraversal_label, %rdi
	call	log

	mov	$traversal_sdelim, %rdi
	call	log

	mov	this, %rdi
	mov	$log_traverse, %rsi
	call	BinaryTree_rtraverse

	mov	$traversal_edelim, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	this, %rdi
	call	BinaryTree_dtor

1:
	mov	%rbp, %rsp
	pop	%rbp
	ret
error:
	mov	$malformed, %rdi
	call	log
	jmp	1b

# Callback for breadth traversal logging
.equ	THIS, -8
log_bftraverse:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	# Powers of two mean a new row
	mov	THIS(%rbp), %rdi
	mov	(%rdi), %rdi
	lea	-1(%rdi), %rax
	test	%rax, %rdi
	jnz	1f

	mov	$newline, %rdi
	call	log

	mov	$spacer, %rdi
	call	log

1:
	mov	$sdelim, %rdi
	call	log

	mov	$idx_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	(%rdi), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$depth_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	call	BinaryTreeNode_depth
	mov	%rax, %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$edelim, %rdi
	call	log

	mov	$traverse_delim, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# Callback for traversal logging
.equ	THIS, -8
log_traverse:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	mov	THIS(%rbp), %rdi
	mov	(%rdi), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$traversal_mdelim, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret
