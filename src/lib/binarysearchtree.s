# lib/binarysearchtree.s - BinarySearchTree

.include	"common.inc"

.globl	BinarySearchTree_ctor, BinarySearchTree_add, BinarySearchTree_find, BinarySearchTree_remove
.globl	BinarySearchTree_log

# BinarySearchTree
	.struct	0
BinarySearchTree.root:
	.struct	BinarySearchTree.root + 1<<3
BinarySearchTree.size:
	.struct	BinarySearchTree.size + 1<<3
	.equ	BINARYSEARCHTREE_SIZE, .

# BinarySearchTreeNode
	.struct	0
BinarySearchTreeNode.data:
	.struct	BinarySearchTreeNode.data + 1<<3
BinarySearchTreeNode.parent:
	.struct	BinarySearchTreeNode.parent + 1<<3
BinarySearchTreeNode.left:
	.struct	BinarySearchTreeNode.left + 1<<3
BinarySearchTreeNode.right:
	.struct	BinarySearchTreeNode.right + 1<<3
	.equ	BINARYSEARCHTREENODE_SIZE, .

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

# @function	BinarySearchTree_ctor
# @description	Constructor for a BinarySearchTree
# @return	%rax	Pointer to the new BinarySearchTree
.type	BinarySearchTree_ctor, @function
BinarySearchTree_ctor:
	mov	$BINARYSEARCHTREE_SIZE, %rdi
	call	alloc

	movq	$NULL, BinarySearchTree.root(%rax)
	movq	$0, BinarySearchTree.size(%rax)
	ret

# @function	BinarySearchTree_find
# @description	Find an element a the BinarySearchTree
# @param	%rdi	Pointer to the BinarySearchTree
# @param	%rsi	An element to find
# @return	%rax	The element on success or NULL on failure
.equ	THIS, -8
.equ	DATA, -16
.equ	CURR, -24
.type	BinarySearchTree_find, @function
BinarySearchTree_find:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DATA(%rbp)
	mov	BinarySearchTree.root(%rdi), %rax

	jmp	3f

1:
	mov	DATA(%rbp), %rdi
	mov	BinarySearchTreeNode.data(%rax), %rsi
	call	strcmp

	test	%rax, %rax

	# Value found
	cmovz	%rsi, %rax
	jz	4f

	# Continue searching
	mov	CURR(%rbp), %rax
	jg	2f

	# Data is less than the current node so move to the left
	mov	BinarySearchTreeNode.left(%rax), %rax
	jmp	3f

2:
	# Data is greater than the current node so move to the right
	mov	BinarySearchTreeNode.right(%rax), %rax

3:
	mov	%rax, CURR(%rbp)
	test	%rax, %rax
	jnz	1b

4:
	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinarySearchTree_add
# @description	Add an element to a BinarySearchTree
# @param	%rdi	Pointer to the BinarySearchTree
# @param	%rsi	Pointer to the element to add
# @return	%rax	The added element on success or NULL on failure
.equ	THIS, -8
.equ	DATA, -16
.equ	ADJC, -24
.type	BinarySearchTree_add, @function
BinarySearchTree_add:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DATA(%rbp)

	# Fetch the most adjacent node
	call	find_last
	mov	%rax, ADJC(%rbp)
	test	%rax, %rax
	jnz	1f

	# If most adjacent node is null we are inserting into an empty tree
	mov	DATA(%rbp), %rdi
	call	new_node
	mov	THIS(%rbp), %rdi
	mov	%rax, BinarySearchTree.root(%rdi)
	mov	ADJC(%rbp), %rcx
	jmp	3f

1:
	mov	DATA(%rbp), %rdi
	mov	BinarySearchTreeNode.data(%rax), %rsi
	call	strcmp
	test	%rax, %rax

	# Restore this pointer
	mov	THIS(%rbp), %rdi
	# If the result was zero we just return zero (NULL) bc the value is already in the tree
	jz	4f

	# Check if we are greater than or less than the adjacent
	jg	2f

	# New value is less than the adjacent node's value, thus we point the "left" of adjacent
	# at the new node
	mov	DATA(%rbp), %rdi
	call	new_node
	mov	ADJC(%rbp), %rcx
	mov	%rax, BinarySearchTreeNode.left(%rcx)
	jmp	3f

2:
	# New value is greater than the adjacent node's value, thus we point the "right" of
	# adjacent at the new node
	mov	DATA(%rbp), %rdi
	call	new_node
	mov	ADJC(%rbp), %rcx
	mov	%rax, BinarySearchTreeNode.right(%rcx)

3:
	mov	THIS(%rbp), %rdi
	# When we get here we've added a new node (%rax) and we have the adjacent node in %rcx
	mov	%rcx, BinarySearchTreeNode.parent(%rax)

	# Increment the size of the tree
	incq	BinarySearchTree.size(%rdi)

	# Set return value
	mov	DATA(%rbp), %rax

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinarySearchTree_remove
# @description	Remove the specified item from a BinarySearchTree
# @param	%rdi	Pointer to the BinarySearchTree
# @param	%rsi	The element to remove
# @param	%rax	The removed element on success, or NULL on failure
.equ	THIS, -8
.equ	DATA, -16
.equ	LAST, -24
.type	BinarySearchTree_remove, @function
BinarySearchTree_remove:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DATA(%rbp)
	call	find_last
	mov	%rax, LAST(%rbp)

	# Check to see if the tree even has the value
	mov	DATA(%rbp), %rdi
	mov	BinarySearchTreeNode.data(%rax), %rsi
	call	strcmp
	test	%rax, %rax
	xor	%rax, %rax
	jnz	4f

	# Check if the node has one or two NULL children
	mov	LAST(%rbp), %rsi
	cmpq	$NULL, BinarySearchTreeNode.left(%rsi)
	je	3f

	cmpq	$NULL, BinarySearchTreeNode.right(%rsi)
	je	3f

	mov	BinarySearchTreeNode.right(%rsi), %rsi
	jmp	2f

1:
	mov	BinarySearchTreeNode.left(%rsi), %rsi

2:
	cmpq	$NULL, BinarySearchTreeNode.left(%rsi)
	jnz	1b

	mov	BinarySearchTreeNode.data(%rsi), %rax
	mov	LAST(%rbp), %rcx
	mov	%rax, BinarySearchTreeNode.data(%rcx)

3:
	# Splice out the node
	mov	THIS(%rbp), %rdi
	call	splice

	# Set the return value
	mov	DATA(%rbp), %rax

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinarySearchTree_log
# @description	Logs the innards of a BinarySearchTree
# @param	%rdi	Pointer to the binary search tree
# @return	void
.equ	THIS, -8
.type	BinarySearchTree_log, @function
BinarySearchTree_log:
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
	mov	BinarySearchTree.size(%rdi), %rdi
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
	mov	BinarySearchTreeNode.data(%rdi), %rdi
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
	mov	BinarySearchTreeNode.data(%rdi), %rdi
	call	log

	mov	$raw_vrwrap, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	find_last
# @description	File private method to find the node holding the smallest value greater than the
#		specified element
# @param	%rdi	Pointer to the BinarySearchTree
# @param	%rsi	The search value
# @return	%rax	Pointer to the BinarySearchTreeNode holding the smallest value 
.equ	THIS, -8
.equ	DATA, -16
.equ	CURR, -24
.equ	PREV, -32
find_last:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DATA(%rbp)
	mov	BinarySearchTree.root(%rdi), %rax
	mov	%rax, CURR(%rbp)
	movq	$NULL, PREV(%rbp)
	jmp	3f

1:
	mov	%rax, PREV(%rbp)

	mov	DATA(%rbp), %rdi
	mov	BinarySearchTreeNode.data(%rax), %rsi
	call	strcmp

	test	%rax, %rax
	# If the result of strcmp is zero, the node in %rax/PREV has the value
	jz	4f
	jg	2f

	# Data is less than the current node so attempt to go left
	mov	CURR(%rbp), %rax
	mov	BinarySearchTreeNode.left(%rax), %rax
	mov	%rax, CURR(%rbp)
	jmp	3f

2:
	# Data is greater than the current node so attempt to go right
	mov	CURR(%rbp), %rax
	mov	BinarySearchTreeNode.right(%rax), %rax
	mov	%rax, CURR(%rbp)

3:
	# If this becomes null we've exhausted the search
	test	%rax, %rax
	jnz	1b

4:
	mov	PREV(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	splice
# @description	File private helper to extract a node from the tree
# @param	%rdi	Pointer to the BinarySearchTree
# @param	%rsi	Pointer to the node to splice
# @return	void
.equ	THIS, -8
splice:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	# Populate %rax with the splice node. This will be the left node of the target (if it's)
	# not NULL or otherwise the right node of the target
	cmpq	$NULL, BinarySearchTreeNode.left(%rsi)
	jz	1f

	mov	BinarySearchTreeNode.left(%rsi), %rax
	jmp	2f

1:
	MOV	BinarySearchTreeNode.right(%rsi), %rax

2:
	# Check if the target is the root
	cmp	BinarySearchTree.root(%rdi), %rsi
	jne	3f

	# If the target is the root, we set the new root to the splice node and set the parent of
	# the operation (in %rcx) to NULL
	mov	%rax, BinarySearchTree.root(%rdi)
	mov	$NULL, %rcx
	jmp	5f

3:
	# The target is NOT the root node, in which case we put the parent of the target in %rcx
	# and check if the target is to the left or the right of the parent. We replace the target
	# with the splice node accordingly
	mov	BinarySearchTreeNode.parent(%rsi), %rcx

	cmp	BinarySearchTreeNode.left(%rcx), %rsi
	jne	4f

	mov	%rax, BinarySearchTreeNode.left(%rcx)
	jmp	5f

4:
	mov	%rax, BinarySearchTreeNode.right(%rcx)

5:
	# Lastly we check to see if the splice node is NULL, if it is we are all done. If it is not
	# we need to set it's parent to the value obtained in the previous steps
	cmp	$NULL, %rax
	jz	6f

	mov	%rcx, BinarySearchTreeNode.parent(%rax)

6:
	# Free the node
	mov	%rsi, %rdi
	call	free

	# Decrement the size of the tree
	mov	THIS(%rbp), %rdi
	decq	BinarySearchTree.size(%rdi)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	new_node
# @description	File private helper to create a new node
# @param	%rdi	Value of the node
# @return	%rax	Pointer to a new BinarySearchTreeNode
.equ	DATA, -8
new_node:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, DATA(%rbp)

	mov	$BINARYSEARCHTREENODE_SIZE, %rdi
	call	alloc

	mov	DATA(%rbp), %rcx
	mov	%rcx, BinarySearchTreeNode.data(%rax)
	movq	$NULL, BinarySearchTreeNode.parent(%rax)
	movq	$NULL, BinarySearchTreeNode.left(%rax)
	movq	$NULL, BinarySearchTreeNode.right(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret
