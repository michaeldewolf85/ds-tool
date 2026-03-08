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

filename:
	.ascii	"btree.dat\0"

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
item25:
	.ascii	"Topsham\0"
item26:
	.ascii	"Cape Elizabeth\0"
item27:
	.ascii	"Yarmouth\0"
item28:
	.ascii	"Old Orchard Beach\0"
item29:
	.ascii	"Presque Isle\0"
item30:
	.ascii	"Bath\0"
item31:
	.ascii	"Freeport\0"
item32:
	.ascii	"Skowhegan\0"
item33:
	.ascii	"Cumberland\0"
item34:
	.ascii	"Ellsworth\0"
item35:
	.ascii	"Buxton\0"
item36:
	.ascii	"Gray\0"
item37:
	.ascii	"Berwick\0"
item38:
	.ascii	"Winslow\0"
item39:
	.ascii	"Waterboro\0"
item40:
	.ascii	"Hampden\0"
item41:
	.ascii	"Farmington\0"
item42:
	.ascii	"South Berwick\0"
item43:
	.ascii	"Old Town\0"
item44:
	.ascii	"Caribou\0"
item45:
	.ascii	"Belfast\0"
item46:
	.ascii	"Rockland\0"
item47:
	.ascii	"Eliot\0"
item48:
	.ascii	"Fairfield\0"

.section .bss

this:
	.zero	1<<3

.section .text

# @public	btree_handler
# @description	Handler for the "btree" command
# @param	%rdi	Pointer to user input
# @return	void
.equ	RESB, -64
.type	btree_handler, @function
btree_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$64, %rsp

	mov	$filename, %rdi
	call	BTree_ctor
	mov	%rax, this

	mov	this, %rdi

	mov	$item1, %rsi
	call	BTree_add

	mov	$item2, %rsi
	call	BTree_add

	mov	$item3, %rsi
	call	BTree_add

	mov	$item4, %rsi
	call	BTree_add

	mov	$item5, %rsi
	call	BTree_add

	mov	$item6, %rsi
	call	BTree_add

	mov	$item7, %rsi
	call	BTree_add

	mov	$item8, %rsi
	call	BTree_add

	mov	$item9, %rsi
	call	BTree_add

	mov	$item10, %rsi
	call	BTree_add

	mov	%rsp, %rdx
	call	BTree_find

	mov	$item11, %rsi
	call	BTree_add

	mov	$item12, %rsi
	call	BTree_add

	mov	$item13, %rsi
	call	BTree_add

	mov	$item14, %rsi
	call	BTree_add

	mov	$item15, %rsi
	call	BTree_add

	mov	$item16, %rsi
	call	BTree_add

	mov	$item17, %rsi
	call	BTree_add

	mov	$item18, %rsi
	call	BTree_add

	mov	$item19, %rsi
	call	BTree_add

	mov	$item20, %rsi
	call	BTree_add

	mov	$item21, %rsi
	call	BTree_add

	mov	$item22, %rsi
	call	BTree_add

	mov	$item23, %rsi
	call	BTree_add

	mov	$item24, %rsi
	call	BTree_add

	mov	$item25, %rsi
	call	BTree_add

	mov	$item26, %rsi
	call	BTree_add

	mov	$item27, %rsi
	call	BTree_add

	mov	$item28, %rsi
	call	BTree_add

	mov	$item29, %rsi
	call	BTree_add

	mov	$item30, %rsi
	call	BTree_add

	mov	$item31, %rsi
	call	BTree_add

	mov	$item32, %rsi
	call	BTree_add

	mov	$item33, %rsi
	call	BTree_add

	mov	$item34, %rsi
	call	BTree_add

	mov	$item35, %rsi
	call	BTree_add

	mov	$item36, %rsi
	call	BTree_add

	mov	$item37, %rsi
	call	BTree_add

	mov	$item38, %rsi
	call	BTree_add

	mov	$item39, %rsi
	call	BTree_add

	mov	$item40, %rsi
	call	BTree_add

	mov	$item41, %rsi
	call	BTree_add

	mov	$item42, %rsi
	call	BTree_add

	mov	$item43, %rsi
	call	BTree_add

	mov	$item44, %rsi
	call	BTree_add

	mov	$item45, %rsi
	call	BTree_add

	mov	$item46, %rsi
	call	BTree_add

	mov	$item47, %rsi
	call	BTree_add

	mov	$item48, %rsi
	call	BTree_add

	mov	$item13, %rsi
	lea	RESB(%rbp), %rdx
	call	BTree_find

	mov	$item1, %rsi
	call	BTree_find

	mov	$item2, %rsi
	call	BTree_find

	mov	$item3, %rsi
	call	BTree_find

	mov	$item4, %rsi
	call	BTree_find

	mov	$item5, %rsi
	call	BTree_find

	mov	$item6, %rsi
	call	BTree_find

	mov	$item7, %rsi
	call	BTree_find

	mov	$item8, %rsi
	call	BTree_find

	mov	$item9, %rsi
	call	BTree_find

	mov	$item10, %rsi
	call	BTree_find

	mov	$item11, %rsi
	call	BTree_find

	mov	$item12, %rsi
	call	BTree_find

	call	BTree_log
	call	print
	# BTreeNode!!
	#call	BTreeNode_ctor
	#mov	%rax, %rdi

	#mov	$item1, %rsi
	#mov	$2, %rdx
	#call	BTreeNode_add

	#mov	$item3, %rsi
	#mov	$4, %rdx
	#call	BTreeNode_add

	#mov	$item2, %rsi
	#mov	$5, %rdx
	#call	BTreeNode_add

	#mov	$item4, %rsi
	#mov	$1, %rdx
	#call	BTreeNode_add

	#mov	$item5, %rsi
	#mov	$7, %rdx
	#call	BTreeNode_add

	#mov	$item6, %rsi
	#mov	$0, %rdx
	#call	BTreeNode_add

	#call	BTreeNode_split

	#mov	%rax, %rsi
	#call	BTreeNode_merge

	mov	%rbp, %rsp
	pop	%rbp
	ret
