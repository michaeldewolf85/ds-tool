# proc/handlers/dllist.s - Handler for DLList

.include	"common.inc"
.include	"structs.inc"

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

get:
	.ascii	"get\0"
set:
	.ascii	"set\0"
add:
	.ascii	"add\0"
remove:
	.ascii	"remove\0"

commands:
	.quad	get
	.quad	set
	.quad	add
	.quad	remove
	.quad	0	# Sentinel

handlers:
	.quad	DLList_get
	.quad	DLList_set
	.quad	DLList_add
	.quad	DLList_remove

malformed:
	.ascii	"Malformed command\n\0"

start_delim:
	.ascii	"{ \0"

mid_delim:
	.ascii	" <-> \0"

end_delim:
	.ascii	" }\n\0"

newline:
	.ascii	"\n\0"

length_label:
	.ascii	"Length => \0"

raw_label:
	.ascii	"Raw    => \0"

null:
	.ascii	"NULL\0"

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
	mov	Input.argv + 8(%rbx), %rdi	# Second argument is the operation
	xor	%r12, %r12			# Index of found operation

	cmpq	$1, Input.argc(%rbx)		# If only one argument, print the DLList ... 
	je	4f

	cmpq	$3, Input.argc(%rbx)		# Otherwise, we must have 3 arguments to be valid
	jl	error

check:
	mov	commands(, %r12, 8), %rsi
	cmp	$0, %rsi			# Check for the sentinel, if we match here the 
	je	error				# command was not found

	call	strcmp
	cmp	$0, %rax
	je	match

	inc	%r12
	jmp	check

match:
	mov	Input.argv + 16(%rbx), %rdi	# Third argument is always an index
	call	atoi
	cmp	$0, %rax
	jl	error

	mov	%rax, %rsi
	mov	Input.argv + 24(%rbx), %rdx	# Third argument may be a string pointer

	mov	this, %rdi			# Ensure instance is in place
	call	*handlers(, %r12, 8)		# Call the handler

	mov	$null, %r12
	mov	%rax, %rdi
	cmp	$0, %rax
	cmove	%r12, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$newline, %rdi
	call	log

4:
	mov	this, %rdi
	call	DLList_log

5:
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp 5b

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
	# Validates the passed index
	cmp	%rsi, DLList.len(%rdi)
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	call	get_node
	mov	DLListItem.val(%rax), %rax
	ret
# Error index
1:
	xor	%rax, %rax
	ret

# @function	DLList_set
# @description	Set the element at the specified index
# @param	%rdi	Pointer to the DLList
# @param	%rsi	The index to set
# @param	%rdx	Pointer to the value to set
# @return	%rax	Pointer to the previous value
.equ	VAL, -8
DLList_set:
	# Validates the passed index
	cmp	%rsi, DLList.len(%rdi)
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	push	%rdx				# Preserve new value

	call	get_node
	pop	%rdx				# Retrieve new value
	pushq	DLListItem.val(%rax)		# Preserve return value

	# Apply the update
	mov	%rdx, DLListItem.val(%rax)

	pop	%rax
	ret
# Error index
1:
	xor	%rax, %rax
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
	# Validates the passed index
	cmp	%rsi, DLList.len(%rdi)
	jc	1f				# If there's carry it's either too big or negative

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
# Error index
1:
	xor	%rax, %rax
	ret

# @function	DLList_remove
# @description	Remove the element at the specified index
# @param	%rdi	Pointer to the DLList
# @param	%rsi	Index to remove
# @return	%rax	Pointer to the removed element
DLList_remove:
	# Validates the passed index
	cmp	%rsi, DLList.len(%rdi)
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	push	%rdi				# Preserve "this" pointer

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
	pop	%rdi
	ret
# Error index
1:
	xor	%rax, %rax
	ret

# @function	DLList_log
# @description	Logs the innards of a DLList
# @param	%rdi	Pointer to the DLList
# @return	void
.equ	THIS, -8
.equ	LEN, -16
.equ	CUR, -24
DLList_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	DLList.len(%rdi), %rax
	mov	%rax, LEN(%rbp)
	mov	DLList.head(%rdi), %rax
	mov	%rax, CUR(%rbp)

	mov	$length_label, %rdi
	call	log

	mov	LEN(%rbp), %rdi
	call	itoa

	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$raw_label, %rdi
	call	log

	mov	$start_delim, %rdi
	call	log

	cmpq	$0, LEN(%rbp)
	je	2f

1:
	mov	CUR(%rbp), %rax
	mov	DLListItem.next(%rax), %rax
	mov	%rax, CUR(%rbp)

	mov	DLListItem.val(%rax), %rdi
	call	log

	decq	LEN(%rbp)
	cmpq	$0, LEN(%rbp)
	je	2f

	mov	$mid_delim, %rdi
	call	log
	jmp	1b

2:
	mov	$end_delim, %rdi
	call	log

	mov	THIS(%rbp), %rdi

	mov	%rbp, %rsp
	pop	%rbp
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
