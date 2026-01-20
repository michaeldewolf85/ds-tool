# proc/handlers/linearhashtable.s - Handler for the "linearhashtable" command

.include	"common.inc"

.globl	linearhashtable, linearhashtable_handler

.section .rodata

.type	linearhashtable, @object
linearhashtable:
	.ascii	"linearhashtable\0"

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
	mov	$123, %rsi
	call	LinearHashTable_find

	mov	$123456, %rsi
	call	LinearHashTable_add

	mov	$234567, %rsi
	call	LinearHashTable_add

	mov	$345678, %rsi
	call	LinearHashTable_add

	mov	$456789, %rsi
	call	LinearHashTable_add

	mov	$123456, %rsi
	call	LinearHashTable_find

	mov	$234567, %rsi
	call	LinearHashTable_find

	mov	$345678, %rsi
	call	LinearHashTable_find

	mov	$456789, %rsi
	call	LinearHashTable_find

	mov	$456, %rsi
	call	LinearHashTable_find

	mov	$234567, %rsi
	call	LinearHashTable_remove

	mov	$345678, %rsi
	call	LinearHashTable_remove


2:
	ret
