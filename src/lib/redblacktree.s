# lib/redblacktree.s - RedBlackTree

.include	"common.inc"

.globl	RedBlackTree_ctor, RedBlackTree_add, RedBlackTree_remove, RedBlackTree_log

# RedBlackTree
	.struct	0
RedBlackTree.root:
	.struct	RedBlackTree.root + 1<<3
RedBlackTree.size:
	.struct	RedBlackTree.size + 1<<3
.equ	REDBLACKTREE_SIZE, .

# RedBlackTreeNode
	.struct	0
RedBlackTreeNode.data:
	.struct	RedBlackTreeNode.data + 1<<3
RedBlackTreeNode.parent:
	.struct	RedBlackTreeNode.parent + 1<<3
RedBlackTreeNode.left:
	.struct	RedBlackTreeNode.left + 1<<3
RedBlackTreeNode.right:
	.struct	RedBlackTreeNode.right + 1<<3
RedBlackTreeNode.color:
	.struct	RedBlackTreeNode.color + 1<<3
.equ	REDBLACKTREENODE_SIZE, .

# Colors
.equ	RED, 0
.equ	BLACK, 1

.section .rodata

newline:
	.byte	LF, NULL
null:
	.ascii	"NULL\0"
raw_label:
	.ascii	"Raw => {\0"
raw_end:
	.ascii	"}\0"
ds_delim:
	.ascii	"[\0"
de_delim:
	.ascii	"]\n\0"
horz:
	.ascii	"---\0"
vert:
	.ascii	"|--\0"
spacer:
	.byte	SPACE, SPACE, SPACE, NULL
red_circle:
	.byte	0xf0, 0x9f, 0x94, 0xb4, NULL
black_circle:
	.byte	0xe2, 0xac, 0xa4, SPACE, NULL

.section .text

# @function	RedBlackTree_ctor
# @description	Constructor for a RedBlackTree
# @return	%rax	Pointer to the new RedBlackTree
.type	RedBlackTree_ctor, @function
RedBlackTree_ctor:
	mov	$REDBLACKTREE_SIZE, %rdi
	call	alloc
	movq	$NULL, RedBlackTree.root(%rax)
	movq	$0, RedBlackTree.size(%rax)
	ret

# @function	RedBlackTree_add
# @description	Adds an element to a RedBlackTree
# @param	%rdi	Pointer to the RedBlackTree
# @param	%rsi	The item to add
# @return	%rax	The item on success, NULL on failure (e.g. node already in the tree)
.equ	THIS, -8
.type	RedBlackTree_add, @function
RedBlackTree_add:
	push	%rbp
	mov	%rsp, %rbp

	# TODO we may not need this!!
	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	call	add_node
	test	%rax, %rax
	jz	1f

	# We've added a new node so we need to perform any fixup operations to preserve the
	# cardinal properties of the tree
	mov	%rax, %rsi
	call	add_fixup

1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	RedBlackTree_remove
# @description	Remove an element from a RedBlackTree
# @param	%rdi	Pointer to a RedBlackTree
# @param	%rsi	Element to remove
# @param	%rax	The removed element on success or NULL on failure
.equ	THIS, -8
.equ	NODE, -16
.equ	PRNT, -24
.type	RedBlackTree_remove, @function
RedBlackTree_remove:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)

	call	find_last
	test	%rax, %rax
	jz	3f

	mov	%rax, NODE(%rbp)
	mov	RedBlackTreeNode.data(%rax), %rdi
	call	strcmp
	test	%rax, %rax
	jnz	3f

	# Now that we know we have the element we need to find a node (w) with only one child and
	# splice w out of the tree by having w.parent adopt the node we want to remove
	# %rax (u) is the node we want to remove
	# %rsi (w) holds our candidate for the node to splice out of the tree
	# %rcx is a temp store

	# We want the next highest value in the tree to replace the node we are going to remove.
	# First we check it's right child
	mov	NODE(%rbp), %rax
	mov	RedBlackTreeNode.right(%rax), %rsi
	test	%rsi, %rsi
	jnz	1f

	# If the right child of the node we want to remove is NULL then we can just splice the node
	# we want to remove
	mov	%rax, %rsi
	mov	RedBlackTreeNode.left(%rsi), %rax
	jmp	2f

1:
	# Otherwise we recurse down the left side of the right child of u until we reach a null
	# node which means we found the smallest value larger than u
	mov	RedBlackTreeNode.left(%rsi), %rcx
	test	%rcx, %rcx
	cmovnz	%rcx, %rsi
	jnz	1b
	
	# Now that we've found the node with the smallest value large than you we replace the data
	# at u with the data at that node
	mov	RedBlackTreeNode.data(%rsi), %rcx
	mov	%rcx, RedBlackTreeNode.data(%rax)
	mov	RedBlackTreeNode.right(%rsi), %rax

2:
	# Save w and u
	mov	%rax, NODE(%rbp)
	mov	%rsi, PRNT(%rbp)

	mov	THIS(%rbp), %rdi
	call	splice

	# TODO: I'm not completely clear on how to solve this but basically I'm in a situation 
	# where NODE in %rax is NULL. This happens when the node from find_last has no children
	mov	RedBlackTreeNode.color(%rsi), %rcx
	add	%rcx, RedBlackTreeNode.color(%rax)
	mov	RedBlackTreeNode.parent(%rsi), %rcx
	mov	%rcx, RedBlackTreeNode.parent(%rax)

	# Now we are done with the node so we can free it
	mov	%rsi, %rdi
	call	free

	mov	NODE(%rbp), %rsi
	call	remove_fixup

3:
	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	RedBlackTree_log
# @description	Logs the innards of a RedBlackTree
# @param	%rdi	Pointer to a RedBlackTree
# @return	void
.equ	THIS, -8
.type	RedBlackTree_log, @function
RedBlackTree_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$raw_label, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	RedBlackTree.root(%rdi), %rdi
	mov	$log_node, %rsi
	xor	%rdx, %rdx
	call	traverse

	mov	$raw_end, %rdi
	call	log

	mov	THIS(%rbp), %rdi

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	log_node
# @description	File private helper callback to log a node during traverse
# @param	%rdi	Pointer to the RedBlackTreeNode to log
# @param	%rsi	The depth of the node
# @return	void
.equ	THIS, -8
.equ	DPTH, -16
log_node:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DPTH(%rbp)

	mov	$spacer, %rdi
	call	log

	mov	DPTH(%rbp), %rsi
	test	%rsi, %rsi
	jz	2f

	mov	$vert, %rdi
	call	log

1:
	cmpq	$1, DPTH(%rbp)
	jle	2f

	mov	$horz, %rdi
	call	log
	decq	DPTH(%rbp)
	jmp	1b

2:
	mov	$ds_delim, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	test	%rdi, %rdi
	jnz	3f

	mov	$black_circle, %rdi
	call	log

	mov	$null, %rdi
	call	log
	jmp	6f

3:
	mov	THIS(%rbp), %rdi
	mov	RedBlackTreeNode.color(%rdi), %rdi
	test	%rdi, %rdi
	jz	4f

	mov	$black_circle, %rdi
	call	log
	jmp	5f

4:
	mov	$red_circle, %rdi
	call	log

5:
	mov	THIS(%rbp), %rdi
	mov	RedBlackTreeNode.data(%rdi), %rdi
	call	log

6:
	mov	$de_delim, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	traverse
# @description	File private helper to traverse the subtree at a given node and invoke a callback
# @param	%rdi	Pointer to the subtree root (RedBlackTreeNode)
# @param	%rsi	Pointer to a callback. Callback will recieve the node in %rdi
# @param	%rdx	The depth
# @return	void
.equ	THIS, -8
.equ	FUNC, -16
.equ	DPTH, -24
traverse:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, FUNC(%rbp)
	mov	%rdx, DPTH(%rbp)

	mov	%rdx, %rsi
	call	*FUNC(%rbp)

	mov	THIS(%rbp), %rdi
	mov	DPTH(%rbp), %rsi
	test	%rdi, %rdi
	jz	1f

	incq	DPTH(%rbp)

	mov	FUNC(%rbp), %rsi
	mov	DPTH(%rbp), %rdx
	mov	RedBlackTreeNode.left(%rdi), %rdi
	call	traverse

	mov	THIS(%rbp), %rdi
	mov	FUNC(%rbp), %rsi
	mov	DPTH(%rbp), %rdx
	mov	RedBlackTreeNode.right(%rdi), %rdi
	call	traverse

1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	add_node
# @description	File private helper that adds a node
# @param	%rdi	Pointer to the RedBlackTree
# @param	%rsi	The item to add
# @return	%rax	The node node on success or NULL on failure
.equ	THIS, -8
.equ	NODE, -16
add_node:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	call	find_last
	mov	%rax, NODE(%rbp)
	test	%rax, %rax
	jnz	1f

	# "Last" node is NULL which indicates we are inserting into an empty tree
	mov	%rsi, %rdi
	call	new_node

	# Insert new node as the "root"
	mov	THIS(%rbp), %rdi
	mov	%rax, RedBlackTree.root(%rdi)
	incq	RedBlackTree.size(%rdi)
	jmp	4f

1:
	mov	%rax, NODE(%rbp)

	# Check if the "last" node contains the same value we are trying to add, if so we can
	# return the NULL result in %rax ()
	mov	RedBlackTreeNode.data(%rax), %rdi
	call	strcmp
	test	%rax, %rax
	jz	4f

	# We are adding a new node to the left OR to the right so we need to preserve the current
	# state of the flags
	pushf

	# Create the new node
	mov	%rsi, %rdi
	call	new_node

	# Put parent in %rcx and jump to the correct assignment logic
	mov	NODE(%rbp), %rcx
	popf
	js	2f

	# "Last" node is greater than the new value so we need to add a new node to its left
	mov	%rax, RedBlackTreeNode.left(%rcx)
	jmp	3f

2:
	# "Last" node is LESS THAN the new value so we need to add a new node to its right
	mov	%rax, RedBlackTreeNode.right(%rcx)

3:
	# Set parent (%rcx) on the new node
	mov	%rcx, RedBlackTreeNode.parent(%rax)

	# Restore "this" pointer
	mov	THIS(%rbp), %rdi

	# Update the tree size
	incq	RedBlackTree.size(%rdi)

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

4:
	# Node already exists in the tree. In this case %rax is already set to NULL so we only
	# need to restore the this pointer
	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	find_last
# @description	File private helper that finds either a node in the tree or else the smallest node
#		in the tree that is greater than the specified element
# @param	%rdi	Pointer to the RedBlackTree
# @param	%rsi	The item to find
# @return	%rax	Pointer to a RedBlackTreeNode
.equ	THIS, -8
.equ	NODE, -16
find_last:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	RedBlackTree.root(%rdi), %rax
	mov	%rax, NODE(%rbp)
	jmp	3f

1:
	# Save node value during strcmp
	mov	%rax, NODE(%rbp)

	mov	RedBlackTreeNode.data(%rax), %rdi
	call	strcmp
	test	%rax, %rax
	jz	4f					# Node contains the value

	# Restore node value after strcmp so we can traverse another step
	mov	NODE(%rbp), %rax
	js	2f					# Node is GREATER THAN the search

	# Current node's value is GREATER THAN the search so we need to go left
	mov	RedBlackTreeNode.left(%rax), %rax
	jmp	3f

2:
	# Current node's value is LESS THAN the search so we need to go right
	mov	RedBlackTreeNode.right(%rax), %rax

3:
	test	%rax, %rax
	jnz	1b

4:
	mov	THIS(%rbp), %rdi
	mov	NODE(%rbp), %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	new_node
# @description	Creates a new RedBlackTreeNode
# @param	%rdi	The value of the node
# @return	%rax
new_node:
	push	%rdi

	# Allocate the node
	mov	$REDBLACKTREENODE_SIZE, %rdi
	call	alloc

	# Assign attributes
	pop	%rdi
	mov	%rdi, RedBlackTreeNode.data(%rax)
	movq	$NULL, RedBlackTreeNode.parent(%rax)
	movq	$NULL, RedBlackTreeNode.left(%rax)
	movq	$NULL, RedBlackTreeNode.right(%rax)
	movq	$RED, RedBlackTreeNode.color(%rax)

	ret

# @function	push_black
# @description	File private helper that takes a black node with two red children colors it red and
#		its children black
# @param	%rdi	Pointer to a black RedBlackTreeNode
# @return	void
push_black:
	decq	RedBlackTreeNode.color(%rdi)
	mov	RedBlackTreeNode.left(%rdi), %rax
	incq	RedBlackTreeNode.color(%rax)
	mov	RedBlackTreeNode.right(%rdi), %rax
	incq	RedBlackTreeNode.color(%rax)
	ret

# @function	pull_black
# @description	File private helper that takes a red node with two black children colors it black 
#		and its children red
# @param	%rdi	Pointer to a red RedBlackTreeNode
# @return	void
pull_black:
	incq	RedBlackTreeNode.color(%rdi)
	mov	RedBlackTreeNode.left(%rdi), %rax
	decq	RedBlackTreeNode.color(%rax)
	mov	RedBlackTreeNode.right(%rdi), %rax
	decq	RedBlackTreeNode.color(%rax)
	ret

# @function	rotate_left
# @description	File private helper that swaps a nodes right child with itself while maintaining
#		the binary search tree property
# @param	%rdi	Pointer to the RedBlackTree
# @param	%rsi	Pointer to a RedBlackTreeNode to rotate left
rotate_left:
	mov	RedBlackTreeNode.right(%rsi), %rax

	# Make the parent of w (right child) the parent of u (parent node)
	mov	RedBlackTreeNode.parent(%rsi), %rcx
	mov	%rcx, RedBlackTreeNode.parent(%rax)

	# Check if the parent is NULL
	test	%rcx, %rcx
	jz	2f

	# Checks if u was a left or right child
	cmp	%rsi, RedBlackTreeNode.left(%rcx)
	jne	1f

	# u is a left child of its parent so we need to instead make w the left child of the parent
	mov	%rax, RedBlackTreeNode.left(%rcx)
	jmp	2f

1:
	# u is a right child of its parent so we need to instead make w the right child of the 
	# parent
	mov	%rax, RedBlackTreeNode.right(%rcx)

2:
	# Make the left property of w instead be the right property of u. We know this is correct
	# Because since u was a parent of the structure at w it was LESS THAN ws children
	mov	RedBlackTreeNode.left(%rax), %rdx
	mov	%rdx, RedBlackTreeNode.right(%rsi)

	test	%rdx, %rdx
	jz	3f

	mov	%rsi, RedBlackTreeNode.parent(%rdx)

3:
	# Make the parent of u equal to w
	mov	%rax, RedBlackTreeNode.parent(%rsi)
	
	# Make u a left child of w
	mov	%rsi, RedBlackTreeNode.left(%rax)

	# Check if u was the root of the tree
	cmp	%rsi, RedBlackTree.root(%rdi)
	jne	4f

	# If u was the root of the tree update the root of the tree to be w and set w's parent to
	# NULL
	mov	%rax, RedBlackTree.root(%rdi)
	movq	$NULL, RedBlackTreeNode.parent(%rax)

4:
	ret

# @function	rotate_right
# @description	File private helper that swaps a nodes left child with itself while maintaining
#		the binary search tree property
# @param	%rdi	Pointer to the RedBlackTree
# @param	%rsi	Pointer to a RedBlackTreeNode
rotate_right:
	mov	RedBlackTreeNode.left(%rsi), %rax

	# Make the parent of w (right child) the parent of u (parent node)
	mov	RedBlackTreeNode.parent(%rsi), %rcx
	mov	%rcx, RedBlackTreeNode.parent(%rax)

	# Check if the parent is NULL
	test	%rcx, %rcx
	jz	2f

	# Checks if u was a left or right child
	cmp	%rsi, RedBlackTreeNode.left(%rcx)
	jne	1f

	# u is a left child of its parent so we need to instead make w the left child of the parent
	mov	%rax, RedBlackTreeNode.left(%rcx)
	jmp	2f

1:
	# u is a right child of its parent so we need to instead make w the right child of the 
	# parent
	mov	%rax, RedBlackTreeNode.right(%rcx)

2:
	# Make the right property of w instead be the left property of u. We know this is correct
	# Because since u was a parent of the structure at w it was LESS THAN ws children
	mov	RedBlackTreeNode.right(%rax), %rdx
	mov	%rdx, RedBlackTreeNode.left(%rsi)

	test	%rdx, %rdx
	jz	3f

	mov	%rsi, RedBlackTreeNode.parent(%rdx)

3:
	# Make the parent of u equal to w
	mov	%rax, RedBlackTreeNode.parent(%rsi)
	
	# Make u a right child of w
	mov	%rsi, RedBlackTreeNode.right(%rax)

	# Check if u was the root of the tree
	cmp	%rsi, RedBlackTree.root(%rdi)
	jne	4f

	# If u was the root of the tree update the root of the tree to be w and set w's parent to
	# NULL
	mov	%rax, RedBlackTree.root(%rdi)
	movq	$NULL, RedBlackTreeNode.parent(%rax)

4:
	ret

# @function	flip_left
# @description	File private helper that swaps the colors of a node and its right child and then
#		performs a left rotation
# @param	%rdi	Pointer to a RedBlackTree
# @param	%rsi	Pointer to a RedBlackTreeNode
# @return	void
flip_left:
	mov	RedBlackTreeNode.color(%rsi), %rax
	mov	RedBlackTreeNode.right(%rsi), %rcx
	mov	RedBlackTreeNode.color(%rcx), %rdx
	mov	%rdx, RedBlackTreeNode.color(%rsi)
	mov	%rax, RedBlackTreeNode.color(%rcx)
	call	rotate_left
	ret

# @function	flip_right
# @description	File private helper that swaps the colors of a node and its left child and then
#		performs a right rotation
# @param	%rdi	Pointer to a RedBlackTree
# @param	%rsi	Pointer to a RedBlackTreeNode
# @return	void
flip_right:
	mov	RedBlackTreeNode.color(%rsi), %rax
	mov	RedBlackTreeNode.left(%rsi), %rcx
	mov	RedBlackTreeNode.color(%rcx), %rdx
	mov	%rdx, RedBlackTreeNode.color(%rsi)
	mov	%rax, RedBlackTreeNode.color(%rcx)
	call	rotate_right
	ret

# @function	add_fixup
# @description	File private helper that restores all RedBlackTree properties after addition
# @param	%rdi	Pointer to the RedBlackTree
# @param	%rsi	Pointer to the RedBlackTreeNode that was just added whose color is red
# @return	void
.equ	THIS, -8
.equ	NODE, -16
.equ	PRNT, -24
add_fixup:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, NODE(%rbp)
	
	jmp	7f

1:
	# If the focus node happens to be the root of the tree we can just set its color to black
	# and return
	cmp	RedBlackTree.root(%rdi), %rsi
	jne	2f

	movq	$BLACK, RedBlackTreeNode.color(%rsi)
	jmp	8f

2:
	# We check the left node of the parent to see if it is black and if so, we therefore know
	# that the left child is NOT the new node (which is red) and therefore we are violating the
	# left-leaning property

	# Save parent (w)
	mov	RedBlackTreeNode.parent(%rsi), %rax
	mov	%rax, PRNT(%rbp)

	# Check if left child of the parent (w) is black
	mov	RedBlackTreeNode.left(%rax), %rcx
	test	%rcx, %rcx
	jz	3f

	cmpq	$BLACK, RedBlackTreeNode.color(%rcx)
	jne	4f

3:
	# If the left child is black then we are violating the left-leaning property x(bc the new 
	# node (right child)i is red. To remedy this we call flip left on the parent (w). This
	# swaps the colors of the parent (w) and and the new node (u) and performs a left rotation.
	# and w as its sibling). Afterwards we know we are no longer violating the left leaning
	# property because u (red) is now the right node
	mov	%rax, %rsi
	call	flip_left

	# After flipping left the left (black) node is on the right so whether w is black or not we
	# are no longer violating the left-leaning property. U has also become w's parent and w
	# occupies the position u did before. We make the focus node w (swap w and u).
	mov	PRNT(%rbp), %rsi
	mov	%rsi, NODE(%rbp)
	mov	RedBlackTreeNode.parent(%rsi), %rax
	mov	%rax, PRNT(%rbp)

4:
	# Next we check if the parent (w) is black. If it is not then we are good as u is red so
	# we are not in violation of the no-red-edge property.
	cmpq	$BLACK, RedBlackTreeNode.color(%rax)
	je	8f

	# Otherwise this means that w is red and u is red so we violate the no red edge property.
	# We move our focus up one level up to w's parent (u's grandparent)
	mov	RedBlackTreeNode.parent(%rax), %rsi
	mov	%rsi, NODE(%rbp)

	# We check if the right node on the grandparent is black. If so we may be able to fix the
	# no-red-edge property by flipping right
	mov	RedBlackTreeNode.right(%rsi), %rax
	test	%rax, %rax
	jz	5f

	cmpq	$BLACK, RedBlackTreeNode.color(%rax)
	jne	6f

5:
	call	flip_right
	jmp	8f

6:
	mov	%rsi, %rdi
	call	push_black

	# Restore "this" pointer after push_black. TODO: consider having %rdi reserved across ALL
	# helpers
	mov	THIS(%rbp), %rdi

7:
	cmpq	$RED, RedBlackTreeNode.color(%rsi)
	je	1b

8:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	splice
# @description	File private helper to splice a node out of the tree
# @param	%rdi	Pointer to a RedBlackTree
# @param	%rsi	Pointer to the RedBlackTreeNode to splice out
# @return	void
splice:
	mov	RedBlackTreeNode.left(%rsi), %rax
	test	%rax, %rax
	jz	1f

	mov	RedBlackTreeNode.left(%rsi), %rax
	jmp	2f

1:
	mov	RedBlackTreeNode.right(%rsi), %rax

2:
	# Check if the node to be spliced is the root
	cmp	RedBlackTree.root(%rdi), %rsi
	jne	3f

	# Node to be removed is the root
	mov	%rax, RedBlackTree.root(%rdi)
	xor	%rcx, %rcx
	jmp	5f

3:
	# Node to be removed is not the root
	mov	RedBlackTreeNode.parent(%rsi), %rcx
	cmp	%rsi, RedBlackTreeNode.left(%rcx)
	jne	4f

	mov	%rax, RedBlackTreeNode.left(%rcx)
	jmp	5f

4:
	mov	%rax, RedBlackTreeNode.right(%rcx)

5:
	test	%rax, %rax
	jz	6f

	mov	%rcx, RedBlackTreeNode.parent(%rax)

6:
	decq	RedBlackTree.size(%rdi)
	ret

# @function	remove_fixup
# @description	File private helper to resolve edge cases and balance the tree after a remove op
# @param	%rdi	Pointer to the RedBlackTree
# @param	%rsi	Pointer to the node in the tree which was a child of a removed node and
#			which was adopted by u's parent
# @return	void
.equ	THIS, -8
.equ	NODE, -16
remove_fixup:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, NODE(%rbp)

1:
	cmpq	$BLACK, RedBlackTreeNode.color(%rsi)
	jle	5f

	cmpq	RedBlackTree.root(%rdi), %rsi
	jne	2f

	# Fixup case 0 ... u is the root. We recolor u to be black
	movq	$BLACK, RedBlackTreeNode.color(%rsi)
	jmp	1b

2:
	mov	RedBlackTreeNode.parent(%rsi), %rax
	mov	RedBlackTreeNode.left(%rax), %rax
	testq	$RED, RedBlackTreeNode.color(%rax)
	jnz	3f

	# Fixup case 1 ... u's sibling, v, is red
	call	remove_fixup_case1
	mov	%rax, %rsi
	jmp	1b

3:
	cmp	%rax, %rsi
	jne	4f

	# Fixup case 2 ... u's sibling, v, is black, and u is the left child of its parent, w
	call	remove_fixup_case2
	mov	%rax, %rsi
	jmp	1b

4:
	# Fixup case 3 ... u's sibling is black and u is the right child of its parent, w
	call	remove_fixup_case3
	mov	%rax, %rsi
	jmp	1b

5:
	cmpq	RedBlackTree.root(%rdi), %rsi
	je	6f

	# Restore left-leaning property, if needed
	mov	RedBlackTreeNode.parent(%rsi), %rsi
	mov	RedBlackTreeNode.right(%rsi), %rax

	testq	$RED, RedBlackTreeNode.color(%rax)
	jnz	6f

	mov	RedBlackTreeNode.left(%rsi), %rax
	cmpq	$BLACK, RedBlackTreeNode.color(%rax)
	jne	6f

	call	flip_left

6:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	remove_fixup_case1
# @description	File private helper to fix case 1 during a remove operation
# @param	%rdi	Pointer to the RedBlackTree
# @param	%rsi	Pointer to the RedBlackTreeNode to fix
# @return	%rax	Pointer to the next node to fix
.equ	NODE, -8
remove_fixup_case1:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rsi, NODE(%rbp)

	mov	RedBlackTreeNode.parent(%rsi), %rsi
	call	flip_right

	mov	NODE(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	remove_fixup_case2
# @description	File private helper to fix case 2 during a remove operation
# @param	%rdi	Pointer to the RedBlackTree
# @param	%rsi	Pointer to the RedBlackTreeNode to fix
# @return	%rax	Pointer to the next node to fix
.equ	THIS, -8
.equ	NODE, -16
.equ	PRNT, -24
.equ	RGHT_OLD, -32
.equ	RGHT_NEW, -40
remove_fixup_case2:
	push	%rbp
	mov	%rsp, %rbp

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, NODE(%rbp)
	mov	RedBlackTreeNode.parent(%rsi), %rdi
	mov	%rdi, PRNT(%rbp)
	mov	RedBlackTreeNode.right(%rdi), %rax
	mov	%rax, RGHT_OLD(%rbp)

	# Parent of fixup node is in %rdi
	call	pull_black

	mov	THIS(%rbp), %rdi
	call	flip_left

	mov	RedBlackTreeNode.right(%rsi), %rax
	mov	%rax, RGHT_NEW(%rbp)

	testq	$RED, RedBlackTreeNode.color(%rax)
	jnz	2f

	call	rotate_left

	mov	RGHT_OLD(%rbp), %rsi
	call	flip_right

	mov	RGHT_NEW(%rbp), %rdi
	call	push_black

	mov	THIS(%rbp), %rdi
	mov	RGHT_OLD(%rbp), %rsi
	mov	RedBlackTreeNode.right(%rsi), %rax
	testq	$RED, RedBlackTreeNode.color(%rax)
	jnz	1f

	call	flip_left

1:
	mov	RGHT_NEW(%rbp), %rax
	jmp	3f

2:
	mov	RGHT_OLD(%rbp), %rax

3:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	remove_fixup_case3
# @description	File private helper to fix case 3 during a remove operation
# @param	%rdi	Pointer to the RedBlackTree
# @param	%rsi	Pointer to the RedBlackTreeNode to fix
# @return	%rax	Pointer to the next node to fix
.equ	THIS, -8
.equ	NODE, -16
.equ	PRNT, -24
.equ	LEFT_OLD, -32
.equ	LEFT_NEW, -40
remove_fixup_case3:
	push	%rbp
	mov	%rsp, %rbp

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, NODE(%rbp)
	mov	RedBlackTreeNode.parent(%rsi), %rdi
	mov	%rdi, PRNT(%rbp)
	mov	RedBlackTreeNode.left(%rdi), %rax
	mov	%rax, LEFT_OLD(%rbp)

	call	pull_black

	mov	THIS(%rbp), %rdi
	call	flip_right

	mov	RedBlackTreeNode.left(%rsi), %rax
	mov	%rax, LEFT_NEW(%rbp)

	testq	$RED, RedBlackTreeNode.color(%rax)
	jnz	2f

	call	rotate_right

	mov	LEFT_OLD(%rbp), %rsi
	call	flip_left

	mov	LEFT_NEW(%rbp), %rdi
	call	push_black

	mov	THIS(%rbp), %rdi
	mov	LEFT_NEW(%rbp), %rax
	jmp	4f

2:
	mov	LEFT_OLD(%rbp), %rsi
	testq	$RED, RedBlackTreeNode.color(%rsi)
	jnz	3f

	mov	%rsi, %rdi
	call	push_black
	mov	%rsi, %rax
	jmp	4f

3:
	call	flip_left
	mov	PRNT(%rbp), %rax

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret
