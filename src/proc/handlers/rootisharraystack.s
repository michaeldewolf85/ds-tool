# proc/handlers/rootisharraystack.s - Handlers for RootishArrayStack

.include	"structs.inc"

.globl	rootisharraystack, rootisharraystack_handler

.section .rodata

.type	rootisharraystack, @object
rootisharraystack:
	.ascii	"rootisharraystack\0"

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
	.quad	RootishArrayStack_get
	.quad	RootishArrayStack_set
	.quad	RootishArrayStack_add
	.quad	RootishArrayStack_remove

newline:
	.ascii	"\n\0"

malformed:
	.ascii	"Malformed command\n\0"

null:
	.ascii	"NULL\0"

.section .bss

this:
	.zero	1<<3

.section .text

# @function	rootisharraystack_handler
# @description	Handler for the "rootisharraystack" command
# @param	%rdi	Pointer to Input
# @return	void
.type	rootisharraystack_handler, @function
rootisharraystack_handler:
	push	%rbp
	mov	%rsp, %rbp

	cmpq	$0, this
	je	new

handler:
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
	call	RootishArrayStack_log
3:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp 3b

# Initialization
new:
	call	RootishArrayStack_ctor
	mov	%rax, this
	jmp	handler
