# lib/selist.s - SEList

.include	"common.inc"

.globl	SEList_add, SEList_ctor, SEList_get, SEList_log, SEList_remove, SEList_set

# SEList
	.struct	0
SEList.head:
	.struct	SEList.head + 1<<3
SEList.len:
	.struct	SEList.len + 1<<3
	.equ	SELIST_SIZE, .

# SEListItem
	.struct	0
SEListItem.data:
	.struct	SEListItem.data + 1<<3
SEListItem.next:
	.struct	SEListItem.next + 1<<3
SEListItem.prev:
	.struct	SEListItem.prev + 1<<3
	.equ	SELISTITEM_SIZE, .

.equ	SELIST_BLOCK_SIZE, 3

.section .rodata

lf:
	.byte	LF, NULL

len_label:
	.ascii	"Length => \0"

raw_label:
	.ascii	"Raw    => \0"

spacer:
	.ascii	" \0"

s_delim:
	.ascii	"[ \0"

m_delim:
	.ascii	", \0"

e_delim:
	.ascii	" ]\n\0"

sblock_delim:
	.ascii	"{\n\0" 

mblock_delim:
	.ascii	" <-> \0" 

eblock_delim:
	.ascii	"}\n\0"

.section .text

# @function	SEList_ctor
# @description	Constructor for a SEList
# @return	%rax	Pointer to the new SEList
.equ	HEAD, -8
SEList_ctor:
	push	%rbp
	mov	%rsp, %rbp

	# Allocate for the "head" node
	mov	$SELISTITEM_SIZE, %rdi
	call	alloc

	# Assign "head" node attributes
	movq	$NULL, SEListItem.data(%rax)	# NULL data pointer
	mov	%rax, SEListItem.next(%rax)	# Next pointer to itself
	mov	%rax, SEListItem.prev(%rax)	# Prev pointer to itself

	# Save "head" node as a local variable
	sub	$8, %rsp
	mov	%rax, HEAD(%rbp)

	# Allocate for the SEList
	mov	$SELIST_SIZE, %rdi
	call	alloc

	mov	HEAD(%rbp), %rcx
	mov	%rcx, SEList.head(%rax)
	movq	$0, SEList.len(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	SEList_get
# @description	Get the element at the specified index
# @param	%rdi	Pointer to the SEList
# @param	%rsi	The requested index
# @return	%rax	Pointer to the element
.equ	THIS, -8
SEList_get:
	push	%rbp
	mov	%rsp, %rbp

	# Index checking (not greater than / equal to the length or less than zero)
	cmp	%rsi, SEList.len(%rdi)
	jc	1f
	je	1f

	# Local variables
	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	call	get_location
	mov	SEListItem.data(%rax), %rdi
	mov	%rdx, %rsi
	call	BDeque_get

	mov	THIS(%rbp), %rdi

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret
# Out of bounds
1:
	xor	%rax, %rax
	jmp	2b


# @function	SEList_set
# @description	Set the element at the specified index
# @param	%rdi	Pointer to the SEList
# @param	%rsi	The index to set
# @param	%rdx	The value to set
# @return	%rax	Pointer to the previous value
.equ	THIS, -8
.equ	VAL, -16
SEList_set:
	push	%rbp
	mov	%rsp, %rbp

	# Index checking (not greater than / equal to the length or less than zero)
	cmp	%rsi, SEList.len(%rdi)
	jc	1f
	je	1f

	# Local variables
	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rdx, VAL(%rbp)

	call	get_location
	mov	SEListItem.data(%rax), %rdi
	mov	%rdx, %rsi
	mov	VAL(%rbp), %rdx
	call	BDeque_set

	mov	THIS(%rbp), %rdi

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret
# Out of bounds
1:
	xor	%rax, %rax
	jmp	2b

# @function	SEList_add
# @description	Insert an element at the specified key. Existing values will shift right
# @param	%rdi	Pointer to the SEList
# @param	%rsi	The index to insert at
# @param	%rdx	The element to add
# @return	%rax	The added element
.equ	THIS, -8	# The SEList
.equ	KEY, -16	# The key of the item to add
.equ	VAL, -24	# The value of the item to add
.equ	CURR, -32	# Pointer to the node which currently holds the key
.equ	IDX, -40	# The index of the current value at the key
.equ	NODE, -48	# Pointer to a node being examined (for loops)
SEList_add:
	push	%rbp
	mov	%rsp, %rbp

	# Index checking (not greater than length or less than zero)
	cmp	%rsi, SEList.len(%rdi)
	jc	10f			# In the case of "add" equals length is valid

	# Local variables
	sub	$48, %rsp
	mov	%rdi, THIS(%rbp)		# Save "this" pointer
	mov	%rsi, KEY(%rbp)
	mov	%rdx, VAL(%rbp)

	# Check if the item is being added to the end of the list
	cmp	SEList.len(%rdi), %rsi
	je	7f

	# Get the block and index of the key
	call	get_location
	mov	%rax, CURR(%rbp)
	mov	%rdx, IDX(%rbp)

	xor	%rcx, %rcx			# Loop counter = 0
	mov	%rax, NODE(%rbp)		# Node being examined, starts at the "current"
	jmp	2f				# Jump to find available nodes loop conditions

1:
	# Find available nodes loop body
	mov	SEListItem.next(%rax), %rax
	mov	%rax, NODE(%rbp)
	inc	%rcx

2:
	# Find available nodes loop conditions
	# Maximum iterations NOT reached yet
	cmp	$SELIST_BLOCK_SIZE, %rcx
	jge	2f

	# Not end of list
	cmp	SEList.head(%rdi), %rax
	je	2f

	# Current node's block is full
	mov	SEListItem.data(%rax), %rdi	# Change "this" pointer to the node's block
	call	BDeque_length
	mov	THIS(%rbp), %rdi		# Restore "this" pointer

	cmp	$SELIST_BLOCK_SIZE + 1, %rax
	mov	NODE(%rbp), %rax		# Restore node being examined
	jl	2f

	jmp	1b
2:

	# Once we reach here we either exceeded the max iterations, reached the end of the list 
	# or found a node with block space available. We need to apply some special handling to
	# certain of these conditions:

	# If we reached the max iterations without finding a result we need to call spread to
	# rebalance the list
	cmp	$SELIST_BLOCK_SIZE, %rcx
	jl	3f

	mov	CURR(%rbp), %rdi
	call	spread

	# Now that spead has occurred we can add to the node currently holding the element
	mov	CURR(%rbp), %rax
	mov	%rax, NODE(%rbp)

	jmp	5f				# Jump to shift loop

3:
	# If we reached are pointed at the end of the list we need to add a new node
	cmp	SEList.head(%rdi), %rax
	jne	5f

	mov	%rax, %rdi			# Set "this" pointer to node to add before
	call	add_node			# This will update %rax to the new node
	mov	%rax, NODE(%rbp)		# Set to current node
	mov	THIS(%rbp), %rdi		# Restore "this" pointer to SEList

	jmp	5f				# Jump to shift loop

4:
	# Shift loop - we start at the current node and work backwards on shifting elements
	# Retrieve the LAST value in the previous node
	mov	SEListItem.prev(%rax), %rdi	# Previous node
	mov	SEListItem.data(%rdi), %rdi	# Previous node's block
	# If we are shifting elements at all it implies that the blocks in question are full so 
	# to retrieve the last we can infer a key of SELIST_BLOCKSIZE
	mov	$SELIST_BLOCK_SIZE, %rsi
	call	BDeque_remove
	
	# Set the FIRST value on the current node
	mov	%rax, %rdx			# Value in %rdx
	mov	NODE(%rbp), %rax		# Restore current node in %rax
	mov	SEListItem.data(%rax), %rdi	# Pointer to block to add to
	xor	%rsi, %rsi			# First element is at index 0
	call	BDeque_add

	mov	NODE(%rbp), %rax		# Restore current node in %rax
	mov	SEListItem.prev(%rax), %rax
	mov	%rax, NODE(%rbp)

5:
	# Shift loop conditions
	cmp	CURR(%rbp), %rax
	jne	4b

	# Finally we are ready to set the item
	mov	SEListItem.data(%rax), %rdi	# Set "this" pointer to current nodes block
	mov	IDX(%rbp), %rsi
	mov	VAL(%rbp), %rdx
	call	BDeque_add

6:
	# Increment the length
	mov	THIS(%rbp), %rdi		# Restore "this" pointer
	incq	SEList.len(%rdi)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# Append the item to the list (ie add to last node)
7:
	# Add to the last node in the list. First we need to determine if we need to add a NEW node
	# If list is empty (ie "prev" of "head" is itself), we need to add a new node
	mov	SEList.head(%rdi), %rax
	mov	SEListItem.prev(%rax), %rax
	mov	%rax, NODE(%rbp)

	# Check if the prev node is just pointing at itself. If so the list is empty
	cmp	SEList.head(%rdi), %rax
	je	8f

	# Prev node is NOT the head node but we check if it is full and we need to add a new node
	mov	SEListItem.data(%rax), %rdi
	call	BDeque_length
	cmp	$SELIST_BLOCK_SIZE + 1, %rax
	je	8f

	# Neither is true so just add to the last node
	jmp	9f

8:
	# Add a new node before the "head"
	mov	THIS(%rbp), %rdi
	mov	SEList.head(%rdi), %rdi
	call	add_node
	mov	%rax, NODE(%rbp)

9:
	mov	NODE(%rbp), %rax
	mov	SEListItem.data(%rax), %rdi	# Arg1 to BDeque_add - BDeque pointer
	call	BDeque_length
	mov	%rax, %rsi			# Arg2 to BDeque_add - Last idx == length
	mov	VAL(%rbp), %rdx			# Arg3 to BDeque_add - Value
	call	BDeque_add
	jmp	6b

# Out of bounds
10:
	xor	%rax, %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	SEList_remove
# @description	Remove the element at the specified index
# @param	%rdi	Pointer to the SEList
# @param	%rsi	Index to remove
# @param	%rax	The removed element
.equ	THIS, -8
.equ	IDX, -16
.equ	CNODE, -24
.equ	CIDX, -32
.equ	CVAL, -40
.type	SEList_remove, @function
SEList_remove:
	push	%rbp
	mov	%rsp, %rbp

	# Index checking (not greater than / equal to the length or less than zero)
	cmp	%rsi, SEList.len(%rdi)
	jc	8f
	je	8f

	# Local variables
	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, IDX(%rbp)

	# Retrieve and store the current node and index
	call	get_location
	mov	%rax, CNODE(%rbp)
	mov	%rdx, CIDX(%rbp)

	# Retrieve and store the current value
	mov	SEListItem.data(%rax), %rdi
	mov	%rdx, %rsi
	call	BDeque_get
	mov	%rax, CVAL(%rbp)

	xor	%rcx, %rcx			# Loop counter = 0
	mov	CNODE(%rbp), %rdx		# Found node pointer
	jmp	2f

1:
	# Find nodes loop
	mov	SEListItem.next(%rdx), %rdx
	inc	%rcx

2:
	# Find nodes loop condition
	# Maximum number of iterations:
	cmp	$SELIST_BLOCK_SIZE, %rcx
	jge	3f

	# Check for head node (end of list)
	mov	THIS(%rbp), %rax
	cmp	SEList.head(%rax), %rdx
	je	3f

	# Check block for optimal size
	mov	SEListItem.data(%rdx), %rdi
	call	BDeque_length
	cmp	$SELIST_BLOCK_SIZE - 1, %rax
	jne	3f

	jmp	1b

3:
	# Check if we reached max iterations during the find loop
	cmp	$SELIST_BLOCK_SIZE, %rcx
	jne	3f

	mov	CNODE(%rbp), %rdi
	call	gather

3:
	# Remove the item
	mov	CNODE(%rbp), %rdx
	mov	SEListItem.data(%rdx), %rdi
	mov	CIDX(%rbp), %rsi
	call	BDeque_remove

	jmp	5f

4:
	# Element shift loop
	# Remove first element of "next" node
	mov	SEListItem.next(%rdx), %rdi
	mov	SEListItem.data(%rdi), %rdi
	xor	%rsi, %rsi
	call	BDeque_remove

	# Add removed element as last of the current node
	mov	CNODE(%rbp), %rdx
	mov	SEListItem.data(%rdx), %rdi
	mov	%rax, %rdx
	call	BDeque_length
	mov	%rax, %rsi
	call	BDeque_add

	# Increment current node
	mov	CNODE(%rbp), %rdx
	mov	SEListItem.next(%rdx), %rdx
	mov	%rdx, CNODE(%rbp)

5:
	# Element shift loop condition. Current node is in %rdx
	# Check if "next" is head node (end of list)
	mov	CNODE(%rbp), %rdx		# Restore current node in %rdx
	mov	SEListItem.next(%rdx), %rax
	mov	THIS(%rbp), %rcx
	cmp	SEList.head(%rcx), %rax
	je	6f

	# Less than optimal size
	mov	SEListItem.data(%rdx), %rdi
	call	BDeque_length
	cmp	$SELIST_BLOCK_SIZE - 1, %rax
	jge	6f	

	jmp	4b

6:
	# Check if node block is empty
	cmp	$0, %rax
	jne	6f

	mov	%rdx, %rdi
	call	remove_node

6:
	# Decrement length and put return value in %rax
	mov	THIS(%rbp), %rdi
	decq	SEList.len(%rdi)
	mov	CVAL(%rbp), %rax

7:
	mov	%rbp, %rsp
	pop	%rbp
	ret
# Out of bounds
8:	xor	%rax, %rax
	jmp	7b

# @function	SEList_log
# @description	Log the innards of an SEList
# @param	%rdi	Pointer to the SEList to log
# @return	void
.equ	THIS, -8
.equ	CTR, -16
.equ	HEAD, -24
.type	SEList_log, @function
SEList_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$s_delim, %rdi
	call	log

	movq	$0, CTR(%rbp)
	jmp	2f
1:
	mov	CTR(%rbp), %rsi
	call	SEList_get
	mov	%rax, %rdi
	call	log
	
	incq	CTR(%rbp)
	mov	THIS(%rbp), %rdi
	mov	CTR(%rbp), %rcx
	cmp	SEList.len(%rdi), %rcx
	je	3f

	mov	$m_delim, %rdi
	call	log

2:
	mov	THIS(%rbp), %rdi
	mov	CTR(%rbp), %rcx
	cmp	SEList.len(%rdi), %rcx
	jl	1b

3:
	mov	$e_delim, %rdi
	call	log

	mov	$lf, %rdi
	call	log

	mov	$len_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	SEList.len(%rdi), %rdi
	call	itoa

	mov	%rax, %rdi
	call	log

	mov	$lf, %rdi
	call	log

	mov	$raw_label, %rdi
	call	log

	mov	$sblock_delim, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	SEList.head(%rdi), %rax
	mov	%rax, HEAD(%rbp)
	mov	SEListItem.next(%rax), %rax
	mov	%rax, CTR(%rbp)

	jmp	5f
4:
	mov	$spacer, %rdi
	call	log

	mov	$mblock_delim, %rdi
	call	log

	mov	CTR(%rbp), %rax
	mov	SEListItem.data(%rax), %rdi
	call	BDeque_log
	
	mov	$mblock_delim, %rdi
	call	log

	mov	$lf, %rdi
	call	log

	mov	CTR(%rbp), %rax
	mov	SEListItem.next(%rax), %rax
	mov	%rax, CTR(%rbp)

5:
	cmp	HEAD(%rbp), %rax
	jne	4b

	mov	$eblock_delim, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	get_location
# @description	File private helper to get the node which stores the element at the specified key
# @param	%rdi	Pointer to the SEList
# @param	%rsi	The key to find the node for
# @return	%rax	Pointer to the SEListItem which contains the element
# @return	%rdx	Index of the element within the item
.equ	THIS, -8
.equ	CURR, -16
get_location:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	# Determine whether forward or backward traversal will be more efficient
	# First we divide the length by 2 to see which "half" contains the key
	mov	SEList.len(%rdi), %rax
	mov	$2, %rcx
	xor	%rdx, %rdx
	div	%rcx

	# Determine which loop to use (forward traversal or backward traversal)
	cmp	%rax, %rsi
	mov	SEList.head(%rdi), %rax		# In either case we start with the "head"
	jge	2f
	
	# Forward traversal loops from "next" of the "head"
	mov	SEListItem.next(%rax), %rax
	mov	%rax, CURR(%rbp)
	mov	%rsi, %rdx			# Loop counter = requested key
1:
	mov	SEListItem.data(%rax), %rdi
	call	BDeque_length

	cmp	%rax, %rdx
	jl	5f

	sub	%rax, %rdx
	mov	CURR(%rbp), %rax
	mov	SEListItem.next(%rax), %rax	# Move "next" into position
	mov	%rax, CURR(%rbp)
	jmp	1b

2:
	# Backward traversal
	mov	SEList.len(%rdi), %rdx		# Loop counter = the length
3:
	cmp	%rdx, %rsi
	jge	4f

	mov	SEListItem.prev(%rax), %rax	# Move "prev" into position
	mov	%rax, CURR(%rbp)

	mov	SEListItem.data(%rax), %rdi
	call	BDeque_length

	sub	%rax, %rdx
	mov	CURR(%rbp), %rax
	jmp	3b
4:
	sub	%rdx, %rsi
	mov	%rsi, %rdx
5:
	# idx is already in %rdx, so we just need to CURR into %rax
	mov	CURR(%rbp), %rax

	mov	THIS(%rbp), %rdi		# Restore "this" pointer to SEList
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	add_node
# @description	Adds a node BEFORE the specified block
# @param	%rdi	Pointer to the "next" node in the sequence
# @return	%rax	Pointer to the new node
.equ	NEXT, -8
.equ	THIS, -16
add_node:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$16, %rsp
	mov	%rdi, NEXT(%rbp)

	# Allocate new list item
	mov	$SELISTITEM_SIZE, %rdi
	call	alloc
	mov	%rax, THIS(%rbp)

	# Allocate "block"
	mov	$SELIST_BLOCK_SIZE + 1, %rdi
	call	BDeque_ctor
	mov	%rax, %rcx			# Allocated block in %rcx

	# Assign block
	mov	THIS(%rbp), %rax		# New node in %rcx
	mov	%rcx, SEListItem.data(%rax)	# Set "block" on the new node

	# Insert into the list
	mov	NEXT(%rbp), %rdx		# Puts the "next" node in %rdx
	mov	SEListItem.prev(%rdx), %rcx	# Puts the "prev" node of "next" in %rax
	mov	%rcx, SEListItem.prev(%rax)	# Sets "prev" on new node to "prev" of "next"
	mov	%rdx, SEListItem.next(%rax)	# Sets "next" on new node to "prev"
	mov	%rax, SEListItem.prev(%rdx)	# Sets "prev" on "next" to new node
	mov	%rax, SEListItem.next(%rcx)	# Sets "next" on old "prev" to new node

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	remove_node
# @description	File private method to remove a node from the list
# @param	%rdi	The node to remove
# @return	void
remove_node:
	# Unlink node from the list
	mov	SEListItem.prev(%rdi), %rax
	mov	SEListItem.next(%rdi), %rcx
	mov	%rcx, SEListItem.next(%rax)
	mov	%rax, SEListItem.prev(%rcx)

	push %rdi
	# Free the block
	mov	SEListItem.data(%rdi), %rdi
	call	BDeque_dtor

	# Free the item
	pop	%rdi
	call	free

	ret

# @function	spread
# @description	File private method to add a new node and spread out existing elements so that
#		there is optimal space on each block in the list
# @param	%rdi	Pointer to a start node
# @return	void
.equ	THIS, -8
.equ	CURR, -16
spread:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	xor	%rcx, %rcx		# Loop counter = 0
	jmp	2f
1:
	# Find the last node that will be impacted so that we can work backwards
	mov	SEListItem.next(%rdi), %rdi	# Move to next
	inc	%rcx

2:
	# Find loop condition
	cmp	$SELIST_BLOCK_SIZE - 1, %rcx
	jl	1b

	# Now that we have the LAST impacted node in %rdi we add a node directly before. This puts
	# the new node we've added into %rax
	call	add_node
	mov	%rax, CURR(%rbp)	# Assign current node to our stack variable
	jmp	6f

3:
	# Remove LAST element from the previous node. We know the block is full and that therefore
	# block size is the index of the last item
	mov	CURR(%rbp), %rax		# Put current in %rax
	mov	SEListItem.prev(%rax), %rdi
	mov	SEListItem.data(%rdi), %rdi

	# We need to get the length so we know what is the last index
	call	BDeque_length
	dec	%rax
	mov	%rax, %rsi
	call	BDeque_remove

	mov	%rax, %rdx			# Removed element in %rdx for add call
	mov	CURR(%rbp), %rax		# Put current in %rax
	mov	SEListItem.data(%rax), %rdi	# Pointer to current node's block in %rdi
	xor	%rsi, %rsi			# We are adding as the first element so idx is 0
	call	BDeque_add

4:
	# Inner shift loop condition. We continue shifting elements from the previous node to the
	# current node until we have SELIST_BLOCK_SIZE on the current node
	mov	CURR(%rbp), %rax		# Put current in %rax
	mov	SEListItem.data(%rax), %rdi
	call	BDeque_length
	cmp	$SELIST_BLOCK_SIZE, %rax
	jl	3b				# Continue inner loop

	# Outer shift loop
	# Make the previous node the current node
	mov	CURR(%rbp), %rax		# Put current in %rax
	mov	SEListItem.prev(%rax), %rax
	mov	%rax, CURR(%rbp)

6:
	# Outer shift loop condition. We continue shifting, and working backwards, until we arrive
	# back where we started the function
	cmp	THIS(%rbp), %rax
	jne	4b				# Jump to inner shift loop condition

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	gather
# @description	File private method to remove a node and condense existing elements so that ther
#		is optimal space on each block in the list
# @param	%rdi	Pointer to a start node
# @return	void
.equ	CNODE, -8
.equ	CTR, -16
gather:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$16, %rsp
	mov	%rdi, CNODE(%rbp)
	movq	$0, CTR(%rbp)

	jmp	3f

1:
	# Inner shift loop
	# Remove the first element from the "next" node
	mov	SEListItem.next(%rdx), %rdi
	mov	SEListItem.data(%rdi), %rdi
	xor	%rsi, %rsi
	call	BDeque_remove

	# Add as the last element to the current node
	mov	%rax, %rdx
	mov	CNODE(%rbp), %rdi
	mov	SEListItem.data(%rdi), %rdi
	call	BDeque_length
	mov	%rax, %rsi
	call	BDeque_add

2:
	# Inner shift loop condition
	mov	CNODE(%rbp), %rdx
	mov	SEListItem.data(%rdx), %rdi
	call	BDeque_length
	cmp	$SELIST_BLOCK_SIZE, %rax
	jl	1b

	mov	SEListItem.next(%rdx), %rdx
	mov	%rdx, CNODE(%rbp)
	incq	CTR(%rbp)

3:
	# Outer loop condition
	cmpq	$SELIST_BLOCK_SIZE - 1, CTR(%rbp)
	jl	2b

	# Remove the last node
	mov	%rdx, %rdi
	call	remove_node

	mov	%rbp, %rsp
	pop	%rbp
	ret
