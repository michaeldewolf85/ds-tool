# proc/handlers/arraydeque.s - ArrayDeque handler

.include	"structs.inc"

.globl	arraydeque, arraydeque_handler

.section .rodata

.type	arraydeque, @object
arraydeque:
	.ascii	"arraydeque\0"

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
	.quad	ArrayDeque_get
	.quad	ArrayDeque_set
	.quad	ArrayDeque_add
	.quad	ArrayDeque_remove

malformed:
	.ascii	"Malformed command\n\0"

newline:
	.ascii	"\n\0"

null:
	.ascii	"NULL\0"

.section .bss

# ArrayDeque singleton
instance:
	.zero	1<<3

.section .text

# @function	arraydeque_handler
# @description	Handler for the arraydeque set of commands
# @param	%rdi	Pointer to the Input data struct
# @return	void
.type	arraydeque_handler, @function
arraydeque_handler:
	push	%rbp
	mov	%rsp, %rbp

	cmpq	$0, instance
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

	mov	$null, %r12
	mov	%rax, %rdi
	cmp	$0, %rax
	cmove	%r12, %rdi
	call	log

	mov	$newline, %rdi
	call	log

4:
	mov	instance, %rdi
	call	ArrayDeque_log
3:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp 3b

# ArrayDeque not initialized
new:
	call	ArrayDeque_ctor
	mov	%rax, instance
	jmp	1b
