# proc/handlers/error.s - Catch all error handler

.include	"linux.inc"

.globl	error_handler

.section .rodata

error:
	.ascii	"Unrecognized command\n\0"

.section .text

# Prints an error
.type	error_handler, @function
error_handler:
	mov	$error, %rdi
	call	log
	ret
