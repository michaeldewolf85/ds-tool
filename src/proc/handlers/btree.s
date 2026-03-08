# proc/handlers/btree.s - Handler for the "btree" command

.globl	btree, btree_handler

.equ	BLOCK_SIZE, 56
.section .rodata

.type	btree, @object
btree:
	.ascii	"btree\0"

# TODO: Remove
blockstore:
	.ascii	"blockstore.dat\0"
item1:
	.ascii	"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\0"
item2:
	.ascii	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB\0"
item3:
	.ascii	"CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC\0"
item4:
	.ascii	"DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD\0"
item5:
	.ascii	"EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\0"

.section .bss

this:
	.zero	1<<3

.section .text

# @public	btree_handler
# @description	Handler for the "btree" command
# @param	%rdi	Pointer to user input
# @return	void
.equ	BUFF, -8
.type	btree_handler, @function
btree_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	$BLOCK_SIZE, %rdi
	call	alloc
	mov	%rax, BUFF(%rbp)

	mov	$blockstore, %rdi
	mov	$BLOCK_SIZE, %rsi
	call	BlockStore_ctor
	mov	%rax, this

	mov	$item1, %rsi
	call	BlockStore_place

	mov	$item2, %rsi
	call	BlockStore_place

	mov	$item3, %rsi
	call	BlockStore_place

	mov	$item4, %rsi
	call	BlockStore_place

	mov	$item5, %rsi
	call	BlockStore_place

	mov	$-1, %rsi
	call	BlockStore_read

	mov	$5, %rsi
	mov	BUFF(%rbp), %rdx
	call	BlockStore_read

	mov	$0, %rsi
	call	BlockStore_read

	mov	$-1, %rsi
	mov	$item5, %rdx
	call	BlockStore_write

	mov	$5, %rsi
	mov	$item5, %rdx
	call	BlockStore_write

	mov	$1, %rsi
	mov	$item5, %rdx
	call	BlockStore_write

	mov	$1, %rsi
	mov	BUFF(%rbp), %rdx
	call	BlockStore_read

	mov	$1, %rsi
	call	BlockStore_free

	mov	BUFF(%rbp), %rdx
	call	BlockStore_read

	mov	$item1, %rdx
	call	BlockStore_write

	mov	%rbp, %rsp
	pop	%rbp
	ret
