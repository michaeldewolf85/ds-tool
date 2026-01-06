# proc/handlers/selist.s - Handler for SEList

.include	"structs.inc"

.globl	selist, selist_handler

.section .rodata

.type	selist, @object
selist:
	.ascii	"selist\0"

get:
	.ascii	"get\0"
set:
	.ascii	"set\0"
add:
	.ascii	"add\0"
remove:
	.ascii	"remove\0"

null:
	.ascii	"NULL\0"

newline:
	.ascii	"\n\0"

commands:
	.quad	get
	.quad	set
	.quad	add
	.quad	remove
	.quad	0	# Sentinel

handlers:
	.quad	SEList_get
	.quad	SEList_set
	.quad	SEList_add
	.quad	SEList_remove

malformed:
	.ascii	"Malformed command\n\0"

start_delim:
.section .bss

# SEList singleton
this:
	.zero	1<<3

.section .text

# @function	selist_handler
# @description	Handler for the "selist" command
# @param	%rdi	Pointer to the input data
# @return	void
.type	selist_handler, @function
selist_handler:
	push	%rbp
	mov	%rsp, %rbp

	cmpq	$0, this
	je	new

handler:
	mov	Input.argv + 8(%rbx), %rdi	# Second argument is the operation
	xor	%r12, %r12			# Index of found operation

	cmpq	$1, Input.argc(%rbx)		# If only one argument, print the SEList ... 
	je	print

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

print:
	mov	this, %rdi
	call	SEList_log

end:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp	end

# Initialization
new:
	call	SEList_ctor
	mov	%rax, this
	jmp	handler
