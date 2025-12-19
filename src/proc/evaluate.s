# proc/evaluate.s - Evaluate parsed input and delegate to the appropriate handler

.include "linux.inc"
.include "structs.inc"

.globl evaluate

.section .rodata

## Command strings
exit:
	.ascii	"exit\0"
ping:
	.ascii	"ping\0"

commands:
	.quad	exit
	.quad	ping
	.quad	0	# Sentinel

handlers:
	.quad	exit_handler
	.quad	ping_handler
	.quad	error_handler

pong:
	.ascii	"PONG\n"
	.equ	pong_len, . - pong
error:
	.ascii	"Unrecognized command\n"
	.equ	error_len, . - error

.section .text

exit_handler:
	mov	$SYS_EXIT, %rax
	mov	$EXIT_SUCCESS, %rdi
	syscall

ping_handler:
	mov	$SYS_WRITE, %rax
	mov	$STDOUT, %rdi
	mov	$pong, %rsi
	mov	$pong_len, %rdx
	syscall

	ret

error_handler:
	mov	$SYS_WRITE, %rax
	mov	$STDOUT, %rdi
	mov	$error, %rsi
	mov	$error_len, %rdx
	syscall

	ret

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
