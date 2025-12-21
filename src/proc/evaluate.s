# proc/evaluate.s - Evaluate parsed input and delegate to the appropriate handler

.include "linux.inc"
.include "structs.inc"

.globl evaluate

.section .rodata

commands:
	.quad	exit
	.quad	ping
	.quad	0	# Sentinel

handlers:
	.quad	exit_handler
	.quad	ping_handler
	.quad	error_handler

.section .text

# Evaluate user input
# @param 	%rdi	Address of the input struct
# @return	%rax	Address of a (null terminated) output message
.type evaluate, @function
evaluate:
	push	%rbp
	mov	%rsp, %rbp

	mov	Input.argv(%rdi), %rdi		# Make %rdi point to the first argv
	xor	%rbx, %rbx			# Zero out an index register

check:
	mov	commands(, %rbx, 8), %rsi
	cmp	$0, %rsi			# Check for the sentinel, if we match here the 
	je	match				# command was not found

	call	strcmp
	cmp	$0, %rax
	je	match

	inc	%rbx
	jmp	check

match:
	call	*handlers(, %rbx, 8)		# Call the handler

	mov	%rbp, %rsp
	pop	%rbp
	ret
