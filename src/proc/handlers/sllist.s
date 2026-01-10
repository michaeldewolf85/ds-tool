# proc/handlers/sllist.s - Handler fo SLList

.include	"common.inc"
.include	"structs.inc"

.globl	sllist, sllist_handler

.section .rodata

.type	sllist, @object
sllist:
	.ascii	"sllist\0"

add:
	.ascii	"add\0"
pop:
	.ascii	"pop\0"
push:
	.ascii	"push\0"
remove:
	.ascii	"remove\0"

commands:
	.quad	add
	.quad	pop
	.quad	push
	.quad	remove
	.quad	0	# Sentinel

handlers:
	.quad	SLList_add
	.quad	SLList_pop
	.quad	SLList_push
	.quad	SLList_remove

malformed:
	.ascii	"Malformed command\n\0"

null:
	.ascii	"NULL\0"

newline:
	.ascii	"\n\0"

.section .bss

# SLList singleton
this:
	.zero	1<<3

.section .text

# @function	sllist_handler
# @description	Handler for the "sllist" command
# @param	%rdi	Pointer to the input args struct
# @return	void
.equ	INPUT, -8
.type	sllist_handler, @function
sllist_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, INPUT(%rbp)

	cmpq	$0, this
	je	new

handler:
	mov	INPUT(%rbp), %rax		# Input
	cmpq	$1, Input.argc(%rax)		# If only 1 argument, print the SLList
	je	3f

	mov	Input.argv + 8(%rax), %rdi	# Current command in %rdi
	xor	%r9, %r9
check:
	mov	commands(, %r9, 1<<3), %rsi	# Current command being examined
	cmp	$0, %rsi			# Check for NULL sentinel which indicates no ...
	je	error				# matching command was found

	call	strcmp
	cmp	$0, %rax
	je	match

	inc	%r9
	jmp	check

match:
	mov	this, %rdi

	mov	INPUT(%rbp), %rax
	mov	Input.argv + 16(%rax), %rsi

	call	*handlers(, %r9, 1<<3)

	mov	$null, %rcx
	cmp	$0, %rax
	cmove	%rcx, %rax

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

3:
	mov	this, %rdi
	call	SLList_log

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp	4b
# Initialization
new:
	call	SLList_ctor
	mov	%rax, this
	jmp	handler
