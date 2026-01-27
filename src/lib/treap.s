# lib/treap.s - Treap

.include	"common.inc"

.globl	Treap_ctor, Treap_add, Treap_find, Treap_remove, Treap_log

# Treap
	.struct	0
Treap.root:
	.struct	Treap.root + 1<<3
Treap.size:
	.struct	Treap.size + 1<<3
	.equ	TREAP_SIZE, .

# TreapNode
	.struct	0
TreapNode.data:
	.struct	TreapNode.data + 1<<3
TreapNode.parent:
	.struct	TreapNode.parent + 1<<3
TreapNode.left:
	.struct	TreapNode.left + 1<<3
TreapNode.right:
	.struct	TreapNode.right + 1<<3
TreapNode.priority:
	.struct	TreapNode.priority + 1<<3
	.equ	TREAPNODE_SIZE, .

.section .rodata

newline:
	.byte	LF, NULL
spacer:
	.byte	SPACE, SPACE, NULL
null:
	.ascii	"NULL\0"
height_label:
	.ascii	"Height => \0"
size_label:
	.ascii	"Size   => \0"
raw_label:
	.ascii	"Raw    => {\n\0"
raw_end:
	.ascii	"}\n\0"
raw_vlwrap:
	.ascii	"[\0"
raw_vrwrap:
	.ascii	"]\0"
comma:
	.ascii	",\0"
ts_delim:
	.ascii	"[ \0"
tm_delim:
	.ascii	", \0"
te_delim:
	.ascii	"... ]\0"
vert:
	.ascii	"|\0"
horz:
	.ascii	"---\0"

.section .text

# @function	Treap_ctor
# @description	Constructor for a Treap
# @return	%rax	Pointer to a new Treap
.type	Treap_ctor, @function
Treap_ctor:
	mov	$TREAP_SIZE, %rdi
	call	alloc
	movq	$NULL, Treap.root(%rax)
	movq	$0, Treap.size(%rax)
	ret

# @function	Treap_find
# @description	Find an element in a Treap
# @param	%rdi	Pointer to the Treap
# @param	%rsi	The element to find
# @param	%rax	The element or NULL
.equ	THIS, -8
.equ	CURR, -16
.type	Treap_find, @function
Treap_find:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	Treap.root(%rdi), %rax

1:
	# Save the current node somewhere safe during strcmp
	mov	%rax, CURR(%rbp)
	test	%rax, %rax
	jz	3f

	mov	TreapNode.data(%rax), %rdi
	call	strcmp

	# If the result of strcmp is zero we are done so set the return value and jump to the end
	test	%rax, %rax
	cmovz	%rdi, %rax
	jz	3f
	js	2f

	# Current node being examined is GREATER THAN the find value so we want to go left
	mov	CURR(%rbp), %rax
	mov	TreapNode.left(%rax), %rax
	jmp	1b

2:
	# Current node being examined is LESS THAN the find value so we want to go right
	mov	CURR(%rbp), %rax
	mov	TreapNode.right(%rax), %rax
	jmp	1b


3:
	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	Treap_add
# @description	Add an element to a Treap
# @param	%rdi	Pointer to the Treap
# @param	%rsi	Element to add
# @return	%rax	The added value
.equ	THIS, -8
.equ	DATA, -16
.type	Treap_add, @function
Treap_add:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables => TODO is this needed??
	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DATA(%rbp)

	call	add_node
	test	%rax, %rax
	jz	1f

	mov	%rax, %rsi
	call	bubble_up

1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	Treap_remove
# @description	Remove an element from a Treap
# @param	%rdi	Pointer to the Treap
# @param	%rsi	The element to remove
# @return	%rax	The removed element or NULL
.equ	THIS, -8
.equ	DATA, -16
.equ	NODE, -24
.type	Treap_remove, @function
Treap_remove:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DATA(%rbp)
	call	find_last
	mov	%rax, NODE(%rbp)

	test	%rax, %rax
	jz	1f

	mov	TreapNode.data(%rax), %rdi
	call	strcmp

	test	%rax, %rax
	mov	$NULL, %rax			# NULL out return value in case we jnz
	jnz	1f
	
	mov	THIS(%rbp), %rdi
	mov	NODE(%rbp), %rsi
	call	trickle_down
	call	splice

	# Free the removed node
	mov	%rsi, %rdi
	call	free

	# Restore the "this" pointer and tee up return value
	mov	THIS(%rbp), %rdi
	mov	DATA(%rbp), %rax

1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	Treap_log
# @description	Logs the innards of a Treap
# @param	%rdi	Pointer to a Treap
# @return	void
.equ	THIS, -8
.type	Treap_log, @function
Treap_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$ts_delim, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	$log_node, %rsi
	mov	$1, %rdx
	call	BinaryTree_rtraverse

	mov	$te_delim, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$size_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	Treap.size(%rdi), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$height_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	call	BinaryTree_rheight
	mov	%rax, %rdi
	call	itoa
	mov	%rax, %rdi
	call	 log

	mov	$newline, %rdi
	call	log

	mov	$raw_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	$log_raw, %rsi
	mov	$0, %rdx
	call	BinaryTree_rtraverse

	mov	$raw_end, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	log_node
# @description	File private helper callback to log a node during a traverse
# @param	%rdi	Pointer to the node to log
# @return	void
log_node:
	mov	TreapNode.data(%rdi), %rdi
	call	log

	mov	$tm_delim, %rdi
	call	log
	ret	

# @function	log_raw
# @description	File private helper callback to log a node during a breadth-first traverse
# @param	%rdi	Pointer to the node to log
# @return	void
# Callback for raw logging:
.equ	THIS, -8
.equ	DEPTH, -16
log_raw:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$spacer, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	call	BinaryTreeNode_depth
	mov	%rax, DEPTH(%rbp)

	test	%rax, %rax
	jz	2f

	mov	$vert, %rdi
	call	log

1:
	mov	$horz, %rdi
	call	log
	decq	DEPTH(%rbp)
	cmpq	$0, DEPTH(%rbp)
	jg	1b

2:
	mov	$raw_vlwrap, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	TreapNode.data(%rdi), %rdi
	call	log

	mov	$comma, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	TreapNode.priority(%rdi), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$raw_vrwrap, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	find_last
# @description	File private method to find the last node in the tree before a value
# @param	%rdi	Pointer to the Treap
# @param	%rsi	Value
# @return	%rax	Pointer to a TreapNode
.equ	THIS, -8
.equ	CURR, -16
.equ	PREV, -24
find_last:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	Treap.root(%rdi), %rax
	movq	$NULL, PREV(%rbp)

1:
	mov	%rax, CURR(%rbp)
	test	%rax, %rax
	jz	3f

	mov	%rax, PREV(%rbp)

	mov	TreapNode.data(%rax), %rdi
	call	strcmp
	test	%rax, %rax

	# Restore %rax
	mov	CURR(%rbp), %rax

	jz	3f
	js	2f

	# Value of the current node being examined is GREATER THAN the provided value so we need to
	# go "left"
	mov	TreapNode.left(%rax), %rax
	jmp	1b

2:
	# Value of the current node being examined is LESS THAN the provided value so we need to
	# go "right"
	mov	TreapNode.right(%rax), %rax
	jmp	1b

3:
	# Value of current node being examined is EQUAL TO the provided value

	mov	THIS(%rbp), %rdi
	mov	PREV(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	new_node
# @description	File private helper to create a new TreapNode
# @param	%rdi	Value of the node
# @return	%rax	Pointer to a new TreapNode
new_node:
	push	%rdi

	# Allocate the node
	mov	$TREAPNODE_SIZE, %rdi
	call	alloc

	# Assign the attributes
	pop	%rdi
	mov	%rdi, TreapNode.data(%rax)
	movq	$NULL, TreapNode.parent(%rax)
	movq	$NULL, TreapNode.left(%rax)
	movq	$NULL, TreapNode.left(%rax)

1:
	# Generate the priority (p) value
	rdrand	%cx
	jnc	1b

	# Assign p noting that we only use the lowest 8 bits to achieve a small number that is 
	# easy to reason about. TODO: we may want this to be larger to achieve better distribution
	movb	%cl, TreapNode.priority(%rax)
	ret

# @function	add_node
# @description	File private helper to add a value to the tree
# @param	%rdi	Pointer to the Treap
# @param	%rsi	Element to add
# @return	%rax	Returns the added node or NULL on failure
.equ	THIS, -8
.equ	DATA, -16
.equ	NODE, -24
add_node:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DATA(%rbp)
	call	find_last
	mov	%rax, NODE(%rbp)

	test	%rax, %rax
	jnz	1f

	# Last node is NULL which indicates an empty tree
	mov	%rsi, %rdi
	call	new_node
	mov	THIS(%rbp), %rdi
	mov	%rax, Treap.root(%rdi)
	mov	NODE(%rbp), %rcx
	jmp	3f

1:
	# Check if the node is already in the tree
	mov	TreapNode.data(%rax), %rdi
	call	strcmp
	test	%rax, %rax

	# The node is already in the tree so we don't make a new node and return NULL if this is
	# the case
	mov	$NULL, %rax			# We cannot use xor here bc that sets flags
	jz	4f

	# Check if the comparison was signed (LESS THAN) or not (GREATER THAN)
	js	2f

	# The value of the last node is LESS THAN the value being added so the new node goes on the
	# "left"
	mov	%rsi, %rdi
	call	new_node
	mov	NODE(%rbp), %rcx
	mov	%rax, TreapNode.left(%rcx)

	mov	THIS(%rbp), %rdi
	jmp	3f

2:
	# The value of the last node is GREATER THAN the value being added so the new node goes on
	# the "right"
	mov	%rsi, %rdi
	call	new_node
	mov	NODE(%rbp), %rcx
	mov	%rax, TreapNode.right(%rcx)

	mov	THIS(%rbp), %rdi

3:
	# Set the parent on the new node
	mov	%rcx, TreapNode.parent(%rax)

	# Increase the size by one
	incq	Treap.size(%rdi)

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	splice
# @description	File private helper to remove a node from a Treap
# @param	%rdi	Pointer to the Treap
# @param	%rsi	Pointer to the TreapNode to remove
# @return	void
splice:
	# We obtain a descendent of the target (%rax) and the parent of the target (%rcx)
	# To obtain the descendent, first we check if "left" of the target has a value, and if so, 
	# we use that. Otherwise use "right". We do not care if "right" is NULL for now
	mov	TreapNode.left(%rsi), %rax
	test	%rax, %rax
	jnz	1f

	mov	TreapNode.right(%rsi), %rax

1:
	# Check if the target node is the root
	cmp	Treap.root(%rdi), %rsi
	jne	2f

	# Target node IS the root so we set the new root to the target node's descendent and set 
	# the parent (%rcx) to NULL
	mov	%rax, Treap.root(%rdi)
	xor	%rcx, %rcx

2:
	# Target node is NOT the root so we set the parent to the parent of the target and splice
	# the target out
	mov	TreapNode.parent(%rsi), %rcx

	# Check if the target is a "left" child
	cmp	%rsi, TreapNode.left(%rcx)
	jne	3f

	# If the target is a "left" child we replace it with the descendent
	mov	%rax, TreapNode.left(%rcx)
	jmp	4f

3:
	# Otherwise the target is a "right" child so we replace it with the descendent
	mov	%rax, TreapNode.right(%rcx)

4:
	# Lastly check if the descendent was NULL. Is it was not we need to set its parent
	test	%rax, %rax
	jz	5f

	mov	%rcx, TreapNode.parent(%rax)

5:
	decq	Treap.size(%rdi)
	ret

# @function	rotate_left
# @description	File private helper that takes a target node and rotates its subtree such that the
#		right child of the target becomes the parent while preserving the binary search
#		tree property
# @param	%rdi	Pointer to the Treap
# @param	%rsi	Pointer to the node to rotate
# @return	void
rotate_left:
	# Target (u) is in %rsi. Node on the "right" (w) is in %rax and "parent" of w is in %rcx
	mov	TreapNode.right(%rsi), %rax	# w

	# Set the parent of the node on the right to the parent of the target
	mov	TreapNode.parent(%rsi), %rcx
	mov	%rcx, TreapNode.parent(%rax)

	# Check that we are not the root node and parent is null
	test	%rcx, %rcx
	jz	2f

	# Check which side of the parent the target is on
	cmp	TreapNode.left(%rcx), %rsi
	jne	1f

	# If target is on the "left" side of the parent, we set the "left" side of parent to w
	mov	%rax, TreapNode.left(%rcx)
	jmp	2f

1:
	# If target is on the "right" side of the parent, we set the "right" side of parent to w
	mov	%rax, TreapNode.right(%rcx)

2:
	# Make the "right" side of the target point to the "left" of w. Remember w was the "right"
	# side of the target (greater than it) so the "left" of w is also greater than the target
	mov	TreapNode.left(%rax), %rdx
	mov	%rdx, TreapNode.right(%rsi)

	# Check to see if the new "right" side of the target is null, if not we need to set its
	# parent
	test	%rdx, %rdx
	jz	3f

	mov	%rsi, TreapNode.parent(%rdx)

3:
	# Make w the parent of the target
	mov	%rax, TreapNode.parent(%rsi)

	# Set the target as the "left" of w
	mov	%rsi, TreapNode.left(%rax)
		
	# Check if the target node is the root
	cmp	%rsi, Treap.root(%rdi)
	jne	4f

	# If the target node is the root, then we need to make w the root instead and set its 
	# parent to NULL
	mov	%rax, Treap.root(%rdi)
	movq	$NULL, TreapNode.parent(%rax)

4:
	ret

# @function	rotate_right
# @description	File private helper that takes a target node and rotates its subtree such that the
#		left child of the target becomes the parent while preserving the binary search
#		tree property
# @param	%rdi	Pointer to the Treap
# @param	%rsi	Pointer to the node to rotate
# @return	void
rotate_right:
	# Target (u) is in %rsi. Node on the "left" (w) is in %rax and "parent" of w is in %rcx
	mov	TreapNode.left(%rsi), %rax	# w

	# Set the parent of the node on the left to the parent of the target
	mov	TreapNode.parent(%rsi), %rcx
	mov	%rcx, TreapNode.parent(%rax)

	# Check that we are not the root node and parent is null
	test	%rcx, %rcx
	jz	2f

	# Check which side of the parent the target is on
	cmp	TreapNode.left(%rcx), %rsi
	jne	1f

	# If target is on the "left" side of the parent, we set the "left" side of parent to w
	mov	%rax, TreapNode.left(%rcx)
	jmp	2f

1:
	# If target is on the "right" side of the parent, we set the "right" side of parent to w
	mov	%rax, TreapNode.right(%rcx)

2:
	# Make the "left" side of the target point to the "right" of w. Remember w was on the left 
	# of the target (less than it) so the right of w is also less than the target
	mov	TreapNode.right(%rax), %rdx
	mov	%rdx, TreapNode.left(%rsi)

	# Check to see if the new "left" side of the target is null, if not we need to set its
	# parent
	test	%rdx, %rdx
	jz	3f

	mov	%rsi, TreapNode.parent(%rdx)

3:
	# Make w the parent of the target
	mov	%rax, TreapNode.parent(%rsi)

	# Set the target as the "right" of w
	mov	%rsi, TreapNode.right(%rax)
		
	# Check if the target node is the root
	cmp	%rsi, Treap.root(%rdi)
	jne	4f

	# If the target node is the root, then we need to make w the root instead and set its 
	# parent to NULL
	mov	%rax, Treap.root(%rdi)
	movq	$NULL, TreapNode.parent(%rax)

4:
	ret

# @function	bubble_up
# @description	File private helper to handle the necessary rotations needed in response to an add
#		operation
# @param	%rdi	Pointer to the Treap
# @param	%rsi	Pointer to the new node that was added
# @return	void
bubble_up:
1:
	# Break if the target is the root
	cmp	%rsi, Treap.root(%rdi)
	je	4f

	# Parent of the target in %rax because we will use it multiple times
	mov	TreapNode.parent(%rsi), %rax

	# Break if the parent's priority if LESS THAN or EQUAL TO the target (heap property)
	mov	TreapNode.priority(%rax), %rcx
	cmp	TreapNode.priority(%rsi), %rcx
	jbe	4f

	push	%rsi
	cmp	TreapNode.right(%rax), %rsi
	jne	2f

	# The target is on the "right" side of the parent so rotate left
	mov	%rax, %rsi
	call	rotate_left
	jmp	3f

2:
	# The target is on the "left" side of the parent so rotate right
	mov	%rax, %rsi
	call	rotate_right

3:
	pop	%rsi
	jmp	1b

4:
	# If the parent of the target ends up being null that means it became the root of the tree
	cmpq	$NULL, TreapNode.parent(%rsi)
	jne	5f

	mov	%rsi, Treap.root(%rdi)

5:
	ret

# @function	trickle_down
# @description	Perform rotations in order to move a target node (u) downwards until it becomes a
#		leaf
# @param	%rdi	Pointer to the Treap
# @param	%rsi	Pointer to the target TreapNode
# @return	void
trickle_down:
	jmp	5f

1:
	# If "left" is NULL we rotate left
	test	%rax, %rax
	jz	2f

	# If "right" is NULL we rotate right
	test	%rcx, %rcx
	jz	3f

	# If "left" has a lower priority than "right" we rotate right
	mov	TreapNode.priority(%rax), %rax
	cmp	TreapNode.priority(%rcx), %rax
	jl	3f
	# If none of the above is true we rotate left

2:
	call	rotate_left
	jmp	4f

3:
	call	rotate_right

4:
	# If the target is the root, set the root to the target's parent
	cmp	Treap.root(%rdi), %rsi
	jne	5f

	mov	TreapNode.parent(%rsi), %rax
	mov	%rax, Treap.root(%rdi)

5:
	mov	TreapNode.left(%rsi), %rax
	mov	TreapNode.right(%rsi), %rcx

	# Continue the loop so long as either "left" OR "right"  of the target have a value. When
	# neither has a value we are done and the target is a leaf node
	test	%rax, %rax
	jnz	1b

	test	%rcx, %rcx
	jnz	1b

	ret
