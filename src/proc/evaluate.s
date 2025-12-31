# proc/evaluate.s - Evaluate parsed input and delegate to the appropriate handler

.include	"linux.inc"
.include	"structs.inc"

.globl	evaluate

.section .rodata

commands:
	.quad	exit
	.quad	ping
	.quad	arraystack
	.quad	arrayqueue
	.quad	0	# Sentinel

handlers:
	.quad	exit_handler
	.quad	ping_handler
	.quad	arraystack_handler
	.quad	arrayqueue_handler
	.quad	error_handler

.section .text

# Evaluate user input
# @param 	%rdi	Address of the input struct
# @return	%rax	Address of a (null terminated) output message
.type	evaluate, @function
evaluate:
	push	%rbp
	push	%rbx				# Pointer to input struct
	push	%r12				# Index into commands array
	mov	%rsp, %rbp

	mov	%rdi, %rbx

	mov	Input.argv(%rdi), %rdi		# Make %rdi point to the first argv
	xor	%r12, %r12			# Zero out an index register

check:
	mov	commands(, %r12, 8), %rsi
	cmp	$0, %rsi			# Check for the sentinel, if we match here the 
	je	match				# command was not found

	call	strcmp
	cmp	$0, %rax
	je	match

	inc	%r12
	jmp	check

match:
	mov	%rbx, %rdi
	call	*handlers(, %r12, 8)		# Call the handler

	mov	%rbp, %rsp
	pop	%r12
	pop	%rbx
	pop	%rbp
	ret
