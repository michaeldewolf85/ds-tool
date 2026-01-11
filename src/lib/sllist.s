# lib/sllist.s - SLList

.include	"common.inc"

.globl	SLList_ctor, SLList_push, SLList_pop, SLList_add, SLList_remove, SLList_log

# SLList struct
	.struct	0
SLList.len:
	.struct	SLList.len + 1<<3
SLList.head:
	.struct	SLList.head + 1<<3
SLList.tail:
	.struct	SLList.tail + 1<<3
	.equ	SLLIST_SIZE, .

# SLListItem struct
	.struct	0
SLListItem.val:
	.struct	SLListItem.val + 1<<3
SLListItem.next:
	.struct	SLListItem.next + 1<<3
	.equ	SLLISTITEM_SIZE, .

.section .rodata

newline:
	.ascii	"\n\0"

start_delim:
	.ascii	"{ \0"

mid_delim:
	.ascii	" -> \0"

end_delim:
	.ascii	" }\n\0"

length_label:
	.ascii	"Length => \0"

raw_label:
	.ascii	"Raw    => \0"

.section .text

# @function	SLList_ctor
# @description	Constructor for an SLList
# @return	%rax	Pointer to the SLList
.type	SLList_ctor, @function
SLList_ctor:
	mov	$SLLIST_SIZE, %rdi
	call	alloc

	movq	$0, SLList.len(%rax)
	movq	$NULL, SLList.head(%rax)
	movq	$NULL, SLList.tail(%rax)

	ret

# @function	SLList_push
# @description	Pushes an element onto the begining (HEAD) of the list
# @param	%rdi	Pointer to the SLList
# @param	%rsi	Pointer to the element to push
# @param	%rax	Pointer to the pushed element
.equ	THIS, -8
.equ	VAL, -16
.type	SLList_push, @function
SLList_push:
	push	%rbp
	mov	%rsp, %rbp

	# Variables
	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, VAL(%rbp)

	# Allocate memory for the new item
	mov	$SLLISTITEM_SIZE, %rdi
	call	alloc

	# Populate the item's data
	mov	THIS(%rbp), %rdi
	mov	VAL(%rbp), %rcx
	mov	%rcx, SLListItem.val(%rax)	# Sets "val" to user input
	mov	SLList.head(%rdi), %rcx
	mov	%rcx, SLListItem.next(%rax)	# Sets "next" to the current list "head"

	# Update the SLList's data
	mov	%rax, SLList.head(%rdi)		# Updates the "head" of the list to the new node
	mov	SLList.tail(%rdi), %rcx		# Default to the current value for the tail but ...
	cmpq	$0, SLList.len(%rdi)		# if this is the first/only item, set the tail ...
	cmove	%rax, %rcx			# to the new node
	mov	%rcx, SLList.tail(%rdi)		# Updates the "tail" of the list (potentially)

	incq	SLList.len(%rdi)		# Increment the length

	mov	VAL(%rbp), %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	SLList_pop
# @description	Remove the beginning (HEAD) element from the list
# @param	%rdi	Pointer to the SLList
# @return	%rax	Pointer to the removed element
.type	SLList_pop, @function
SLList_pop:
	xor	%rax, %rax
	cmpq	$0, SLList.len(%rdi)		# If the list is empty we just return NULL
	je	1f

	mov	SLList.head(%rdi), %rax		# Move the current "head" into the return value
	mov	SLListItem.next(%rax), %rcx	# Retrieve the "next" of the item to be removed ...
	mov	%rcx, SLList.head(%rdi)		# and set the current head to that
	decq	SLList.len(%rdi)		# Decrement list length

	xor	%rcx, %rcx
	cmpq	$0, SLList.len(%rdi)		# If the list just became empty we NULL the tail
	cmovg	SLList.tail(%rdi), %rcx		# Otherwise we just set it to what it was
	mov	%rcx, SLList.tail(%rdi)

	pushq	SLListItem.val(%rax)		# Preserve return value

	# Free the memory
	mov	%rax, %rdi
	call	free

	pop	%rax				# Set return value to preserved
1:
	ret

# @function	SLList_remove
# @description	Remove the beginning (HEAD) element from the list. Effectively an alias for pop
# @param	%rdi	Pointer to the SLList
# @return	%rax	Pointer to the removed element
.type	SLList_remove, @function
SLList_remove:
	call	SLList_pop
	ret

# @function	SLList_add
# @description	Add an element to the end (TAIL) of the list.
# @param	%rdi	Pointer to the SLList
# @param	%rsi	Pointer to the element to add
# @return	%rax	Pointer to the added element
.equ	THIS, -8
.equ	VAL, -16
.type	SLList_add, @function
SLList_add:
	push	%rbp
	mov	%rsp, %rbp

	# Variables
	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, VAL(%rbp)

	mov	$SLLISTITEM_SIZE, %rdi
	call	alloc

	# Populate the item's data
	mov	VAL(%rbp), %rcx
	mov	%rcx, SLListItem.val(%rax)	# Sets "val" to user input
	movq	$NULL, SLListItem.next(%rax)	# Since this is the new tail set "next" to NULL

	mov	THIS(%rbp), %rdi		# Restore "this" pointer

	cmpq	$0, SLList.len(%rdi)
	je	1f

	# Insert the item into the list
	mov	SLList.tail(%rdi), %rcx
	mov	%rax, SLListItem.next(%rcx)	# Update "next" on the existing "tail"

2:
	# Update tail on the list and increment the length
	mov	%rax, SLList.tail(%rdi)
	incq	SLList.len(%rdi)

	# Set return value
	mov	VAL(%rbp), %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# List length is zero
1:
	mov	%rax, SLList.head(%rdi)
	jmp	2b

# @function	SLList_log
# @description	Log the innards of the SLList
# @param	%rdi	Pointer to the SLList
# @return	void
.equ	THIS, -8
.type	SLList_log, @function
SLList_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$newline, %rdi
	call	log

	mov	$length_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	SLList.len(%rdi), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$raw_label, %rdi
	call	log

	mov	$start_delim, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	SLList.head(%rdi), %r8

	# Check if the list is empty
	cmp	$0, %r8
	je	2f

# Print loop
1:
	mov	SLListItem.val(%r8), %rdi
	call	log

	mov	SLListItem.next(%r8), %r8
	cmp	$0, %r8
	je	2f

	mov	$mid_delim, %rdi
	call	log

	jmp	1b

# Print loop done
2:
	mov	$end_delim, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret
