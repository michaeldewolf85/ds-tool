# lib/scapegoattree.s - ScapegoatTree

.include	"common.inc"

.globl	ScapegoatTree_ctor, ScapegoatTree_add, ScapegoatTree_remove, ScapegoatTree_find
.globl	ScapegoatTree_log

# ScapegoatTree
	.struct	0
ScapegoatTree.root:				# Root (r)
	.struct	ScapegoatTree.root + 1<<3
ScapegoatTree.size:				# Size (n)
	.struct	ScapegoatTree.size + 1<<2
ScapegoatTree.bound:				# Bound (q) - At all times q/2 <= n <= q
	.struct	ScapegoatTree.bound + 1<<2
.equ	SCAPEGOATTREE_SIZE, .

# ScapegoatTreeNode
	.struct	0
ScapegoatTreeNode.data:
	.struct	ScapegoatTreeNode.data + 1<<3
ScapegoatTreeNode.parent:
	.struct	ScapegoatTreeNode.parent + 1<<3
ScapegoatTreeNode.left:
	.struct	ScapegoatTreeNode.left + 1<<3
ScapegoatTreeNode.right:
	.struct	ScapegoatTreeNode.right + 1<<3
.equ	SCAPEGOATTREENODE_SIZE, .

.section .rodata

# 1/log_2(3/2) or log_3/2(2)
log32_2:
	.double	1.709511291351455

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
bound_label:
	.ascii	"Bound  => \0"
log32_label:
	.ascii	"Log32  => \0"
raw_label:
	.ascii	"Raw    => {\n\0"
raw_end:
	.ascii	"}\n\0"
raw_vlwrap:
	.ascii	"[\0"
raw_vrwrap:
	.ascii	"]\0"
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

# @function	ScapegoatTree_ctor
# @description	Constructor for a ScapegoatTree
# @return	void
.type	ScapegoatTree_ctor, @function
ScapegoatTree_ctor:
	mov	$SCAPEGOATTREE_SIZE, %rdi
	call	alloc

	movq	$NULL, ScapegoatTree.root(%rax)
	movl	$0, ScapegoatTree.size(%rax)
	movl	$0, ScapegoatTree.bound(%rax)
	ret

# @function	ScapegoatTree_find
# @description	Finds an element in a ScapegoatTree
# @param	%rdi	Pointer to the ScapegoatTree
# @param	%rsi	The element to find
# @return	%rax	The element if found or NULL
.equ	THIS, -8
.equ	CURR, -16
.type	ScapegoatTree_find, @function
ScapegoatTree_find:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	ScapegoatTree.root(%rdi), %rax
	mov	%rax, CURR(%rbp)
	jmp	3f

1:
	mov	%rax, CURR(%rbp)
	mov	ScapegoatTreeNode.data(%rax), %rdi
	call	strcmp
	test	%rax, %rax
	mov	CURR(%rbp), %rax

	cmovz	%rdi, %rax
	jz	4f

	js	2f

	# Node being examined is greater than the search value so we need to go left
	mov	ScapegoatTreeNode.left(%rax), %rax
	jmp	3f

2:
	# Node being examined is less than the search value so we need to go right
	mov	ScapegoatTreeNode.right(%rax), %rax

3:
	test	%rax, %rax
	jnz	1b

4:
	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	ScapegoatTree_add
# @description	Adds an element to a ScapegoatTree
# @param	%rdi	Pointer to a ScapegoatTree
# @param	%rsi	The element to add
# @return	%rax	TRUE on success or FALSE on failure
.equ	THIS, -8
.equ	NODE, -16
.equ	DEPTH, -24
.equ	VAL, -32
.type	ScapegoatTree_add, @function
ScapegoatTree_add:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, VAL(%rbp)

	# Puts new node in %rax and depth (q) of new node in %rdx
	call	add_with_depth
	mov	%rax, NODE(%rbp)
	mov	%rdx, DEPTH(%rbp)
	
	movl	ScapegoatTree.bound(%rdi), %edi
	call	log32

	# Check if we have exceeded our max logarithmic depth
	cmp	%rax, %rdx
	jle	3f

	mov	NODE(%rbp), %rcx
	mov	ScapegoatTreeNode.parent(%rcx), %rcx

1:
	# Find scapegoat ... parent of new node is in %rcx
	# Compare three times the size of the parent of the new node ...
	mov	%rcx, %rdi
	call	size
	imul	$3, %rax
	mov	%rax, %rdx

	# ... to two times the size of the parent's parent
	mov	ScapegoatTreeNode.parent(%rcx), %rdi
	call	size
	imul	$2, %rax

	cmp	%rax, %rdx
	jg	2f

	mov	%rdi, %rcx
	jmp	1b

2:
	mov	%rdi, %rsi
	mov	THIS(%rbp), %rdi
	call	rebuild

3:
	# Restore this pointer
	mov	THIS(%rbp), %rdi

	# Prepare return value (TRUE/FALSE)
	mov	$NULL, %rax		# Set to return value to false by default
	mov	VAL(%rbp), %rcx		# Stage TRUE in a register (for CMOVcc)
	mov	DEPTH(%rbp), %rdx	# Check that depth >= 0
	test	%rdx, %rdx
	cmovns	%rcx, %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	ScapegoatTree_remove
# @description	Removes an element from a ScapegoatTree
# @param	%rdi	Pointer to a ScapegoatTree
# @param	%rsi	The element to remove
# @return	%rax	TRUE on success, FALSE on failure
.equ	THIS, -8
.equ	NODE, -16
.equ	VAL, -24
.type	ScapegoatTree_remove, @function
ScapegoatTree_remove:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, VAL(%rbp)
	call	find_last_with_depth
	test	%rax, %rax
	jz	5f

	mov	%rax, NODE(%rbp)
	mov	ScapegoatTreeNode.data(%rax), %rdi
	call	strcmp
	test	%rax, %rax
	jnz	5f

	# NODE contains the value to remove, we put it in %rsi in anticipation of calling splice
	mov	THIS(%rbp), %rdi
	mov	NODE(%rbp), %rsi

	# If the target node has a NULL left node ...
	cmpq	$NULL, ScapegoatTreeNode.left(%rsi)
	je	3f

	# ... or a NULL right node, we can call splice directly ...
	cmpq	$NULL, ScapegoatTreeNode.right(%rsi)
	je	3f

	# Otherwise we need to trade the target nodes value with a leaf node and splice the leaf
	# instead. First we go to the immediate right of the target (value > target), and traverse
	# all the way down to the left until we reach the end, which gives us the next greatest
	# value to the target in the tree
	mov	ScapegoatTreeNode.right(%rsi), %rsi
	jmp	2f

1:
	mov	ScapegoatTreeNode.left(%rsi), %rsi

2:
	cmpq	$NULL, ScapegoatTreeNode.left(%rsi)
	jne	1b

	# Having found the next greatest value (and a leaf node), we swap the value of the target
	# with the value at the leaf node.
	mov	NODE(%rbp), %rax
	mov	ScapegoatTreeNode.data(%rsi), %rcx
	mov	%rcx, ScapegoatTreeNode.data(%rax)

3:
	# Finally we can splice out the node
	call	splice

	# Check if we need a full rebuild
	movl	ScapegoatTree.size(%rdi), %eax
	imul	$2, %eax
	cmp	ScapegoatTree.bound(%rdi), %eax
	jge	4f

	# Rebuild the whole tree
	mov	ScapegoatTree.root(%rdi), %rsi
	call	rebuild

	# Update the bound to be the size
	mov	ScapegoatTree.size(%rdi), %eax
	mov	%eax, ScapegoatTree.bound(%rdi)

4:
	mov	VAL(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

5:
	# Value was not found in the tree
	mov	THIS(%rbp), %rdi
	xor	%rax, %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	ScapegoatTree_log
# @description	Logs the innards of a ScapegoatTree
# @param	%rdi	Pointer to the ScapegoatTree
# @return	void
.equ	THIS, -8
.type	ScapegoatTree_log, @function
ScapegoatTree_log:
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
	mov	ScapegoatTree.size(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$bound_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	ScapegoatTree.bound(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$log32_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	ScapegoatTree.bound(%rdi), %edi
	call	log32
	mov	%rax, %rdi
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

	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	log_node
# @description	File private helper callback to log a node during a traverse
# @param	%rdi	Pointer to the node to log
# @return	void
log_node:
	mov	ScapegoatTreeNode.data(%rdi), %rdi
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
	mov	ScapegoatTreeNode.data(%rdi), %rdi
	call	log

	mov	$raw_vrwrap, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	splice
# @description	Removes the target node from the tree
# @param	%rdi	Pointer to the ScapegoatTree
# @param	%rsi	Pointer to the ScapegoatTreeNode to splice
# @return	void
splice:
	push	%rdi	# Preserve this pointer bc we call alloc

	mov	ScapegoatTreeNode.left(%rsi), %rax
	test	%rax, %rax
	jnz	1f

	mov	ScapegoatTreeNode.right(%rsi), %rax

1:
	cmp	ScapegoatTree.root(%rdi), %rsi
	jne	2f

	# Node to be spliced is the ROOT node, if so we can just replace the root with the child
	mov	%rax, ScapegoatTree.root(%rdi)
	xor	%rcx, %rcx
	jmp	4f

2:
	# Node to be spliced is NOT the ROOT node. First we check to see if the target is a left or
	# right child
	mov	ScapegoatTreeNode.parent(%rsi), %rcx

	cmp	%rsi, ScapegoatTreeNode.left(%rcx)
	jne	3f

	# Target node is a left child so we replace if with its own child
	mov	%rax, ScapegoatTreeNode.left(%rcx)
	jmp	4f
	
3:
	# Target node is a right child so we replace if with its own child
	mov	%rax, ScapegoatTreeNode.right(%rcx)

4:
	# Check the replacement is NULL. If it is not we need to also update its parent
	test	%rax, %rax
	jz	5f

	mov	%rcx, ScapegoatTreeNode.parent(%rax)

5:
	# Decrement the size
	decl	ScapegoatTree.size(%rdi)

	# Free the node now that we are done with it
	mov	%rsi, %rdi
	call	free

	pop	%rdi	# Restore this pointer
	ret

# @function	find_last_with_depth
# @description	File private helper to find the node containing a leaf location for a value
# @param	%rdi	Pointer to a ScapegoatTree
# @param	%rsi	The element to find the location of
# @return	%rax	Pointer to a ScapegoatTreeNode
# @return	%rdx	The depth of the node
.equ	THIS, -8
.equ	CURR, -16
.equ	DEPTH, -24
find_last_with_depth:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	ScapegoatTree.root(%rdi), %rax
	movq	$NULL, CURR(%rbp)
	movq	$0, DEPTH(%rbp)

1:
	test	%rax, %rax
	jz	3f

	mov	%rax, CURR(%rbp)

	mov	ScapegoatTreeNode.data(%rax), %rdi
	call	strcmp

	# Test strcmp result
	test	%rax, %rax

	# Restore current node in %rax
	mov	CURR(%rbp), %rax
	jz	3f
	js	2f

	# Current node is GREATER THAN the target so we go left
	mov	ScapegoatTreeNode.left(%rax), %rax
	incq	DEPTH(%rbp)
	jmp	1b

2:
	# Current node is LESS THAN the target so we go right
	mov	ScapegoatTreeNode.right(%rax), %rax
	incq	DEPTH(%rbp)
	jmp	1b

3:
	mov	THIS(%rbp), %rdi
	mov	CURR(%rbp), %rax
	mov	DEPTH(%rbp), %rdx
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	new_node
# @description	File private helper to create a new node
# @param	%rdi	Value for the node
# @return	%rax	Pointer to the new ScapegoatTreeNode
new_node:
	push	%rdi				# Preserve value

	# Allocate the new node
	mov	$SCAPEGOATTREENODE_SIZE, %rdi
	call	alloc

	pop	%rdi				# Restore value

	# Allocate and clear attributes
	mov	%rdi, ScapegoatTreeNode.data(%rax)
	movq	$NULL, ScapegoatTreeNode.parent(%rax)
	movq	$NULL, ScapegoatTreeNode.left(%rax)
	movq	$NULL, ScapegoatTreeNode.right(%rax)

	ret

# @function	add_with_depth
# @description	File private helper to add a node to the ScapegoatTree and return the node and its
#		depth
# @param	%rdi	Pointer to a ScapegoatTree
# @param	%rsi	The element to add
# @return	%rax	The added node
# @return	%rdx	The depth of the new node
.equ	THIS, -8
.equ	NODE, -16
.equ	DEPTH, -24
add_with_depth:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	call	find_last_with_depth
	mov	%rax, NODE(%rbp)
	mov	%rdx, DEPTH(%rbp)
	
	test	%rax, %rax
	jnz	1f

	# If the leaf location is NULL (zero) that means we are inserting into an empty tree
	mov	%rsi, %rdi
	call	new_node
	mov	THIS(%rbp), %rdi
	mov	%rax, ScapegoatTree.root(%rdi)
	xor	%rcx, %rcx			# This is implied to be the parent (which is NULL)
	jmp	3f

1:
	mov	%rsi, %rdi
	mov	ScapegoatTreeNode.data(%rax), %rsi
	call	strcmp
	test	%rax, %rax

	# Check if value is already contained in the tree
	jz	5f

	js	2f

	# The new value is GREATER THAN the found node so it goes on the right
	call	new_node
	mov	NODE(%rbp), %rcx
	mov	%rax, ScapegoatTreeNode.right(%rcx)
	jmp	3f

2:
	# The new value is LESS THAN the the found node so it goes on the left
	call	new_node
	mov	NODE(%rbp), %rcx
	mov	%rax, ScapegoatTreeNode.left(%rcx)

3:
	# Set the parent on the new node
	mov	%rcx, ScapegoatTreeNode.parent(%rax)

	# Restore the "this" pointer
	mov	THIS(%rbp), %rdi

	# Increase the size + bounds
	incl	ScapegoatTree.size(%rdi)
	incl	ScapegoatTree.bound(%rdi)

	# Add depth to the return value
	mov	DEPTH(%rbp), %rdx

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

5:
	# Node with the specified value ALREADY exists in the tree (%rax already has zero/NULL)
	mov	THIS(%rbp), %rdi
	mov	$-1, %rdx
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	rebuild
# @description	File private helper to deconstruct and rebuild a subtree
# @param	%rdi	Pointer to the ScapegoatTree
# @param	%rsi	Pointer to the root of the new subtree (ScapegoatTreeNode)
# @return	void
.equ	THIS, -8
.equ	NODE, -16
.equ	PRNT, -24
.equ	SIZE, -32
.equ	ARRY, -40
rebuild:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	# Obtain and store parent of root
	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, NODE(%rbp)
	mov	ScapegoatTreeNode.parent(%rsi), %rax
	mov	%rax, PRNT(%rbp)

	# Obtain and store size of the subtree
	mov	%rsi, %rdi
	call	size
	mov	%rax, SIZE(%rbp)

	# Allocate and store a temporary array
	mov	%rax, %rdi
	imul	$1<<3, %rdi
	call	alloc
	mov	%rax, ARRY(%rbp)

	# Pack the nodes in the tree into the array
	mov	NODE(%rbp), %rdi
	mov	%rax, %rsi
	xor	%rdx, %rdx
	call	pack_into_array

	# Build the balanced tree
	mov	ARRY(%rbp), %rdi
	xor	%rsi, %rsi
	mov	SIZE(%rbp), %rdx
	call	build_balanced

	# Root of the new tree is in %rax, the target node is in %rcx, parent node is in %rdx
	mov	NODE(%rbp), %rcx
	mov	PRNT(%rbp), %rdx
	test	%rdx, %rdx
	jnz	1f

	# Parent node is root of the tree proper so we need to set the new tree root as the root
	mov	THIS(%rbp), %rdi
	mov	%rax, ScapegoatTree.root(%rdi)
	movq	$NULL, ScapegoatTreeNode.parent(%rax)

	jmp	3f

1:
	# Check if target is the right node of the parent
	cmp	ScapegoatTreeNode.right(%rdx), %rcx
	jne	2f

	# Target node was a right child so we set the subtree as the right child of the parent
	mov	%rax, ScapegoatTreeNode.right(%rdx)
	mov	%rdx, ScapegoatTreeNode.parent(%rax)
	jmp	3f

2:
	# Target node was a left child so we set the subtree as the left child of the parent
	mov	%rax, ScapegoatTreeNode.left(%rdx)
	mov	%rdx, ScapegoatTreeNode.parent(%rax)

3:
	# Free the temp array
	mov	ARRY(%rbp), %rdi
	call	free

	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	pack_into_array
# @description	File private helper to pack a subtree into an array
# @param	%rdi	Pointer to the root of the subtree
# @param	%rsi	Pointer to the array
# @param	%rdx	A recursion counter (should start at zero)
# @return	%rax	The count of elements packed
.equ	THIS, -8
pack_into_array:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	test	%rdi, %rdi
	jz	1f

	# Recurse to the left
	mov	ScapegoatTreeNode.left(%rdi), %rdi
	call	pack_into_array

	# Move current element into position
	mov	THIS(%rbp), %rdi
	mov	%rdi, (%rsi, %rdx, 1<<3)
	inc	%rdx

	mov	ScapegoatTreeNode.right(%rdi), %rdi
	call	pack_into_array

1:
	mov	%rdx, %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	build_balanced
# @description	File private helper to build a perfectly balanced tree
# @param	%rdi	Pointer to a sorted array of items
# @param	%rsi	Start index into sorted array
# @param	%rdx	Counter of additions
# @return	%rax	Pointer to the ScapegoatTreeNode at the root of a subtree
.equ	RCTR, -8
.equ	SIZE, -16
.equ	MIDP, -24
.equ	CURR, -32
build_balanced:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rsi, RCTR(%rbp)
	mov	%rdx, SIZE(%rbp)

	# Check if we've added all the elements and return NULL if so
	xor	%rax, %rax
	test	%rdx, %rdx
	jz	3f

	# Divide addition counter by two and capture the midpoint index into the array
	mov	%rdx, %rax
	xor	%rdx, %rdx
	mov	$2, %rcx
	div	%rcx
	mov	%rax, MIDP(%rbp)

	# Obtain the array index that this level of recursion will be operating with (counter plus
	# size div 2) and capture current node to work on
	add	%rsi, %rax
	mov	(%rdi, %rax, 1<<3), %rax
	mov	%rax, CURR(%rbp)

	# Construct the build_balanced call for the item to the "left" of the current
	# %rdi still has the array of sorted items
	# %rsi still has the count
	# We need to put the count remaining div 2 into %rdx and then we call ourselves
	mov	MIDP(%rbp), %rdx
	call	build_balanced

	# Move result of last build_balanced call into the "left" of the current node
	mov	CURR(%rbp), %rcx
	mov	%rax, ScapegoatTreeNode.left(%rcx)
	test	%rax, %rax
	jz	1f

	# The "left" node we just added was not null so we need to set its parent to the current
	# node
	mov	%rcx, ScapegoatTreeNode.parent(%rax)

1:
	# Construct the build_balanced call for the item to the "right" of the current
	# %rdi still has the array of sorted items
	# %rsi needs to have the current count + midpoint + 1
	mov	RCTR(%rbp), %rsi
	add	MIDP(%rbp), %rsi
	inc	%rsi
	# %rdi Needs to have the size minus the midpoint minus one
	mov	SIZE(%rbp), %rdx
	sub	MIDP(%rbp), %rdx
	dec	%rdx
	call	build_balanced

	# Move the result of last build_balanced call into the right of the current node
	mov	CURR(%rbp), %rcx
	mov	%rax, ScapegoatTreeNode.right(%rcx)
	test	%rax, %rax
	jz	2f

	# The "right" node we just added was not null so we need to set its parent to the current
	# node
	mov	%rcx, ScapegoatTreeNode.parent(%rax)

2:
	# Return the current node on this path
	mov	CURR(%rbp), %rax

3:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	size
# @description	File private helper to determine the size of a subtree
# @param	%rdi	Pointer to a ScapegoatTreeNode
# @return	%rax	Returns the number of nodes in a subtree
.equ	THIS, -8
.equ	SIZE, -16
size:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	movq	$0, SIZE(%rbp)

	test	%rdi, %rdi
	jz	1f

	incq	SIZE(%rbp)
	mov	ScapegoatTreeNode.left(%rdi), %rdi
	call	size
	add	%rax, SIZE(%rbp)

	mov	THIS(%rbp), %rdi
	mov	ScapegoatTreeNode.right(%rdi), %rdi
	call	size
	add	%rax, SIZE(%rbp)

1:
	mov	THIS(%rbp), %rdi
	mov	SIZE(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret


# @function	log32
# @description	File private helper that calculates log_3/2(q) of a number (q).
# @param	%rdi	The argument (q) to the logarithm
# @return	%rax	The exponent which 3/2 needs to be raised to in order to equal q
.equ	TMP, -8
.equ	CW_SAVE, -12
.equ	CW_CEIL, -16
log32:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, TMP(%rbp)

	# Push log_3/2(2) magic constant onto FPU register stack
	fldl	log32_2

	# Covert q to floating point and push onto FPU register stack
	fildl	TMP(%rbp)

	# Calculate log_3/2(q) and pop the stack so that result is on top
	fyl2x

	# Save the current FPU 2 byte control word (CW)
	fstcw	CW_SAVE(%rbp)

	# Move FPU CW into %rax to modify round flags
	movzwl	CW_SAVE(%rbp), %eax
	and	$~0xc00, %ax		# Clears bits 11 + 12 ~0xc00 = 1111 0011 1111 1111 w/ tilde
	or	$0x800, %ax		# Sets bit 12 (round up bit) 0x800 - 1000 0000 0000
	mov	%ax, CW_CEIL(%rbp)
	fldcw	CW_CEIL(%rbp)

	# Round the result of the log calculation (w/ ceiling config via control words)
	frndint

	# IMPORTANT!! Restore original control word
	fldcw	CW_SAVE(%rbp)

	# Convert result back to integer and store the result on the stack
	fistpq	TMP(%rbp)

	mov	TMP(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret
