# proc/handlers/exit.s - Handler for "exit"

.include	"linux.inc"

.globl	exit, exit_handler

.section .rodata

.type	exit, @object
exit:
	.ascii	"exit\0"

.section .text

# Exist the program
.type	exit_handler, @function
exit_handler:
	mov	$SYS_EXIT, %rax
	mov	$EXIT_SUCCESS, %rdi
	syscall
