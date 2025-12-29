# proc/handlers/ping.s - Handler for "ping"

.globl	ping, ping_handler

.section .rodata

.type	ping, @object
ping:
	.ascii	"ping\0"

pong:
	.ascii	"pong\n\0"

.section .text

# Logs the message "pong"
.type	ping_handler, @function
ping_handler:
	mov	$pong, %rdi
	call	log
	ret
