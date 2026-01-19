# proc/handlers/chainedhashtable.s - Handler for the "chainedhashtable" command

.include	"common.inc"

.globl	chainedhashtable, chainedhashtable_handler

.section .rodata

.type	chainedhashtable, @object
chainedhashtable:
	.ascii	"chainedhashtable\0"

# TODO REMOVE!!
item1:
	.ascii	"Bananas\0"
item2:
	.ascii	"Strawberries\0"
item3:
	.ascii	"Apples\0"
item4:
	.ascii	"Blueberries\0"
item5:
	.ascii	"Cantaloupe\0"
item6:
	.ascii	"Blackberries\0"
item7:
	.ascii	"Dragonfruit\0"
item8:
	.ascii	"Oranges\0"

.section .bss

this:
	.zero	1<<3

.section .text

# @function	chainedhashtable_handler
# @description	Handler for the "chainedhashtable" command
# @return	void
.type	chainedhashtable_handler, @function
chainedhashtable_handler:
	push	%rbp
	mov	%rsp, %rbp

	cmp	$NULL, this
	jne	1f

	call	ChainedHashTable_ctor
	mov	%rax, this

1:
	mov	this, %rdi

	mov	$123, %rsi
	call	ChainedHashTable_add

	mov	$123, %rsi
	call	ChainedHashTable_find

	mov	$456, %rsi
	call	ChainedHashTable_add

	mov	$789, %rsi
	call	ChainedHashTable_add

	mov	$123456, %rsi
	call	ChainedHashTable_add

	mov	$234567, %rsi
	call	ChainedHashTable_add

	mov	$345678, %rsi
	call	ChainedHashTable_add

	mov	$123, %rsi
	call	ChainedHashTable_remove

	mov	%rbp, %rsp
	pop	%rbp
	ret
