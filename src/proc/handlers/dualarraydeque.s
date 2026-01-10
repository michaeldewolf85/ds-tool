# proc/handlers/dualarraydeque.s - Handlers for DualArrayDeque

.include	"structs.inc"

.globl	dualarraydeque, dualarraydeque_handler

.section .rodata

.type	dualarraydeque, @object
dualarraydeque:
	.ascii	"dualarraydeque\0"

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
	.quad	DualArrayDeque_get
	.quad	DualArrayDeque_set
	.quad	DualArrayDeque_add
	.quad	DualArrayDeque_remove

newline:
	.ascii	"\n\0"

malformed:
	.ascii	"Malformed command\n\0"

null:
	.ascii	"NULL\0"

.section .bss

# DualArrayDeque singleton pointer
instance:
	.zero	1<<3

.section .text

# @function	dualarraydeque_handler
# @description	Handler for the "dualarraydeque" command
# @param	%rdi	Pointer to the Input args struct
# @return	void
.type	dualarraydeque_handler, @function
dualarraydeque_handler:
	push	%rbp
	mov	%rsp, %rbp

	# Check for initialization
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
	call	DualArrayDeque_log
3:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp 3b

# DualArrayDeque singleton NOT initialized yet
new:
	call	DualArrayDeque_ctor
	mov	%rax, instance
	jmp	1b
