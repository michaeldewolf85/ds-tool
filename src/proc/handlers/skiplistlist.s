# proc/handlers/skiplistlist.s - Handler for the "skiplistlist" command

.include	"common.inc"
.include	"structs.inc"

.globl	skiplistlist, skiplistlist_handler

.section .rodata

skiplistlist:
	.ascii	"skiplistlist\0"

get:
	.ascii	"get\0"
set:
	.ascii	"set\0"
add:
	.ascii	"add\0"
remove:
	.ascii	"remove\0"

commands:
	.quad	get
	.quad	set
	.quad	add
	.quad	remove
	.quad	0	# Sentinel

handlers:
	.quad	SkiplistList_get
	.quad	SkiplistList_set
	.quad	SkiplistList_add
	.quad	SkiplistList_remove

malformed:
	.ascii	"Malformed command\n\0"

newline:
	.ascii	"\n\0"

null:
	.ascii	"NULL\0"

.section .bss

this:
	.zero	1<<3

.section .text

# @function	skiplistlist_handler
# @description	Handler for the skiplistlist command
# @param	%rdi	Pointer to the user input
# @return	void
.equ	THIS, -8
.type	skiplistlist_handler, @function
skiplistlist_handler:
	push	%rbp
	mov	%rsp, %rbp

	cmpq	$NULL, this
	jne	1f

	call	SkiplistList_ctor
	mov	%rax, this

1:
	mov	Input.argv + 8(%rbx), %rdi	# Second argument is the operation
	xor	%r12, %r12			# Index of found operation

	cmpq	$1, Input.argc(%rbx)		# If only one argument, print the DLList ... 
	je	4f

	cmpq	$3, Input.argc(%rbx)		# Otherwise, we must have 3 arguments to be valid
	jl	error

check:
	mov	commands(, %r12, 8), %rsi
	cmp	$0, %rsi			# Check for the sentinel, if we match here the 
	je	error				# command was not found

	call	strcmp
	cmp	$0, %rax
	je	match

	inc	%r12
	jmp	check

match:
	mov	Input.argv + 16(%rbx), %rdi	# Third argument is always an index
	call	atoi
	cmp	$0, %rax
	jl	error

	mov	%rax, %rsi
	mov	Input.argv + 24(%rbx), %rdx	# Third argument may be a string pointer

	mov	this, %rdi			# Ensure instance is in place
	call	*handlers(, %r12, 8)		# Call the handler

	mov	$null, %r12
	mov	%rax, %rdi
	cmp	$0, %rax
	cmove	%r12, %rdi
	call	log

	mov	$newline, %rdi
	call	log

4:
	mov	this, %rdi
	call	SkiplistList_log

5:

	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp 5b
