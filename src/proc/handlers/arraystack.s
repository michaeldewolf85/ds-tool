# proc/handlers/array-stack.s - ArrayStack handler

.include	"common.inc"
.include	"structs.inc"

.globl	arraystack, arraystack_handler, ArrayStack_get, ArrayStack_set, ArrayStack_add
.globl	ArrayStack_remove, ArrayStack_log, ArrayStack_ctor, ArrayStack_length, ArrayStack_size

.section .rodata

# Arraystack command string
.type	arraystack, @object
arraystack:
	.ascii	"arraystack\0"

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
	.quad	ArrayStack_get
	.quad	ArrayStack_set
	.quad	ArrayStack_add
	.quad	ArrayStack_remove

malformed:
	.ascii	"Malformed command\n\0"

null:
	.ascii	"NULL\0"

newline:
	.ascii	"\n\0"

.section .bss

# Static pointer to the one and only ArrayStack instance
instance:
	.zero	1<<3

.section .text

# @function	arraystack_handler
# @description	Handler for the arraystack set of commands
# @param	%rdi	Pointer to the Input struct
# @return	void
.equ	RETURN_VALUE, -8
.type	arraystack_handler, @function
arraystack_handler:
	push	%rbp
	mov	%rsp, %rbp

	push	%rbx
	push	%r12
	mov	%rdi, %rbx

	mov	instance, %rdi
	cmp	$NULL, %rdi
	je	new

1:
	mov	Input.argv + 8(%rbx), %rdi	# Second argument is the operation
	xor	%r12, %r12			# Index of found operation

	cmpq	$1, Input.argc(%rbx)		# If only one argument, print the arraystack ... 
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

	mov	instance, %rdi			# Ensure instance is in place
	call	*handlers(, %r12, 8)		# Call the handler

	# Save return value on the stack
	sub	$8, %rsp
	mov	%rax, RETURN_VALUE(%rbp)

	# Log return value
	mov	RETURN_VALUE(%rbp), %rax
	mov	$null, %r12
	mov	%rax, %rdi
	cmp	$0, %rax
	cmove	%r12, %rdi
	call	log

	mov	$newline, %rdi
	call	log

4:
	mov	instance, %rdi
	call	ArrayStack_log

3:
	pop	%r12
	pop	%rbx

	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp 3b

# No instance yet, so create one
new:
	call	ArrayStack_ctor
	mov	%rax, instance
	jmp	1b
