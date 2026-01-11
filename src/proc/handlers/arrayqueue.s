# proc/handlers/arrayqueue.s - ArrayQueue handler

.include	"structs.inc"

.globl	arrayqueue, arrayqueue_handler

.section .rodata

# ArrayQueue command string
.type	arrayqueue, @object
arrayqueue:
	.ascii	"arrayqueue\0"

add:
	.ascii	"add\0"
remove:
	.ascii	"remove\0"

commands:
	.quad	add
	.quad	remove
	.quad	0	# Sentinel

handlers:
	.quad	ArrayQueue_add
	.quad	ArrayQueue_remove

newline:
	.ascii	"\n\0"

null:
	.ascii	"NULL\0"

malformed:
	.ascii	"Malformed command\n\0"

.section .bss

# One and only ArrayQueue instance
instance:
	.zero	1<<3

.section .text

# @function	arrayqueue_handler
# @description	Handler for the arrayqueue set of commands
# @param	%rdi	A pointer to an "Input" struct (argc, argv)
# @return	void
.equ	INPUT, -8
.equ	COUNTER, -16
.type	arrayqueue_handler, @function
arrayqueue_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, INPUT(%rbp)
	movq	$0, COUNTER(%rbp)

	# Check for initialization
	cmpq	$0, instance
	je	new

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
	mov	instance, %rdi

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
	mov	instance, %rdi
	call	ArrayQueue_log

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# Not initialized
new:
	call	ArrayQueue_ctor
	mov	%rax, instance
	jmp	1b

error:
	mov	$malformed, %rdi
	call	log
	jmp	2b
