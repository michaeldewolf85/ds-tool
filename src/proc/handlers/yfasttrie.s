# proc/handlers/yfasttrie.s - Handler for the "yfasttrie" command

.include	"common.inc"
.include	"structs.inc"

.globl	yfasttrie, yfasttrie_handler

.section .bss

this:
	.zero	1<<3

.section .rodata

yfasttrie:
	.ascii	"yfasttrie\0"

.section .text

# @function	yfasttrie_handler
# @description	Handler for the "yfasttrie" command
# @param	%rdi	User input
# @return	void
.type	yfasttrie_handler, @function
yfasttrie_handler:
	push	%rbp
	mov	%rsp, %rbp

	cmpq	$NULL, this
	jne	1f

	call	YFastTrie_ctor
	mov	%rax, this

1:
	mov	this, %rdi

	mov	$1, %rsi
	call	YFastTrie_add

	mov	%rbp, %rsp
	pop	%rbp
	ret
