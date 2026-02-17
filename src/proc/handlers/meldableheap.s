# proc/handlers/meldableheap.s - Handler for the "meldableheap" command

.include	"common.inc"
.include	"structs.inc"

.globl	meldableheap, meldableheap_handler

.section .rodata

.type	meldableheap, @object
meldableheap:
	.ascii	"meldableheap\0"

add:
	.ascii	"add\0"
remove:
	.ascii	"remove\0"

commands:
	.quad	add
	.quad	remove
	.quad	0	# Sentinel

handlers:
	.quad	MeldableHeap_add
	.quad	MeldableHeap_remove

newline:
	.ascii	"\n\0"

null:
	.ascii	"NULL\0"

malformed:
	.ascii	"Malformed command\n\0"

.section .bss

this:
	.zero	1<<3

.section .text

# @function	meldableheap_handler
# @description	Handler for the "meldableheap" command
# @param	%rdi	Pointer to the InputData struct
# @return	void
.equ	INPUT, -8
.equ	COUNTER, -16
.type	meldableheap_handler, @function
meldableheap_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, INPUT(%rbp)
	movq	$0, COUNTER(%rbp)

	cmpq	$NULL, this
	jne	1f

	call	MeldableHeap_ctor
	mov	%rax, this

1:
	mov	INPUT(%rbp), %rax		# Input
	cmpq	$1, Input.argc(%rax)		# If only 1 argument, print the ArrayQueue
	je	3f

	mov	Input.argv + 8(%rax), %rdi	# Current command in %rdi
check:
	mov	COUNTER(%rbp), %rcx
	mov	commands(, %rcx, 1<<3), %rsi	# Current command being examined
	cmp	$0, %rsi			# Check for NULL sentinel which indicates no ...
	je	error				# matching command was found

	call	strcmp
	cmp	$0, %rax
	je	match

	incq	COUNTER(%rbp)
	jmp	check

match:
	mov	this, %rdi

	mov	INPUT(%rbp), %rax		# Only "add" command takes an argument but argv ...
	mov	Input.argv + 16(%rax), %rsi	# passes zeroes in all the other slots

	mov	COUNTER(%rbp), %rcx
	call	*handlers(, %rcx, 1<<3)

	mov	$null, %rcx
	cmp	$0, %rax
	cmove	%rcx, %rax

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$newline, %rdi
	call	log

3:
	mov	this, %rdi
	call	MeldableHeap_log

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp	4b
