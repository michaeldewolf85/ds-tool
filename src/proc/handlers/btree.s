# proc/handlers/btree.s - Handler for the "btree" command

.include	"common.inc"
.include	"structs.inc"

.globl	btree, btree_handler

.equ	BLOCK_SIZE, 56
.section .rodata

.type	btree, @object
btree:
	.ascii	"btree\0"

add:
	.ascii	"add\0"
remove:
	.ascii	"remove\0"
find:
	.ascii	"find\0"

commands:
	.quad	add
	.quad	remove
	.quad	find
	.quad	0	# Sentinel

handlers:
	.quad	BTree_add
	.quad	BTree_remove
	.quad	BTree_find

newline:
	.ascii	"\n\0"

null:
	.ascii	"NULL\0"

malformed:
	.ascii	"Malformed command\n\0"

filename:
	.ascii	"btree.dat\0"

true:
	.ascii	"TRUE\0"
false:
	.ascii	"FALSE\0"

.section .bss

this:
	.zero	1<<3

.section .text

# @public	btree_handler
# @description	Handler for the "btree" command
# @param	%rdi	Pointer to user input
# @return	void
.equ	INPUT, -8
.equ	COUNTER, -16
.equ	RESB, -64
.type	btree_handler, @function
btree_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$64, %rsp
	mov	%rdi, INPUT(%rbp)
	movq	$0, COUNTER(%rbp)


	mov	$filename, %rdi
	call	BTree_ctor
	mov	%rax, this


1:
	mov	INPUT(%rbp), %rax		# Input
	cmpq	$1, Input.argc(%rax)		# If only 1 argument, print the ArrayQueue
	je	3f

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

	mov	INPUT(%rbp), %rax		# Only "add" command takes an argument but argv ...
	mov	Input.argv + 16(%rax), %rsi	# passes zeroes in all the other slots
	lea	RESB(%rbp), %rdx
	mov	COUNTER(%rbp), %rcx
	call	*handlers(, %rcx, 1<<3)

	cmpq	$2, COUNTER(%rbp)
	jne	2f

	lea	RESB(%rbp), %rdi
	test	%rdi, %rdi
	jnz	1f

	mov	$false, %rdi

1:
	call	log
	jmp	3f

2:
	mov	$true, %rdi
	mov	$false, %rsi
	test	%rax, %rax
	cmovz	%rsi, %rdi
	call	log

3:
	mov	$newline, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	this, %rdi
	call	BTree_log

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp	4b
	mov	this, %rdi
