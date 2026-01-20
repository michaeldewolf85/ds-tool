# proc/handlers/linearhashtable.s - Handler for the "linearhashtable" command

.include	"common.inc"

.globl	linearhashtable, linearhashtable_handler

.section .rodata

.type	linearhashtable, @object
linearhashtable:
	.ascii	"linearhashtable\0"

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

# @function	linearhashtable_handler
# @description	Handler for the "linearhashtable" command
# @return	void
.type	linearhashtable_handler, @function
linearhashtable_handler:
	cmpq	$NULL, this
	jne	1f

	call	LinearHashTable_ctor
	mov	%rax, this

1:
	mov	this, %rdi
	mov	$item1, %rsi
	call	LinearHashTable_find

	mov	$item1, %rsi
	call	LinearHashTable_add

	mov	$item2, %rsi
	call	LinearHashTable_add

	mov	$item3, %rsi
	call	LinearHashTable_add

	mov	$item4, %rsi
	call	LinearHashTable_add

	mov	$item2, %rsi
	call	LinearHashTable_find

	mov	$item3, %rsi
	call	LinearHashTable_find

	mov	$item4, %rsi
	call	LinearHashTable_find

	mov	$item5, %rsi
	call	LinearHashTable_find

	mov	$item6, %rsi
	call	LinearHashTable_find

	mov	$item2, %rsi
	call	LinearHashTable_remove

	mov	$item3, %rsi
	call	LinearHashTable_remove

2:
	ret
