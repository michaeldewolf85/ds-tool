# proc/handlers/error.s - Catch all error handler

.include	"linux.inc"

.globl	error_handler

.section .rodata

error:
	.ascii	"Unrecognized command\n"
	.equ	error_len, . - error

.section .text

# Prints an error
.type	error_handler, @function
error_handler:
	push	%rbp
	mov	%rsp, %rbp

	mov	$SYS_WRITE, %rax
	mov	$STDOUT, %rdi
	mov	$error, %rsi
	mov	$error_len, %rdx
	syscall

	mov	%rbp, %rsp
	pop	%rbp
	ret
