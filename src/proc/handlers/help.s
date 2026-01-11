# proc/handlers/help.s - Handler for the "help" command

.include	"common.inc"

.globl	help, help_handler

.section .rodata

.type	help, @object
help:
	.ascii	"help\0"

help_text:
	.ascii	"Available commands:\n\0"

help_addl:
	.ascii	"Use \"<command> help\" to list available operations\n\0"

lf:
	.byte	LF, NULL

list_item:
	.ascii	"  * \0"

.section .text

# @function	help_handler
# @description	Prints a list of evaluate_commands
# @return	void
.equ	NUM, -8
.equ	CMD, -16
help_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp

	# Header
	mov	$help_text, %rdi
	call	log

	movq	$0, NUM(%rbp)
	jmp	2f

1:
	mov	%rcx, CMD(%rbp)

	mov	$list_item, %rdi
	call	log

	mov	CMD(%rbp), %rdi
	call	log

	mov	$lf, %rdi
	call	log

	incq	NUM(%rbp)
	
2:
	mov	NUM(%rbp), %rax
	mov	evaluate_commands(,%rax, 1<<3), %rcx
	cmp	$NULL, %rcx
	jne	1b

	mov	$help_addl, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret
