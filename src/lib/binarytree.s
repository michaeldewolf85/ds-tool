# lib/binarytree.s - BinaryTree

.include	"common.inc"

.globl	BinaryTree_ctor, BinaryTree_dtor, BinaryTree_rheight, BinaryTree_rsize
.globl	BinaryTree_rtraverse, BinaryTree_size, BinaryTree_traverse, BinaryTreeNode_depth
.globl	BinaryTree_bftraverse

# BinaryTree
	.struct	0
BinaryTree.root:
	.struct	BinaryTree.root + 1<<3
	.equ	BINARYTREE_SIZE, .

# BinaryTreeNode
	.struct	0
BinaryTreeNode.idx:
	.struct	BinaryTreeNode.idx + 1<<3
BinaryTreeNode.parent:
	.struct	BinaryTreeNode.parent + 1<<3
BinaryTreeNode.left:
	.struct	BinaryTreeNode.left + 1<<3
BinaryTreeNode.right:
	.struct	BinaryTreeNode.right + 1<<3
	.equ	BINARYTREENODE_SIZE, .

.section .text

# @function	BinaryTree_ctor
# @description	Constructor for a BinaryTree
# @param	%rdi	The number of nodes in the tree
# @return	%rax	Pointer to the new BinaryTree instance
.equ	ILIM, -8
.equ	CIDX, -16
.equ	POFF, -24
.equ	ROOT, -32
.type	BinaryTree_ctor, @function
BinaryTree_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rdi, ILIM(%rbp)	# Limit counter
	movq	$1, CIDX(%rbp)		# Index of current node + loop counter
	movq	$-3, POFF(%rbp)		# Offset of current parent on stack relative to base 

	# If the size passed is zero we don't create a binary tree and just return NULL
	xor	%rax, %rax
	cmp	$0, %rdi
	je	4f

	# Create root node
	mov	$BINARYTREENODE_SIZE, %rdi
	call	alloc

	movq	$1, BinaryTreeNode.idx(%rax)
	movq	$NULL, BinaryTreeNode.parent(%rax)
	mov	%rax, ROOT(%rbp)
	incq	CIDX(%rbp)

1:
	# Allocate the current node and push it to the stack
	mov	$BINARYTREENODE_SIZE, %rdi
	call	alloc
	push	%rax

	# Test if the current index is even or odd
	mov	CIDX(%rbp), %rcx
	test	$1, %rcx
	jnz	2f

	# Even indices indicate a new parent so we move the parent offset down the stack
	decq	POFF(%rbp)

	mov	POFF(%rbp), %rdx
	mov	(%rbp, %rdx, 1<<3), %rdx
	
	# Set the "left" of the parent node to the current node
	mov	%rax, BinaryTreeNode.left(%rdx)
	jmp	3f

2:
	mov	POFF(%rbp), %rdx
	mov	(%rbp, %rdx, 1<<3), %rdx
	
	# Set the "right" of the parent node to the current node
	mov	%rax, BinaryTreeNode.right(%rdx)

3:
	# Set the "idx" on the new node
	mov	%rcx, BinaryTreeNode.idx(%rax)

	# Since we reuse memory we need to initialize these to NULL in case they are not empty
	movq	$NULL, BinaryTreeNode.left(%rax)
	movq	$NULL, BinaryTreeNode.right(%rax)

	# Set the "parent" of the current node
	mov	%rdx, BinaryTreeNode.parent(%rax)

	incq	CIDX(%rbp)
	cmp	ILIM(%rbp), %rcx
	jl	1b

	# Done creating nodes so allocate the tree and set the root
	mov	$BINARYTREE_SIZE, %rdi
	call	alloc

	mov	ROOT(%rbp), %rcx
	mov	%rcx, BinaryTree.root(%rax)

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinaryTree_dtor
# @description	Destructor for a BinaryTree
# @param	%rdi	Pointer to the BinaryTree
.type	BinaryTree_dtor, @function
BinaryTree_dtor:
	push	%rdi

	# Free every node
	mov	BinaryTree.root(%rdi), %rdi
	mov	$free, %rsi
	call	rtraverse

	# Free the tree itself
	pop	%rdi
	call	free

	ret

# @function	BinaryTree_bftraverse
# @description	Do a breadth-first traversal of the BinaryTree and invoke a callbac at each node
# @param	%rdi	Pointer to the BinaryTree
# @param	%rsi	Callback
# @return	void
.equ	THIS, -8
.equ	FUNC, -16
.equ	CURR, -24
.equ	QUEUE, -32
.type	BinaryTree_bftraverse, @function
BinaryTree_bftraverse:
	push	%rbp
	mov	%rsp, %rbp

	cmpq	$NULL, BinaryTree.root(%rdi)
	je	4f

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, FUNC(%rbp)
	mov	BinaryTree.root(%rdi), %rax
	mov	%rax, CURR(%rbp)

	call	ArrayQueue_ctor
	mov	%rax, QUEUE(%rbp)

	mov	%rax, %rdi
	mov	CURR(%rbp), %rsi
	call	ArrayQueue_add

	jmp	3f

1:
	# Get the current item
	call	ArrayQueue_remove
	mov	%rax, CURR(%rbp)

	# Invoke the callback
	mov	%rax, %rdi
	mov	FUNC(%rbp), %rsi
	call	*%rsi

	# From here on keep the queue in %rdi
	mov	QUEUE(%rbp), %rdi

	# Check if left is null, if not add the left
	mov	CURR(%rbp), %rax
	cmpq	$NULL, BinaryTreeNode.left(%rax)
	je	2f

	mov	BinaryTreeNode.left(%rax), %rsi
	call	ArrayQueue_add
	
2:
	# Check if right is null, if not add the right
	mov	CURR(%rbp), %rax
	cmpq	$NULL, BinaryTreeNode.right(%rax)
	je	3f

	mov	BinaryTreeNode.right(%rax), %rsi
	call	ArrayQueue_add
	
3:
	call	ArrayQueue_length
	test	%rax, %rax
	jnz	1b

	# Free the queue
	call	ArrayQueue_dtor

4:
	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinaryTree_size
# @description	Calculate the size of the binary tree (non-recursive)
# @param	%rdi	Pointer to a BinaryTree
# @return	%rax	The size of the tree
.equ	THIS, -8
.equ	PREV, -16
.equ	NEXT, -24
.type	BinaryTree_size, @function
BinaryTree_size:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)

	# Intialize "current", "previous" and "next
	mov	BinaryTree.root(%rdi), %rax
	mov	%rax, %rcx
	movq	$NULL, PREV(%rbp)
	movq	$NULL, NEXT(%rbp)

	# Start size at zero
	xor	%rax, %rax

	# For the duration of the loop %rcx is the current, %rdx is the parent, %rsi is the left 
	# and %rdi is the right
1:
	# Top level one - Is the previous the parent?
	mov	BinaryTreeNode.parent(%rcx), %rdx
	cmp	%rdx, PREV(%rbp)
	jne	4f

	# If the previous was the parent we increment the size
	inc	%rax

	# Is the left null? If not go to the left
	mov	BinaryTreeNode.left(%rcx), %rsi
	test	%rsi, %rsi
	jz	2f

	mov	%rsi, NEXT(%rbp)
	jmp	6f

2:
	# Is the right null? If not go to the right
	mov	BinaryTreeNode.right(%rcx), %rdi
	test	%rdi, %rdi
	jz	3f

	mov	%rdi, NEXT(%rbp)
	jmp	6f

3:
	# Left and right are both null so go to the parent
	mov	%rdx, NEXT(%rbp)
	jmp	6f

4:
	# Top level two - Is the previous the left?
	mov	BinaryTreeNode.left(%rcx), %rsi
	cmp	%rsi, PREV(%rbp)
	jne	5f

	# Is the right null? If not go to the right
	mov	BinaryTreeNode.right(%rcx), %rdi
	test	%rdi, %rdi
	jz	5f

	mov	%rdi, NEXT(%rbp)
	jmp	6f

5:
	# The right was null  or we came from the right already so we go to the parent
	mov	%rdx, NEXT(%rbp)

6:
	# Prepare next iteration
	mov	%rcx, PREV(%rbp)
	mov	NEXT(%rbp), %rcx

7:
	test	%rcx, %rcx
	jnz	1b

	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinaryTree_traverse
# @description	Traverse a binary tree an invoke a callback at each node (non-recursive)
# @param	%rdi	Pointer to the BinaryTree
# @param	%rsi	A callback to invoke for each node
# @return	void
.equ	THIS, -8
.equ	FUNC, -16
.equ	CURR, -24
.equ	PREV, -32
.equ	NEXT, -40
.type	BinaryTree_traverse, @function
BinaryTree_traverse:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, FUNC(%rbp)

	# Initialize "current", "previous" and "next"
	mov	BinaryTree.root(%rdi), %rax
	mov	%rax, CURR(%rbp)
	movq	$NULL, PREV(%rbp)
	movq	$NULL, NEXT(%rbp)
	jmp	8f

1:
	# Invoke the callback
	mov	CURR(%rbp), %rdi
	mov	FUNC(%rbp), %rsi
	call	*%rsi

	# Top level branch one - if the previous is the parent
	mov	CURR(%rbp), %rax
	mov	BinaryTreeNode.parent(%rax), %rcx
	cmp	%rcx, PREV(%rbp)
	jne	4f	

	# Is the left null? If not use the left
	mov	BinaryTreeNode.left(%rax), %rdx
	test	%rdx, %rdx
	jz	2f

	mov	%rdx, NEXT(%rbp)
	jmp	6f

2:
	# Is the right null? If not use the right
	mov	BinaryTreeNode.right(%rax), %rsi
	test	%rsi, %rsi
	jz	3f

	mov	%rsi, NEXT(%rbp)
	jmp	6f

3:
	# Left and right are null so use parent
	mov	%rcx, NEXT(%rbp)
	jmp	6f

4:
	# Top level branch two - if the previous is the left
	mov	BinaryTreeNode.left(%rax), %rsi
	cmp	%rsi, PREV(%rbp)
	jne	5f

	# Is the right null? If not use the right
	mov	BinaryTreeNode.right(%rax), %rsi
	test	%rsi, %rsi
	jz	5f
	
	mov	%rsi, NEXT(%rbp)
	jmp	6f

5:
	# The previous was the right or The right was null so we use the parent
	mov	%rcx, NEXT(%rbp)

6:
	# Preparation for next iteration
	mov	CURR(%rbp), %rax
	mov	%rax, PREV(%rbp)
	mov	NEXT(%rbp), %rax
	mov	%rax, CURR(%rbp)

8:
	cmpq	$NULL, CURR(%rbp)
	jne	1b

	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinaryTree_rheight
# @description	Calculate the height of the binary tree (recursive)
# @param	%rdi	Pointer to the BinaryTree
# @return	%rax	The height of the tree
.type	BinaryTree_rheight, @function
BinaryTree_rheight:
	push	%rdi
	mov	BinaryTree.root(%rdi), %rdi
	call	rheight
	pop	%rdi
	ret

# @function	BinaryTree_rsize
# @description	Calculate the size of the binary tree (recursive)
# @param	%rdi	Pointer to a BinaryTree
# @return	%rax	The size of the tree
.type	BinaryTree_rsize, @function
BinaryTree_rsize:
	push	%rdi
	mov	BinaryTree.root(%rdi), %rdi
	call	rsize
	pop	%rdi
	ret

# @function	BinaryTree_rtraverse
# @description	Traverse a binary tree an invoke a callback at each node (recursive)
# @param	%rdi	Pointer to the BinaryTree
# @param	%rsi	A callback to invoke for each node
# @return	void
.type	BinaryTree_rtraverse, @function
BinaryTree_rtraverse:
	push	%rdi
	mov	BinaryTree.root(%rdi), %rdi
	call	rtraverse
	pop	%rdi
	ret

# @function	BinaryTreeNode_depth
# @description	Calculates the depth of a node in the tree
# @param	%rdi	Pointer to a BinaryTreeNode
# @return	%rax	The depth of the node
.type	BinaryTreeNode_depth, @function
BinaryTreeNode_depth:
	xor	%rax, %rax

1:
	mov	BinaryTreeNode.parent(%rdi), %rdi
	cmp	$NULL, %rdi
	je	2f

	inc	%rax
	jmp	1b

2:
	ret

# @function	rheight
# @description	Calculate the height of the tree beneath a node (recursive)
# @param	%rdi	Pointer to a BinaryTreeNode
# @return	%rax	The height of the tree
.equ	THIS, -8
.equ	LHEIGHT, -16
rheight:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	xor	%rax, %rax
	cmp	$NULL, %rdi
	je	1f

	mov	BinaryTreeNode.left(%rdi), %rdi
	call	rheight
	mov	%rax, LHEIGHT(%rbp)

	mov	THIS(%rbp), %rdi
	mov	BinaryTreeNode.right(%rdi), %rdi
	call	rheight

	# Take the greater of the two heights
	mov	LHEIGHT(%rbp), %rcx
	cmp	%rcx, %rax
	cmovl	%rcx, %rax

	# And add one for this call
	inc	%rax
1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	rsize
# @description	Calculate the size of the tree beneath a node (recursive)
# @param	%rdi	Pointer to a BinaryTreeNode
# @return	%rax	The size of the tree
.equ	THIS, -8
.equ	SIZE, -16
rsize:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	movq	$0, SIZE(%rbp)

	cmp	$NULL, %rdi
	je	1f

	incq	SIZE(%rbp)

	mov	BinaryTreeNode.left(%rdi), %rdi
	call	rsize
	add	%rax, SIZE(%rbp)

	mov	THIS(%rbp), %rdi
	mov	BinaryTreeNode.right(%rdi), %rdi
	call	rsize
	add	%rax, SIZE(%rbp)

1:
	mov	SIZE(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	rtraverse
# @description	Traverse all nodes below the given node, invoking a callback at each (recursive)
# @param	%rdi	Pointer to a BinaryTreeNode
# @param	%rsi	Pointer to a callback to invoke
# @return	void
.equ	THIS, -8
.equ	FUNC, -16
.equ	LEFT, -24
.equ	RIGHT, -32
rtraverse:
	cmp	$NULL, %rdi
	jne	1f

	ret

1:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, FUNC(%rbp)
	mov	BinaryTreeNode.left(%rdi), %rax
	mov	%rax, LEFT(%rbp)
	mov	BinaryTreeNode.right(%rdi), %rax
	mov	%rax, RIGHT(%rbp)

	call	*%rsi

	mov	LEFT(%rbp), %rdi
	mov	FUNC(%rbp), %rsi
	call	rtraverse

	mov	RIGHT(%rbp), %rdi
	mov	FUNC(%rbp), %rsi
	call	rtraverse

	mov	%rbp, %rsp
	pop	%rbp
	ret
