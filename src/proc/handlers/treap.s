# proc/handlers/treap.s - Handler for the "treap" command

.include	"common.inc"
.include	"structs.inc"

.globl	treap, treap_handler

.section .rodata

.type	treap, @object
treap:
	.ascii	"treap\0"

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
	.quad	Treap_add
	.quad	Treap_remove
	.quad	Treap_find

newline:
	.ascii	"\n\0"

null:
	.ascii	"NULL\0"

malformed:
	.ascii	"Malformed command\n\0"

.section .bss

this:
	.zero	1<<3

.section .text

# @function	treap_handler
# @description	Handler for the "treap" command
# @param	%rdi	Pointer to the user input
# @return	void
.equ	INPUT, -8
.equ	COUNTER, -16
.type	treap_handler, @function
treap_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, INPUT(%rbp)
	movq	$0, COUNTER(%rbp)

	cmpq	$0, this
	jnz	1f

	call	Treap_ctor
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

	mov	COUNTER(%rbp), %rcx
	call	*handlers(, %rcx, 1<<3)

	mov	$null, %rcx
	cmp	$0, %rax
	cmove	%rcx, %rax

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

3:
	mov	this, %rdi
	call	Treap_log

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp	4b
