# proc/handlers/ping.s - Handler for "ping"

.include	"linux.inc"

.globl	ping, ping_handler

.section .rodata

.type	ping, @object
ping:
	.ascii	"ping\0"

pong:
	.ascii	"pong\n"
	.equ	pong_len, . - pong

.section .text

# Prints the message "pong"
.type	ping_handler, @function
ping_handler:
	push	%rbp
	mov	%rsp, %rbp

	mov	$SYS_WRITE, %rax
	mov	$STDOUT, %rdi
	mov	$pong, %rsi
	mov	$pong_len, %rdx
	syscall

	mov	%rbp, %rsp
	pop	%rbp
	ret
