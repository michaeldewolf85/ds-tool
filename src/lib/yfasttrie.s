# lib/yfasttrie.s - YFastTrie

.include	"common.inc"

.globl	YFastTrie_ctor, YFastTrie_add

.equ	NIL, 0
.equ	FALSE, 0
.equ	TRUE, 1

# YFastTrie
	.struct	0
YFastTrie.xft:
	.struct	YFastTrie.xft + 1<<3
.equ	YFASTTRIE_SIZE, .

# YTreap
	.struct	0
YTreap.rt:
	.struct	YTreap.rt + 1<<3
.equ	YTREAP_SIZE, .

# YTreapNode
	.struct	0
YTreapNode.key:
	.struct	YTreapNode.key + 1<<2
YTreapNode.rnk:
	.struct	YTreapNode.rnk + 1<<2
YTreapNode.prt:
	.struct	YTreapNode.prt + 1<<3
YTreapNode.lft:
	.struct	YTreapNode.lft + 1<<3
YTreapNode.rgt:
	.struct	YTreapNode.rgt + 1<<3
.equ	YTREAPNODE_SIZE, .

.section .rodata

ytreap_start:
	.ascii	"{\n\0"
ytreap_end:
	.ascii	"}\n\0"
ytreap_key_start:
	.ascii	"[\0"
ytreap_key_end:
	.ascii	"]\n\0"
vert:
	.ascii	"|--\0"
horz:
	.ascii	"---\0"
delim:
	.ascii	"|*\0"
indent:
	.byte	SPACE, SPACE, SPACE, NULL
newline:
	.byte	LF, NULL
nil:
	.ascii	"NIL\0"

.section .text

# @public
# @function	YFastTrie_ctor
# @description	Constructor for a YFastTrie
# @param	%rdi	Height of the tree
# @return	%rax	Pointer to a new YFastTrie
.type	YFastTrie_ctor, @function
YFastTrie_ctor:
	call	XFastTrie_ctor
	push	%rax

	mov	$YFASTTRIE_SIZE, %rdi
	call	alloc

	pop	%rcx
	mov	%rcx, YFastTrie.xft(%rax)
	ret

# @public
# @function	YFastTrie_add
# @description	Adds an element to a YFastTrie
# @param	%rdi	YFastTrie
# @param	%rsi	Key to add
# @return	%rax	TRUE on success, FALSE on failure
.equ	THIS, -8
.equ	DATA, -16
.type	YFastTrie_add, @function
YFastTrie_add:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DATA(%rbp)

	mov	YFastTrie.xft(%rdi), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public
# @function	YTreap_ctor
# @description	Constructor for a YTreap
# @return	%rax	YTreap
YTreap_ctor:
	mov	$YTREAP_SIZE, %rdi
	call	alloc
	movq	$NIL, YTreap.rt(%rax)
	ret

# @public
# @function	YTreap_find
# @description	Find the smallest key in the set which is greater than or equal to the specified or
#		NIL
# @param	%rdi	YTreap
# @param	%rsi	Search key
# @return	%rax	The key
YTreap_find:
	call	_YTreap_find_last
	test	%rax, %rax
	jz	1f

	# We want to return NIL if the found value is LESS THAN the search key
	xor	%rcx, %rcx
	cmp	YTreapNode.key(%rax), %esi
	cmovle	YTreapNode.key(%rax), %eax
	cmovg	%rcx, %rax

1:
	ret

# @public
# @function	YTreap_add
# @description	Adds a key to the Treap SSet
# @param	%rdi	YTreap
# @param	%esi	Key to add
# @return	%rax	TRUE on success, FALSE on failure
YTreap_add:
	call	_YTreap_find_last
	test	%rax, %rax
	jz	1f

	cmp	YTreapNode.key(%rax), %esi
	jne	1f
	
	# Node is already in the tree
	xor	%rax, %rax
	ret

1:
	push	%rax			# Successor node
	call	YTreapNode_ctor
	pop	%rcx			# Successor node in %rcx

	test	%rcx, %rcx
	jnz	2f

	mov	%rax, YTreap.rt(%rdi)
	jmp	4f

2:
	cmp	YTreapNode.key(%rcx), %esi
	jg	3f

	mov	%rax, YTreapNode.lft(%rcx)
	jmp	4f

3:
	mov	%rax, YTreapNode.rgt(%rcx)

4:
	mov	%rcx, YTreapNode.prt(%rax)

	push	%rsi
	mov	%rax, %rsi
	call	_YTreap_bubble_up
	pop	%rsi

	mov	$TRUE, %rax
	ret

# @public
# @function	YTreap_remove
# @param	%rdi	YTreap
# @param	%rsi	A search key to remove
# @return	%rax	TRUE on success, FALSE on failure
YTreap_remove:
	call	_YTreap_find_last
	test	%rax, %rax
	jz	1f

	cmp	YTreapNode.key(%rax), %esi
	je	2f

1:
	# Key was not found
	xor	%rax, %rax
	ret

2:
	mov	%rax, %rsi
	call	_YTreap_trickle_down
	call	_YTreap_splice

	push	%rdi
	push	%rsi
	mov	%rsi, %rdi
	call	free

	pop	%rsi
	pop	%rdi
	mov	$TRUE, %rax
	ret

# @public
# @function	YTreap_split
# @description	Removes all nodes from the YTreap that have keys GREATER THAN specified and return
#		a new YTreap which contains all the removed nodes
# @param	%rdi	YTreap
# @param	%rsi	Search key
# @return	%rax	YTreap
.equ	THIS, -8
.equ	SKEY, -16
.equ	SUCC, -24
.equ	ROOT, -32
.equ	NEWT, -40
YTreap_split:
	push	%rbp
	mov	%rsp, %rbp

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, SKEY(%rbp)

	call	_YTreap_find_last
	mov	%rax, SUCC(%rbp)
	
	# Create a psuedo node with a negative priority so it will bubble to the top of the tree
	call	YTreapNode_ctor
	mov	%rax, ROOT(%rbp)

	mov	%rax, %rsi
	mov	SUCC(%rbp), %rax
	# If the right child of the successor node is nil we just add 
	cmpq	$NIL, YTreapNode.rgt(%rax)
	jne	1f

	mov	%rsi, YTreapNode.rgt(%rax)
	jmp	3f

1:
	mov	YTreapNode.rgt(%rax), %rax

2:
	cmpq	$NIL, YTreapNode.lft(%rax)
	cmovne	YTreapNode.lft(%rax), %rax
	jne	2f

	mov	%rsi, YTreapNode.lft(%rax)

3:
	mov	%rax, YTreapNode.prt(%rsi)
	movl	$-(1<<31), YTreapNode.rnk(%rsi)

	call	_YTreap_bubble_up
	call	YTreap_ctor
	mov	%rax, NEWT(%rbp)

	mov	THIS(%rbp), %rcx
	mov	ROOT(%rbp), %rdi

	# Set root on OLD YTreap
	mov	YTreapNode.lft(%rdi), %rdx
	test	%rdx, %rdx
	jz	4f

	movq	$NIL, YTreapNode.prt(%rdx)

4:
	mov	%rdx, YTreap.rt(%rcx)

	# Set root on NEW YTreap
	mov	YTreapNode.rgt(%rdi), %rdx
	test	%rdx, %rdx
	jz	5f

	movq	$NIL, YTreapNode.prt(%rdx)

5:
	mov	%rdx, YTreap.rt(%rax)

	call	free

	mov	THIS(%rbp), %rdi
	mov	SKEY(%rbp), %rsi
	mov	NEWT(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public
# @function	YTreap_absorb
# @description	Absorb all elements from another YTreap into this. Assumes all elements are smaller
#		than any in this
# @param	%rdi	YTreap (this)
# @param	%rsi	YTreap (to absorb)
# @return	void
.equ	THIS, -8
.equ	THAT, -16
.equ	ROOT, -24
YTreap_absorb:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, THAT(%rbp)

	call	YTreapNode_ctor
	mov	%rax, %rsi
	mov	YTreap.rt(%rdi), %rax
	mov	%rax, YTreapNode.rgt(%rsi)
	test	%rax, %rax
	jz	1f

	mov	%rsi, YTreapNode.prt(%rax)

1:
	mov	THAT(%rbp), %rdi
	mov	YTreap.rt(%rdi), %rax
	mov	%rax, YTreapNode.lft(%rsi)
	test	%rax, %rax
	jz	2f

	mov	%rsi, YTreapNode.prt(%rax)

2:
	mov	THIS(%rbp), %rdi
	mov	%rsi, YTreap.rt(%rdi)
	call	_YTreap_trickle_down
	call	_YTreap_splice

	# Free the psuedo node
	mov	%rsi, %rdi
	call	free

	mov	THAT(%rbp), %rdi
	call	free

	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public
# @function	YTreap_log
# @description	Logs the innards of a YTreap
# @param	%rdi	YTreap
# @return	void
.equ	THIS, -8
YTreap_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$ytreap_start, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	YTreap.rt(%rdi), %rdi
	mov	$YTreapNode_log, %rsi
	xor	%rcx, %rcx
	call	_YTreap_traverse

	mov	$ytreap_end, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private
# @function	YTreapNode_log
# @description	Logs the innards of a YTreapNode
# @param	%rdi	YTreapNode
# @param	%rsi	Depth
# @return	void
.equ	NODE, -8
.equ	DPTH, -16
YTreapNode_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, NODE(%rbp)
	mov	%rsi, DPTH(%rbp)
	
	mov	$indent, %rdi
	call	log

	cmpq	$0, DPTH(%rbp)
	jle	4f

	mov	$vert, %rdi
	call	log
	jmp	2f

1:
	mov	$horz, %rdi
	call	log

2:
	decq	DPTH(%rbp)
	cmpq	$0, DPTH(%rbp)
	jg	1b

4:
	mov	$ytreap_key_start, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	test	%rdi, %rdi
	jnz	5f

	mov	$nil, %rdi
	call	log
	jmp	6f

5:
	mov	YTreapNode.key(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$delim, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	YTreapNode.rnk(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

6:
	mov	$ytreap_key_end, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private
# @function	_YTreap_traverse
# @description	Traverse the subtree of a YTreapNode, invoking a callback for each node
# @param	%rdi	YTreapNode
# @param	%rsi	Callback
# @param	%rcx	Current depth
# @return	void
.equ	NODE, -8
.equ	FUNC, -16
.equ	DPTH, -24
_YTreap_traverse:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, NODE(%rbp)
	mov	%rsi, FUNC(%rbp)
	mov	%rcx, DPTH(%rbp)


	mov	%rcx, %rsi
	call	*FUNC(%rbp)

	incq	DPTH(%rbp)

	mov	NODE(%rbp), %rdi
	mov	FUNC(%rbp), %rsi
	mov	DPTH(%rbp), %rcx
	test	%rdi, %rdi
	jz	1f

	mov	YTreapNode.lft(%rdi), %rdi
	call	_YTreap_traverse

	mov	NODE(%rbp), %rdi
	mov	FUNC(%rbp), %rsi
	mov	DPTH(%rbp), %rcx
	mov	YTreapNode.rgt(%rdi), %rdi
	call	_YTreap_traverse

1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private
# @function	_YTreap_find_last
# @description	Returns either the node associated with a key OR the last leaf node encountered on
#		the search path for that key
# @param	%rdi	YTreap
# @param	%esi	Search key
# @return	%rax	YTreapNode
_YTreap_find_last:
	xor	%rax, %rax
	mov	YTreap.rt(%rdi), %rcx
	jmp	3f

1:
	mov	%rcx, %rax
	cmp	YTreapNode.key(%rcx), %esi

	je	4f
	jg	2f

	mov	YTreapNode.lft(%rcx), %rcx
	jmp	3f

2:
	mov	YTreapNode.rgt(%rcx), %rcx

3:
	test	%rcx, %rcx
	jnz	1b

3:
	ret

# @private	
# @function	_YTreap_splice
# @description	Splice a node with a NIL child from the tree
# @param	%rdi	YTreap
# @param	%rsi	YTreapNode
# @return	void
_YTreap_splice:
	mov	YTreapNode.lft(%rsi), %rax
	test	%rax, %rax
	cmovz	YTreapNode.rgt(%rsi), %rax

	# If the target is the root than we set the root to one of the children
	cmp	YTreap.rt(%rdi), %rsi
	jne	1f

	mov	%rax, YTreap.rt(%rdi)
	xor	%rcx, %rcx
	jmp	3f

1:
	# If the target is NOT the root we replace it with one of the children
	mov	YTreapNode.prt(%rsi), %rcx
	cmp	YTreapNode.lft(%rcx), %rsi
	jne	2f

	mov	%rax, YTreapNode.lft(%rcx)
	jmp	3f

2:
	mov	%rax, YTreapNode.rgt(%rcx)

3:
	test	%rax, %rax
	jz	4f

	mov	%rcx, YTreapNode.prt(%rax)

4:
	ret

# @private	
# @function	_YTreap_bubble_up
# @description	Move the target node UP in the tree until it satisfies the heap property
# @param	%rdi	YTreap
# @param	%rsi	YTreapNode
# @return	void
_YTreap_bubble_up:
	# If we are making calls to rotate it will be with the target's parent so we need %rsi free
	mov	%rsi, %rax

1:
	# If the target is the root we perform no rotations
	cmp	YTreap.rt(%rdi), %rax
	je	4f

	# If the rank of the parent is <= the target we perform no rotations
	mov	YTreapNode.prt(%rax), %rsi
	mov	YTreapNode.rnk(%rsi), %ecx
	cmp	YTreapNode.rnk(%rax), %ecx
	jle	4f

	# Determine whether the target is a right (rotate left) or left (rotate right) child
	cmp	YTreapNode.rgt(%rsi), %rax
	jne	2f

	call	_YTreap_rotate_left
	jmp	3f

2:
	call	_YTreap_rotate_right

3:
	# In either case the target ends up as the parent of %rsi
	mov	YTreapNode.prt(%rsi), %rax
	jmp	1b
	
4:
	ret

# @private	
# @function	_YTreap_trickle_down
# @description	Move the target node DOWN in the tree until it becomes a leaf WITHOUT violating the
#		heap property
# @param	%rdi	YTreap
# @param	%rsi	YTreapNode
# @return	void
_YTreap_trickle_down:
	cmpq	$NIL, YTreapNode.lft(%rsi)
	jne	1f

	cmpq	$NIL, YTreapNode.rgt(%rsi)
	jne	1f

	# Once both children are nil we are done
	ret

1:
	# If the left child is NIL we rotate left
	cmpq	$NIL, YTreapNode.lft(%rsi)
	je	2f

	# If the right child is NIL we rotate right
	cmpq	$NIL, YTreapNode.rgt(%rsi)
	je	3f

	# If the rank of the left child is less than the rank on the right child we rotate right
	mov	YTreapNode.lft(%rsi), %rax
	mov	YTreapNode.rnk(%rax), %eax
	mov	YTreapNode.rgt(%rsi), %rcx
	cmp	YTreapNode.rnk(%rcx), %eax
	jl	3f

	# In all other cases we rotate left
2:
	call	_YTreap_rotate_left
	jmp	4f

3:
	call	_YTreap_rotate_right
	
4:
	cmp	YTreap.rt(%rdi), %rsi
	jne	5f

	mov	YTreapNode.prt(%rsi), %rax
	mov	%rax, YTreap.rt(%rdi)

5:
	jmp	_YTreap_trickle_down

# @private
# @function	_YTreap_rotate_left
# @description	Performs a left rotation on the target node
# @param	%rdi	YTreap
# @param	%rsi	YTreapNode
# @return	void
_YTreap_rotate_left:
	# Transfer parent to right child
	mov	YTreapNode.rgt(%rsi), %rax
	mov	YTreapNode.prt(%rsi), %rcx
	mov	%rcx, YTreapNode.prt(%rax)

	test	%rcx, %rcx
	jz	2f

	# Update child mapping on parent
	cmp	%rsi, YTreapNode.lft(%rcx)
	jne	1f

	# Set a left child
	mov	%rax, YTreapNode.lft(%rcx)
	jmp	2f

1:
	# Set a right child
	mov	%rax, YTreapNode.rgt(%rcx)

2:
	# Transfer left child of new parent to be right child of the target
	mov	YTreapNode.lft(%rax), %rcx
	mov	%rcx, YTreapNode.rgt(%rsi)

	test	%rcx, %rcx
	jz	3f

	mov	%rsi, YTreapNode.prt(%rcx)

3:
	# Make target a left child of the new parent
	mov	%rax, YTreapNode.prt(%rsi)
	mov	%rsi, YTreapNode.lft(%rax)

	# Update Treap root (if necessary)
	cmp	%rsi, YTreap.rt(%rdi)
	jne	4f

	mov	%rax, YTreap.rt(%rdi)

4:
	ret

# @private
# @function	_YTreap_rotate_right
# @description	Performs a right rotation on the target node
# @param	%rdi	YTreap
# @param	%rsi	YTreapNode
# @return	void
_YTreap_rotate_right:
	# Transfer parent to right child
	mov	YTreapNode.lft(%rsi), %rax
	mov	YTreapNode.prt(%rsi), %rcx
	mov	%rcx, YTreapNode.prt(%rax)

	test	%rcx, %rcx
	jz	2f

	# Update child mapping on parent
	cmp	%rsi, YTreapNode.lft(%rcx)
	jne	1f

	# Set a left child
	mov	%rax, YTreapNode.lft(%rcx)
	jmp	2f

1:
	# Set a right child
	mov	%rax, YTreapNode.rgt(%rcx)

2:
	# Transfer right child of new parent to be left child of the target
	mov	YTreapNode.rgt(%rax), %rcx
	mov	%rcx, YTreapNode.lft(%rsi)

	test	%rcx, %rcx
	jz	3f

	mov	%rsi, YTreapNode.prt(%rcx)

3:
	# Make target a right child of the new parent
	mov	%rax, YTreapNode.prt(%rsi)
	mov	%rsi, YTreapNode.rgt(%rax)

	# Update Treap root (if necessary)
	cmp	%rsi, YTreap.rt(%rdi)
	jne	4f

	mov	%rax, YTreap.rt(%rdi)

4:
	ret

# @function	YTreapNode_ctor
# @description	Constructor for a YTreapNode
# @param	%rdi	YTreap
# @param	%esi	Key
# @return	%rax	YTreapNode
YTreapNode_ctor:
	push	%rdi
	push	%rsi

	mov	$YTREAPNODE_SIZE, %rdi
	call	alloc

1:
	rdrand	%di
	jnc	1b

	movzbl	%dil, %edi
	movl	%edi, YTreapNode.rnk(%rax)

	pop	%rsi
	pop	%rdi
	mov	%esi, YTreapNode.key(%rax)
	movq	$NIL, YTreapNode.prt(%rax)
	movq	$NIL, YTreapNode.lft(%rax)
	movq	$NIL, YTreapNode.rgt(%rax)

	ret
