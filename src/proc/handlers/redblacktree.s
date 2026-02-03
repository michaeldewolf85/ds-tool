# proc/handlers/redblacktree.s - Handler for the "redblacktree" command

.include	"common.inc"

.globl	redblacktree, redblacktree_handler

.section .rodata

.type	redblacktree, @object
redblacktree:
	.ascii	"redblacktree\0"

# TODO REMOVE!!
item1:
	.ascii	"Portland\0"
item2:
	.ascii	"Lewiston\0"
item3:
	.ascii	"Bangor\0"
item4:
	.ascii	"South Portland\0"
item5:
	.ascii	"Auburn\0"
item6:
	.ascii	"Biddeford\0"
item7:
	.ascii	"Scarborough\0"
item8:
	.ascii	"Sanford\0"
item9:
	.ascii	"Brunswick\0"
item10:
	.ascii	"Westbrook\0"
item11:
	.ascii	"Saco\0"
item12:
	.ascii	"Augusta\0"
item13:
	.ascii	"Windham\0"
item14:
	.ascii	"Gorham\0"
item15:
	.ascii	"Waterville\0"
item16:
	.ascii	"York\0"
item17:
	.ascii	"Falmouth\0"
item18:
	.ascii	"Kennebunk\0"
item19:
	.ascii	"Wells\0"
item20:
	.ascii	"Orono\0"
item21:
	.ascii	"Standish\0"
item22:
	.ascii	"Kittery\0"
item23:
	.ascii	"Lisbon\0"
item24:
	.ascii	"Brewer\0"

.section .bss

this:
	.zero	1<<3

.section .text

# @function	redblacktree_handler
# @description	Handler for the "redblacktree" command
# @param	%rdi	Command line input args
# @return	void
.type	redblacktree_handler, @function
redblacktree_handler:
	push	%rbp
	mov	%rsp, %rbp

	cmpq	$NULL, this
	jne	1f

	call	RedBlackTree_ctor
	mov	%rax, this

1:
	mov	this, %rdi

	mov	$item1, %rsi
	call	RedBlackTree_add

	mov	$item2, %rsi
	call	RedBlackTree_add

	mov	$item3, %rsi
	call	RedBlackTree_add

	mov	$item4, %rsi
	call	RedBlackTree_add

	call	RedBlackTree_log

	mov	$item5, %rsi
	call	RedBlackTree_add

	mov	$item6, %rsi
	call	RedBlackTree_add

	mov	$item7, %rsi
	call	RedBlackTree_add

	mov	$item8, %rsi
	call	RedBlackTree_add

	call	RedBlackTree_log

	mov	$item9, %rsi
	call	RedBlackTree_add

	mov	$item10, %rsi
	call	RedBlackTree_add

	mov	$item11, %rsi
	call	RedBlackTree_add

	mov	$item12, %rsi
	call	RedBlackTree_add

	mov	$item13, %rsi
	call	RedBlackTree_add

	mov	$item14, %rsi
	call	RedBlackTree_add

	mov	$item15, %rsi
	call	RedBlackTree_add

	mov	$item16, %rsi
	call	RedBlackTree_add

	mov	$item17, %rsi
	call	RedBlackTree_add

	mov	$item18, %rsi
	call	RedBlackTree_add

	mov	$item19, %rsi
	call	RedBlackTree_add

	mov	$item20, %rsi
	call	RedBlackTree_add

	mov	$item21, %rsi
	call	RedBlackTree_add

	mov	$item22, %rsi
	call	RedBlackTree_add

	mov	$item23, %rsi
	call	RedBlackTree_add

	mov	$item24, %rsi
	call	RedBlackTree_add

	call	RedBlackTree_log

	call	print

	#mov	$item1, %rsi
	#call	RedBlackTree_remove

	#mov	$item6, %rsi
	#call	RedBlackTree_remove

	#mov	$item12, %rsi
	#call	RedBlackTree_remove

	#mov	$item18, %rsi
	#call	RedBlackTree_remove

	#mov	$item24, %rsi
	#call	RedBlackTree_remove

	mov	%rbp, %rsp
	pop	%rbp
	ret
