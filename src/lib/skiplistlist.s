# lib/skiplistlist.s - SkiplistList

.include	"common.inc"

.globl	SkiplistList_ctor, SkiplistList_get, SkiplistList_set, SkiplistList_add
.globl	SkiplistList_remove, SkiplistList_log

# SkiplistList
	.struct	0
SkiplistList.head:
	.struct	SkiplistList.head + 1<<3
SkiplistList.height:
	.struct	SkiplistList.height + 1<<3
SkiplistList.size:
	.struct	SkiplistList.size + 1<<3
	.equ	SKIPLISTLIST_SIZE, .

# SkiplistListItem
	.struct	0
SkiplistListItem.data:
	.struct	SkiplistListItem.data + 1<<3
SkiplistListItem.next:
	.struct	SkiplistListItem.next + 1<<3
SkiplistListItem.edge:
	.struct	SkiplistListItem.edge + 1<<3
SkiplistListItem.height:
	.struct	SkiplistListItem.height + 1<<3
	.equ	SKIPLISTLISTITEM_SIZE, .

.equ	MAX_HEIGHT, 1<<5			# Max height is 32

.section .rodata

lfeed:
	.byte	LF, NULL
comma:
	.ascii	",\n\0"
sdelim:
	.ascii	"[ \0"
mdelim:
	.ascii	", \0"
edelim:
	.ascii	" ]\n\0"
hlabel:
	.ascii	"Height => \0"
slabel:
	.ascii	"Size   => \0"
rlabel:
	.ascii	"Raw    => \0"
alabel:
	.ascii	" => \0"
rsdelim:
	.ascii	"{\0"
rmdelim:
	.ascii	" -> \0"
redelim:
	.ascii	"}\0"
spacer:
	.ascii	"  \0"
null:
	.ascii	"NULL\0"
sedgedelim:
	.ascii	" (\0"
eedgedelim:
	.ascii	")\0"

.section .text

# @function	SkiplistList_ctor
# @description	Constructor for a SkiplistList
# @return	%rax	Pointer to the new SkiplistList
.equ	THIS, -8
.equ	HEAD, -16
.type	SkiplistList_ctor, @function
SkiplistList_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp

	# Allocate for the list itself
	mov	$SKIPLISTLIST_SIZE, %rdi
	call	alloc
	mov	%rax, THIS(%rbp)

	# Allocate head
	mov	$NULL, %rdi
	mov	$MAX_HEIGHT - 1, %rsi
	call	add_node
	mov	%rax, HEAD(%rbp)

	# Assign head
	mov	THIS(%rbp), %rax
	mov	HEAD(%rbp), %rcx
	mov	%rcx, SkiplistList.head(%rax)
	movq	$0, SkiplistList.height(%rax)
	movq	$0, SkiplistList.size(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	SkiplistList_get
# @description	Get the element at the specified index
# @param	%rdi	Pointer to the SkiplistList
# @param	%rsi	Index to get
# @return	%rax	Pointer to the element
.type	SkiplistList_get, @function
SkiplistList_get:
	# Validates the passed index
	cmp	%rsi, SkiplistList.size(%rdi)
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	call	find_pred
	mov	SkiplistListItem.next(%rax), %rax
	mov	(%rax), %rax
	mov	SkiplistListItem.data(%rax), %rax
	ret
1:
	xor	%rax, %rax
	ret

# @function	SkiplistList_set
# @description	Set the element at the specified index
# @param	%rdi	Pointer to the SkiplistList
# @param	%rsi	Index to set
# @param	%rdx	Element to set as the value
# @return	%rax	Pointer to the previous element
.type	SkiplistList_set, @function
SkiplistList_set:
	# Validates the passed index
	cmp	%rsi, SkiplistList.size(%rdi)
	jc	1f				# If there's carry it's either too big or negative
	jz	1f				# Also need to check for equals

	mov	%rdx, %r10
	call	find_pred

	mov	SkiplistListItem.next(%rax), %rax
	mov	(%rax), %rcx
	mov	SkiplistListItem.data(%rcx), %rax
	mov	%r10, SkiplistListItem.data(%rcx)
	ret
1:
	xor	%rax, %rax
	ret


# @function	SkiplistList_add
# @description	Adds an element to the SkiplistList at the specified index
# @param	%rdi	Pointer to the SkiplistList
# @param	%rsi	Index to add at
# @param	%rdx	Element to add
# @return	%rax	The added element or NULL on failure
.equ	THIS, -8
.equ	IDX, -16
.equ	VAL, -24
.equ	NEW, -32
.equ	NXT, -40
.type	SkiplistList_add, @function
SkiplistList_add:
	# Validates the passed index
	cmp	%rsi, SkiplistList.size(%rdi)
	jnc	1f				# If there's carry it's either too big or negative

	xor	%rax, %rax
	ret

1:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, IDX(%rbp)
	mov	%rdx, VAL(%rbp)

	# Generate the new node
	call	random_height
	mov	VAL(%rbp), %rdi
	mov	%rax, %rsi
	call	add_node
	mov	%rax, NEW(%rbp)

	mov	THIS(%rbp), %rdi
	mov	SkiplistListItem.height(%rax), %rax
	cmp	SkiplistList.height(%rdi), %rax
	jle	1f

	# Update the height of the list if it is less than the new item
	mov	%rax, SkiplistList.height(%rdi)

1:
	mov	SkiplistList.head(%rdi), %rax	# Current node, starts at "head"
	mov	SkiplistList.height(%rdi), %rcx	# Outer loop counter, starts at height of list
	movq	$-1, %r9			# Index counter
	jmp	6f

2:
	# Inner loop body, finds the preceding node at this level
	mov	%rsi, %r9			# Update counter to include the accumulated edge
	mov	NXT(%rbp), %rax			# Make next current

3:
	# Inner loop condition
	mov	SkiplistListItem.next(%rax), %rdx
	mov	(%rdx, %rcx, 1<<3), %rdx
	mov	%rdx, NXT(%rbp)
	cmp	$NULL, %rdx
	je	4f

	mov	SkiplistListItem.edge(%rax), %rsi
	mov	(%rsi, %rcx, 1<<3), %rsi
	# Add the edge at this level to see if we would overflow the target index, if we don't this
	# node precedes the node we are adding
	add	%r9, %rsi
	cmpq	IDX(%rbp), %rsi
	jl	2b

4:
	# Outer loop body, when we are here we found the preceding node at the current level being
	# processed, thus we need to increase the length of that edge
	mov	SkiplistListItem.edge(%rax), %rdx
	incq	(%rdx, %rcx, 1<<3)

	# Check if the new node's height reaches this level and if so, insert it into the list
	mov	NEW(%rbp), %rdx
	cmp	SkiplistListItem.height(%rdx), %rcx
	jg	5f

	mov	NXT(%rbp), %rsi
	# Insert next pointers, new node is in %rdx, height counter is in %rcx, next node is %rsi
	mov	SkiplistListItem.next(%rdx), %rdi
	mov	%rsi, (%rdi, %rcx, 1<<3)
	mov	SkiplistListItem.next(%rax), %rdi
	mov	%rdx, (%rdi, %rcx, 1<<3)

	# Update edges, new node is in %rdx, height is in %rcx, current node is in %rax
	# Calculates edge length of new node at this level
	# First we need requested index minus our counter (i - j)
	mov	IDX(%rbp), %rsi
	sub	%r9, %rsi

	# Calculate edge of new node at this level
	mov	SkiplistListItem.edge(%rax), %rdi
	mov	(%rdi, %rcx, 1<<3), %rdi
	sub	%rsi, %rdi

	# Assign edge to new node at this level
	mov	SkiplistListItem.edge(%rdx), %r8
	mov	%rdi, (%r8, %rcx, 1<<3)

	# Assign edge to current node at this level
	mov	SkiplistListItem.edge(%rax), %rdi
	mov	%rsi, (%rdi, %rcx, 1<<3)

5:
	dec	%rcx

6:
	# Outer loop condition
	cmpq	$0, %rcx
	jge	3b

	mov	THIS(%rbp), %rdi

	incq	SkiplistList.size(%rdi)
	mov	VAL(%rbp), %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	SkiplistList_remove
# @description	Remove the element at the specified index
# @param	%rdi	Pointer to the SkiplistList
# @param	%rsi	Index of the element to remove
# @return	%rax	Pointer to the removed element
.type	SkiplistList_remove, @function
SkiplistList_remove:
	# Validates the passed index
	cmp	%rsi, SkiplistList.size(%rdi)
	jc	6f				# If there's carry it's either too big or negative
	jz	6f				# Also need to check for equals

	mov	SkiplistList.head(%rdi), %rax
	mov	SkiplistList.height(%rdi), %rcx
	mov	$-1, %rdx
	jmp	5f

1:
	# Inner loop body, we can still move right so move right one place
	mov	%r8, %rax			# Move next pointer to be current pointer
	mov	%r9, %rdx			# Update current index in bottom row

2:
	# Inner loop condition, moving to the right to find preceding node at this level
	# Check if next pointer at this level is NULL, which indicates the end of the row
	mov	SkiplistListItem.next(%rax), %r8
	mov	(%r8, %rcx, 1<<3), %r8
	cmp	$NULL, %r8
	je	3f

	# Check if current position in bottom row plus edge length of next overshoots the item
	mov	SkiplistListItem.edge(%rax), %r9
	mov	(%r9, %rcx, 1<<3), %r9
	add	%rdx, %r9
	cmp	%rsi, %r9
	jl	1b

3:
	# Outer loop body, we've found the preceding node at this level and need to update it
	# Decrement the edge length by one since we are removing one
	mov	SkiplistListItem.edge(%rax), %r9
	decq	(%r9, %rcx, 1<<3)

	# Check for current element for the one we want to remove
	mov	(%r9, %rcx, 1<<3), %r9			# Get edge length to next
	inc	%r9					# Increment it by one
	add	%rdx, %r9				# Add our current position
	cmp	%r9, %rsi
	jne	4f

	# Ensure next is not null which means we still need to go down a level
	cmp	$NULL, %r8
	je	4f

	# We are at the node preceding the element we want to remove, node we want to remove in %r8
	# Sum the edge length of next and the edge length of current and set as length of current
	mov	SkiplistListItem.edge(%rax), %r9
	mov	(%r9, %rcx, 1<<3), %r10
	mov	SkiplistListItem.edge(%r8), %r11
	add	(%r11, %rcx, 1<<3), %r10
	mov	%r10, (%r9, %rcx, 1<<3)

	# Get next of next and apply it as length of current
	mov	SkiplistListItem.next(%r8), %r9
	mov	(%r9, %rcx, 1<<3), %r9
	mov	SkiplistListItem.next(%rax), %r10
	mov	%r9, (%r10, %rcx, 1<<3)

	# Check if the current node is the head
	cmp	SkiplistList.head(%rdi), %rax
	jne	4f

	# Check if the update made next of current null
	cmpq	$NULL, (%r10, %rcx, 1<<3)
	jne	4f

	decq	SkiplistList.height(%rdi)

4:
	dec	%rcx

5:
	# Outer loop condition, moving down the height from top to bottom ...
	cmp	$0, %rcx
	jge	2b

	decq	SkiplistList.size(%rdi)

	# Node to remove is in %r8 and we are done, first preserve the return value and "this"
	mov	SkiplistListItem.data(%r8), %rax
	push	%rax
	push	%rdi

	# Free the node
	mov	%r8, %rdi
	call	free

	# Set the return and exit
	pop	%rdi
	pop	%rax
	ret
6:
	xor	%rax, %rax
	ret

# @function	SkiplistList_log
# @description	Log the innards of a SkiplistList
# @param	%rdi	Pointer to a SkiplistList
# @return	void
.equ	THIS, -8
.equ	CURR, -16
.equ	NEXT, -24
.equ	CTR, -32
.equ	C1, -40
.equ	N1, -48
.type	SkiplistList_log, @function
SkiplistList_log:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$48, %rsp
	mov	%rdi, THIS(%rbp)
	mov	SkiplistList.head(%rdi), %rax
	mov	%rax, CURR(%rbp)
	mov	SkiplistListItem.next(%rax), %rax
	mov	(%rax), %rax
	mov	%rax, NEXT(%rbp)

	mov	$sdelim, %rdi
	call	log
	jmp	2f

1:
	mov	NEXT(%rbp), %rax
	mov	SkiplistListItem.data(%rax), %rdi
	call	log

	mov	NEXT(%rbp), %rax
	mov	SkiplistListItem.next(%rax), %rax
	mov	(%rax), %rax
	mov	%rax, NEXT(%rbp)
	cmp	$NULL, %rax
	je	2f

	mov	$mdelim, %rdi
	call	log

	mov	NEXT(%rbp), %rax
2:
	cmpq	$NULL, NEXT(%rbp)
	jne	1b

	mov	$edelim, %rdi
	call	log

	mov	$lfeed, %rdi
	call	log

	mov	$slabel, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	SkiplistList.size(%rdi), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$lfeed, %rdi
	call	log

	mov	$hlabel, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	SkiplistList.height(%rdi), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$lfeed, %rdi
	call	log

	mov	$rlabel, %rdi
	call	log

	mov	$rsdelim, %rdi
	call	log

	mov	$lfeed, %rdi
	call	log

	# Raw view goes here ....
	mov	THIS(%rbp), %rdi
	mov	SkiplistList.head(%rdi), %rax
	mov	%rax, CURR(%rbp)
	jmp	4f

3:
	mov	$spacer, %rdi
	call	log

	mov	NEXT(%rbp), %rax
	mov	SkiplistListItem.data(%rax), %rdi
	call	log

	mov	$alabel, %rdi
	call	log

	mov	$rsdelim, %rdi
	call	log

	# Heights go here:
	mov	NEXT(%rbp), %rcx
	mov	SkiplistListItem.height(%rcx), %rcx
	mov	%rcx, CTR(%rbp)
	jmp	6f

5:
	mov	$lfeed, %rdi
	call	log
	
	mov	$spacer, %rdi
	call	log

	mov	$spacer, %rdi
	call	log

	mov	CTR(%rbp), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$alabel, %rdi
	call	log

	mov	$rsdelim, %rdi
	call	log

	mov	$spacer, %rdi
	call	log

	mov	%rax, N1(%rbp)
	# Loop elements in chain
	mov	NEXT(%rbp), %rax
	mov	CTR(%rbp), %rcx
	mov	%rax, C1(%rbp)
	jmp	8f
7:
	mov	SkiplistListItem.data(%rax), %rdi
	call	log

	# Print "edge"
	mov	$sedgedelim, %rdi
	call	log

	mov	NEXT(%rbp), %rax
	mov	CTR(%rbp), %rcx
	mov	SkiplistListItem.edge(%rax), %rdi
	mov	(%rdi, %rcx, 1<<3), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$eedgedelim, %rdi
	call	log

	mov	$rmdelim, %rdi
	call	log

	mov	N1(%rbp), %rax
	mov	%rax, C1(%rbp)
8:
	mov	C1(%rbp), %rax
	mov	CTR(%rbp), %rcx
	mov	SkiplistListItem.next(%rax), %rax
	mov	(%rax, %rcx, 1<<3), %rax
	mov	%rax, N1(%rbp)
	cmp	$NULL, %rax
	jne	7b

	mov	$null, %rdi
	call	log

	mov	$spacer, %rdi
	call	log
	mov	$redelim, %rdi
	call	log

	decq	CTR(%rbp)
6:
	cmpq	$0, CTR(%rbp)
	jge	5b

	mov	$lfeed, %rdi
	call	log

	mov	$spacer, %rdi
	call	log

	mov	$redelim, %rdi
	call	log

	mov	$comma, %rdi
	call	log

	mov	NEXT(%rbp), %rax
	mov	%rax, CURR(%rbp)

4:
	mov	CURR(%rbp), %rax
	mov	SkiplistListItem.next(%rax), %rax
	mov	(%rax), %rax
	mov	%rax, NEXT(%rbp)
	cmp	$NULL, %rax
	jne	3b

	mov	$redelim, %rdi
	call	log

	mov	$lfeed, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	add_node
# @description	File private function to add a new node
# @param	%rdi	Value of the node
# @param	%rsi	Height of the node
# @return	%rax	Pointer to the new node
.equ	VAL, -8
.equ	HGT, -16
.equ	SIZ, -24
.equ	THIS, -32
.equ	NEXT, -40
.equ	EDGE, -48
add_node:
	push	%rbp
	mov	%rsp, %rbp

	sub	$48, %rsp
	mov	%rdi, VAL(%rbp)
	mov	%rsi, HGT(%rbp)
	
	# Calculate + store size of head / edge
	inc	%rsi
	imul	$1<<3, %rsi
	mov	%rsi, SIZ(%rbp)

	# Allocate for the item itself
	mov	$SKIPLISTLISTITEM_SIZE, %rdi
	call	alloc
	mov	%rax, THIS(%rbp)

	# Allocate next
	mov	SIZ(%rbp), %rdi
	call	alloc
	mov	%rax, NEXT(%rbp)

	# Allocate edge
	mov	SIZ(%rbp), %rdi
	call	alloc
	mov	%rax, EDGE(%rbp)

	# Assign all the things ...
	mov	THIS(%rbp), %rax
	mov	VAL(%rbp), %rcx
	mov	%rcx, SkiplistListItem.data(%rax)
	mov	HGT(%rbp), %rcx
	mov	%rcx, SkiplistListItem.height(%rax)
	mov	NEXT(%rbp), %rcx
	mov	%rcx, SkiplistListItem.next(%rax)
	mov	EDGE(%rbp), %rcx
	mov	%rcx, SkiplistListItem.edge(%rax)
	
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	random_height
# @description	File private function to generate a random height
# @return	%rax	A random height
random_height:
	xor	%eax, %eax	# Zero out return value

1:
	rdrand	%ecx
	jnc	1b		# If rdrand fails the carry flag gets unset

	jmp	3f
2:
	inc	%eax
	shr	$1, %ecx
3:
	mov	$1, %edx
	and	%ecx, %edx
	cmp	$0, %edx
	jg	2b

	ret

# @function	find_pred
# @description	File private function to find the preceding node for an index
# @param	%rdi	Pointer to the SkiplistList
# @param	%rsi	Index of the element to find the preceding node for
# @return	%rax	Pointer to the preceding node (SkiplistListItem)
find_pred:
	mov	SkiplistList.head(%rdi), %rax
	mov	SkiplistList.height(%rdi), %rcx
	mov	$-1, %rdx
	jmp	4f

1:
	mov	%r8, %rax
	mov	%r9, %rdx

2:
	mov	SkiplistListItem.next(%rax), %r8
	mov	(%r8, %rcx, 1<<3), %r8
	cmp	$NULL, %r8
	je	3f

	mov	SkiplistListItem.edge(%rax), %r9
	mov	(%r9, %rcx, 1<<3), %r9
	add	%rdx, %r9
	cmp	%rsi, %r9
	jl	1b

3:
	dec	%rcx

4:
	cmp	$0, %rcx
	jge	2b

	ret
