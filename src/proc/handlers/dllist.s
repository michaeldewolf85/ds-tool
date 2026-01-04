# proc/handlers/dllist.s - Handler for DLList

.include	"common.inc"

.globl	dllist, dllist_handler

# DLList
	.struct	0
DLList.len:
	.struct	DLList.len + 1<<3
DLList.head:
	.struct	DLList.head + 1<<3
	.equ	DLLIST_SIZE, .

# DLListItem
	.struct	0
DLListItem.val:
	.struct	DLListItem.val + 1<<3
DLListItem.next:
	.struct	DLListItem.next + 1<<3
DLListItem.prev:
	.struct	DLListItem.prev + 1<<3
	.equ	DLLISTITEM_SIZE, .

.section .rodata

.type	dllist, @object
dllist:
	.ascii	"dllist\0"

# TODO REMOVE!!
item1:
	.ascii	"Apples\0"
item2:
	.ascii	"Oranges\0"
item3:
	.ascii	"Bananas\0"
item4:
	.ascii	"Strawberries\0"
item5:
	.ascii	"Blueberries\0"
item6:
	.ascii	"Melons\0"
item7:
	.ascii	"Blackberries\0"
item8:
	.ascii	"Clementines\0"

.section .bss

this:
	.zero	1<<3

.section .text

# @function	dllist_handler
# @description	Handler for the "dllist" command
# @param	%rdi	Pointer to the Input struct
# @return	void
.type	dllist_handler, @function
dllist_handler:
	cmpq	$0, this
	je	new

handler:
	mov	this, %rdi

	mov	$0, %rsi
	mov	$item1, %rdx
	call	DLList_add

	mov	$1, %rsi
	mov	$item2, %rdx
	call	DLList_add

	mov	$2, %rsi
	mov	$item3, %rdx
	call	DLList_add

	mov	$0, %rsi
	mov	$item4, %rdx
	call	DLList_add

	mov	$0, %rsi
	call	DLList_get

	mov	$1, %rsi
	call	DLList_get

	mov	$2, %rsi
	call	DLList_get

	mov	$3, %rsi
	call	DLList_get

	mov	$0, %rsi
	mov	$item2, %rdx
	call	DLList_set

	mov	$0, %rsi
	call	DLList_get

	mov	$0, %rsi
	call	DLList_remove

	ret

# Intialization
new:
	call	DLList_ctor
	mov	%rax, this
	jmp	handler

# @function	DLList_ctor
# @description	Constructor for a DLList
# @return	%rax	Pointer to the new DLList
.equ	THIS, -8
DLList_ctor:
	push	%rbp
	mov	%rsp, %rbp

	# Allocate the list
	mov	$DLLIST_SIZE, %rdi
	call	alloc
	push	%rax

	# Allocate the sentinel (head) of the list
	mov	$DLLISTITEM_SIZE, %rdi
	call	alloc

	# Set the next/prev pointers on the sentinel (to itself)
	movq	$NULL, DLListItem.val(%rax)
	mov	%rax, DLListItem.next(%rax)
	mov	%rax, DLListItem.prev(%rax)
	mov	%rax, %rcx

	# Set the length and head properties on the list itself
	pop	%rax
	movq	$0, DLList.len(%rax)
	mov	%rcx, DLList.head(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	DLList_get
# @description	Get the element at the specified index
# @param	%rdi	Pointer to the DLList
# @param	%rsi	The index to get
# @return	%rax	Pointer to the element
DLList_get:
	call	get_node
	mov	DLListItem.val(%rax), %rax
	ret

# @function	DLList_set
# @description	Set the element at the specified index
# @param	%rdi	Pointer to the DLList
# @param	%rsi	The index to set
# @param	%rdx	Pointer to the value to set
# @return	%rax	Pointer to the previous value
.equ	VAL, -8
DLList_set:
	push	%rdx				# Preserve new value

	call	get_node
	pop	%rdx				# Retrieve new value
	pushq	DLListItem.val(%rax)		# Preserve return value

	# Apply the update
	mov	%rdx, DLListItem.val(%rax)

	pop	%rax
	ret

# @function	DLList_add
# @description	Adds an element at the specified index
# @param	%rdi	Pointer to the DLList
# @param	%rsi	Index to add at
# @param	%rdx	Pointer to the element to add
# @return	%rax	Pointer to the added element
.equ	THIS, -8
.equ	IDX, -16
.equ	VAL, -24
.equ	AFTER, -32	# Adjacent node
DLList_add:
	push	%rbp
	mov	%rsp, %rbp

	# Variables
	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, IDX(%rbp)
	mov	%rdx, VAL(%rbp)
	call	get_node
	mov	%rax, AFTER(%rbp)

	# Create the new item
	mov	$DLLISTITEM_SIZE, %rdi
	call	alloc

	mov	VAL(%rbp), %rcx
	mov	%rcx, DLListItem.val(%rax)	# Set val

	# Insert into the list
	mov	AFTER(%rbp), %rcx		# Next node
	mov	DLListItem.prev(%rcx), %rdx	# Previous node
	mov	%rcx, DLListItem.next(%rax)	# New node next
	mov	%rdx, DLListItem.prev(%rax)	# New node prev
	mov	%rax, DLListItem.prev(%rcx)	# Next node prev
	mov	%rax, DLListItem.next(%rdx)	# Prev node next

	# Increment length
	mov	THIS(%rbp), %rdi
	incq	DLList.len(%rdi)

	mov	VAL(%rbp), %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	DLList_remove
# @description	Remove the element at the specified index
# @param	%rdi	Pointer to the DLList
# @param	%rsi	Index to remove
# @return	%rax	Pointer to the removed element
DLList_remove:
	call	get_node

	# Get next/prev of removed node
	mov	DLListItem.next(%rax), %rcx
	mov	DLListItem.prev(%rax), %rdx

	# "Extract" it from the list
	mov	%rcx, DLListItem.next(%rdx)
	mov	%rdx, DLListItem.prev(%rcx)

	# Decrement the length
	decq	DLList.len(%rdi)

	# Preserve return value
	pushq	DLListItem.val(%rax)

	# Free the memory
	mov	%rax, %rdi
	call	free

	pop	%rax
	ret

# @function	get_node
# @description	File private helper to get a node by index
# @param	%rdi	Pointer to the DLList
# @param	%rsi	Index of the node
# @return	%rax	Pointer to the node
get_node:
	# Check if the requested index is in the first half and thus we should traverse forward
	mov	DLList.len(%rdi), %rax
	mov	$2, %rcx
	xor	%rdx, %rdx
	div	%rcx

	cmp	%rax, %rsi
	jge	2f				# Jump if backward traversal

	mov	DLList.head(%rdi), %rax		# Stage list head for traversal
	mov	DLListItem.next(%rax), %rax	

# Forward traversal
1:
	cmp	$0, %rsi
	je	4f

	mov	DLListItem.next(%rax), %rax
	dec	%rsi
	jmp	1b

# Backward traversal
2:
	mov	DLList.head(%rdi), %rax		# Stage list head for traversal
	mov	DLList.len(%rdi), %rcx
	sub	%rsi, %rcx
3:
	cmp	$0, %rcx
	je	4f

	mov	DLListItem.prev(%rax), %rax
	dec	%rcx
	jmp	3b

4:
	ret
