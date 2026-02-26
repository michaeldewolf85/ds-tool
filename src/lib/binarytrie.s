# lib/binarytrie.s - BinaryTrie

.include	"common.inc"

.globl	BinaryTrie_ctor, BinaryTrie_add, BinaryTrie_find, BinaryTrie_remove, BinaryTrie_log

# BinaryTrie
	.struct	0
BinaryTrie.root:
	.struct	BinaryTrie.root + 1<<3
BinaryTrie.dummy:
	.struct	BinaryTrie.dummy + 1<<3
BinaryTrie.height:
	.struct	BinaryTrie.height + 1<<2
BinaryTrie.size:
	.struct	BinaryTrie.size + 1<<2
.equ	BINARYTRIE_SIZE, .

# BinaryTrieNode
	.struct	0
BinaryTrieNode.data:
	.struct	BinaryTrieNode.data + 1<<3
BinaryTrieNode.parent:
	.struct	BinaryTrieNode.parent + 1<<3
BinaryTrieNode.left:
	.struct	BinaryTrieNode.left + 1<<3
BinaryTrieNode.right:
	.struct	BinaryTrieNode.right + 1<<3
BinaryTrieNode.jump:
	.struct	BinaryTrieNode.jump + 1<<3
.equ	BINARYTRIENODE_SIZE, .

.section .rodata

newline:
	.byte	LF, NULL
size_label:
	.ascii	"Size   => \0"
height_label:
	.ascii	"Height => \0"
list_label:
	.ascii	"List   => { <=> \0"
list_mid:
	.ascii	" <=> \0"
list_end:
	.ascii	" }\n\0"
raw_label:
	.ascii	"Raw    => {\n\0"
raw_end:
	.ascii	"}\n\0"
horz:
	.ascii	"---\0"
vert:
	.ascii	"|--\0"
spacer:
	.byte	SPACE, SPACE, SPACE, NULL
ds_delim:
	.ascii	"[\0"
de_delim:
	.ascii	"]\n\0"
star:
	.ascii	"*\0"
null:
	.ascii	"NULL\0"

.section .text

# @function	BinaryTrie_ctor
# @description	Constructor for a BinaryTrie
# @param	%rdi	Height of the tree
# @return	%rax	Pointer to the new BinaryTrie
.equ	HEIGHT, -8
.equ	ROOT, -16
.equ	DUMMY, -24
.type	BinaryTrie_ctor, @function
BinaryTrie_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, HEIGHT(%rbp)

	# Create "root" node
	mov	$NULL, %rdi
	call	BinaryTrieNode_ctor
	mov	%rax, ROOT(%rbp)

	# Create "dummy" node
	mov	$NULL, %rdi
	call	BinaryTrieNode_ctor
	mov	%rax, DUMMY(%rbp)

	# Set left/right of "dummy" to point to itself
	mov	%rax, BinaryTrieNode.left(%rax)
	mov	%rax, BinaryTrieNode.right(%rax)

	mov	$BINARYTRIE_SIZE, %rdi
	call	alloc

	mov	ROOT(%rbp), %rcx
	mov	DUMMY(%rbp), %rdx

	# Set "jump" on "root" to point to the "dummy"
	mov	%rdx, BinaryTrieNode.jump(%rcx)

	# Assign all the attributes
	mov	%rcx, BinaryTrie.root(%rax)
	mov	%rdx, BinaryTrie.dummy(%rax)
	movl	$0, BinaryTrie.size(%rax)
	mov	HEIGHT(%rbp), %rcx
	mov	%ecx, BinaryTrie.height(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinaryTrieNode_ctor
# @description	Constructor for a BinaryTrieNode
# @param	%rdi	Data value
# @return	%rax	Pointer to a new BinaryTrieNode with parent and siblings NULL
.equ	DATA, -8
BinaryTrieNode_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, DATA(%rbp)

	mov	$BINARYTRIENODE_SIZE, %rdi
	call	alloc

	mov	DATA(%rbp), %rdi
	mov	%rdi, BinaryTrieNode.data(%rax)
	movq	$NULL, BinaryTrieNode.parent(%rax)
	movq	$NULL, BinaryTrieNode.left(%rax)
	movq	$NULL, BinaryTrieNode.right(%rax)
	movq	$NULL, BinaryTrieNode.jump(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinaryTrie_find
# @description	Finds whether a given element exists in a BinaryTrie
# @param	%rdi	Pointer to a BinaryTrie
# @param	%rsi	The item to find
# @return	%rax	Finds the smallest value larger than the item or -1 on error
.type	BinaryTrie_find, @function
BinaryTrie_find:
	# Check for out of bounds
	mov	$-1, %r10
	test	%rsi, %rsi
	js	5f				# Less than 0

	mov	BinaryTrie.height(%rdi), %ecx
	mov	$1, %rdx
	shl	%cl, %rdx
	cmp	%rdx, %rsi
	jge	5f				# Greater than 2^w - 1

	mov	BinaryTrie.root(%rdi), %rax
	xor	%rdx, %rdx			# Need to use %rcx for SHR
	jmp	2f

1:
	mov	BinaryTrie.height(%rdi), %ecx
	sub	%rdx, %rcx
	dec	%rcx

	mov	%rsi, %r8
	shr	%cl, %r8
	and	$1, %r8

	# If %r8 evaluates to 1 (right) this will find the "right" element ...
	mov	BinaryTrieNode.left(%rax, %r8, 1<<3), %r9
	test	%r9, %r9
	jz	3f

	mov	%r9, %rax
	inc	%rdx

2:
	cmp	BinaryTrie.height(%rdi), %edx
	jl	1b
	je	4f

3:
	mov	BinaryTrieNode.jump(%rax), %rax
	test	%r8, %r8
	jz	4f

	mov	BinaryTrieNode.right(%rax), %rax

4:
	mov	BinaryTrieNode.data(%rax), %r10		# Put data in %r10 in case we need it

	mov	$-1, %r11
	cmp	BinaryTrie.dummy(%rdi), %rax
	cmove	%r11, %r10
	
5:
	mov	%r10, %rax
	ret

# @function	BinaryTrie_add
# @description	Adds an item to a BinaryTrie
# @param	%rdi	Pointer to a BinaryTrie
# @param	%rsi	A w-bit integer to add
# @return	%rax	The added item (w-bit integer) or NULL on failure
.equ	THIS, -8
.equ	DATA, -16
.equ	NODE, -24
.equ	CNTR, -32
.equ	SIDE, -40
.equ	PRED, -48
.type	BinaryTrie_add, @function
BinaryTrie_add:
	push	%rbp
	mov	%rsp, %rbp

	# Check for out of bounds
	xor	%rax, %rax
	test	%rsi, %rsi
	js	11f				# Less than 0

	mov	BinaryTrie.height(%rdi), %ecx
	mov	$1, %rdx
	shl	%cl, %rdx
	cmp	%rdx, %rsi			# Greater than 2^w - 1
	jge	11f

	sub	$48, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DATA(%rbp)

	mov	BinaryTrie.root(%rdi), %rax
	mov	%rax, NODE(%rbp)
	movq	$0, CNTR(%rbp)
	jmp	2f

1:
	mov	BinaryTrie.height(%rdi), %ecx
	sub	CNTR(%rbp), %rcx
	dec	%rcx

	mov	DATA(%rbp), %rax
	shr	%cl, %rax
	and	$1, %rax
	mov	%rax, SIDE(%rbp)

	// I know we are using "left" offset but his will take actually tanke "right" if %r8 is 1
	mov	NODE(%rbp), %rax
	mov	SIDE(%rbp), %rcx
	mov	BinaryTrieNode.left(%rax, %rcx, 1<<3), %rax
	test	%rax, %rax
	jz	3f

	mov	%rax, NODE(%rbp)
	incq	CNTR(%rbp)

2:
	mov	CNTR(%rbp), %rcx
	cmp	BinaryTrie.height(%rdi), %ecx
	jl	1b

3:
	# If the %rcx counter reached the lowest level it means the value was already in the tree
	# in which case we return NULL
	mov	CNTR(%rbp), %rcx
	xor	%rax, %rax
	cmp	BinaryTrie.height(%rdi), %ecx
	je	11f

	# Find the nodes' predecessor, we use the jump to look to the smallest / largest node in
	# the subtree
	mov	NODE(%rbp), %rax
	mov	BinaryTrieNode.jump(%rax), %rax

	# If the new node belongs on the left we use the left pointer to get the predecessor
	mov	SIDE(%rbp), %rcx
	test	%rcx, %rcx
	jnz	4f

	mov	BinaryTrieNode.left(%rax), %rax

4:
	mov	%rax, PRED(%rbp)

	# Once we've capture the predecessor NULL out the jump in NODE
	mov	NODE(%rbp), %rax
	movq	$NULL, BinaryTrieNode.jump(%rax)
	jmp	6f

5:
	mov	BinaryTrie.height(%rdi), %ecx
	sub	CNTR(%rbp), %rcx
	dec	%rcx

	mov	DATA(%rbp), %rax
	shr	%cl, %rax
	and	$1, %rax
	mov	%rax, SIDE(%rbp)

	mov	%rax, %rdi
	call	BinaryTrieNode_ctor
	mov	SIDE(%rbp), %rcx
	mov	NODE(%rbp), %rdx
	// I know we are using "left" offset but his will take actually tanke "right" if %r8 is 1
	mov	%rax, BinaryTrieNode.left(%rdx, %rcx, 1<<3)
	mov	%rdx, BinaryTrieNode.parent(%rax)
	mov	%rax, NODE(%rbp)
	incq	CNTR(%rbp)

6:
	# Continue to interation to place the node in the tree, adding new nodes as needed along
	# the way
	mov	CNTR(%rbp), %rcx
	mov	THIS(%rbp), %rdi
	cmp	BinaryTrie.height(%rdi), %ecx
	jl	5b
	
	# Finally we have the final node in NODE (%rax) and we can set some values on it
	mov	DATA(%rbp), %rcx
	mov	%rcx, BinaryTrieNode.data(%rax)

	# Set "prev" (left) of new node to PRED and "next" (right) of new node to PRED.next
	mov	PRED(%rbp), %rcx
	mov	%rcx, BinaryTrieNode.left(%rax)
	mov	BinaryTrieNode.right(%rcx), %rdx
	mov	%rdx, BinaryTrieNode.right(%rax)

	# Set "next" (right) and "prev" (left) of adjacent nodes to new node
	mov	BinaryTrieNode.left(%rax), %rcx
	mov	%rax, BinaryTrieNode.right(%rcx)
	mov	BinaryTrieNode.right(%rax), %rcx
	mov	%rax, BinaryTrieNode.left(%rcx)

	# Last we need to walk back up the tree and update jump pointers
	jmp	10f

7:
	cmpq	$NULL, BinaryTrieNode.left(%rax)
	jne	8f

	mov	BinaryTrieNode.jump(%rax), %rcx
	test	%rcx, %rcx
	jz	9f

	mov	BinaryTrieNode.data(%rcx), %rdx
	cmp	DATA(%rbp), %rdx
	jg	9f

8:
	cmpq	$NULL, BinaryTrieNode.right(%rax)
	jne	10f

	mov	BinaryTrieNode.jump(%rax), %rcx
	test	%rcx, %rcx
	jz	9f

	mov	BinaryTrieNode.data(%rcx), %rdx
	cmp	DATA(%rbp), %rdx
	jge	10f


9:
	mov	NODE(%rbp), %rcx
	mov	%rcx, BinaryTrieNode.jump(%rax)

10:
	mov	BinaryTrieNode.parent(%rax), %rax
	test	%rax, %rax
	jnz	7b

	mov	THIS(%rbp), %rdi
	mov	DATA(%rbp), %rsi
	incl	BinaryTrie.size(%rdi)
	mov	$TRUE, %rax

11:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinaryTrie_remove
# @description	Remove an item from a BinaryTrie
# @param	%rdi	Pointer to the BinaryTrie
# @param	%rsi	The item to remove
# @return	%rax	TRUE on success, FALSE on failure
.equ	THIS, -8
.equ	DATA, -16
.equ	NODE, -24
.equ	PRED, -32
.equ	SUCC, -40
.type	BinaryTrie_remove, @function
BinaryTrie_remove:
	push	%rbp
	mov	%rsp, %rbp

	# Check for out of bounds
	xor	%rax, %rax
	test	%rsi, %rsi
	js	9f				# Less than 0

	mov	BinaryTrie.height(%rdi), %ecx
	mov	$1, %rdx
	shl	%cl, %rdx
	cmp	%rdx, %rsi			# Greater than 2^w - 1
	jge	9f

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DATA(%rbp)

	mov	BinaryTrie.root(%rdi), %rax
	xor	%rdx, %rdx
	jmp	2f

1:
	mov	BinaryTrie.height(%rdi), %ecx
	sub	%rdx, %rcx
	dec	%rcx

	mov	DATA(%rbp), %r8
	shr	%cl, %r8
	and	$1, %r8

	# If %r8 is 1 this will actually find "right" instead of "left"
	mov	BinaryTrieNode.left(%rax, %r8, 1<<3), %rax
	test	%rax, %rax					# Node not found so return early
	jz	9f

	inc	%rdx

2:
	cmp	BinaryTrie.height(%rdi), %edx
	jl	1b

3:
	# Save the "found" node
	mov	%rax, NODE(%rbp)

	# Unlink the node from the tree
	mov	BinaryTrieNode.right(%rax), %rcx
	mov	%rcx, SUCC(%rbp)
	mov	BinaryTrieNode.left(%rax), %rdx
	mov	%rdx, PRED(%rbp)
	mov	%rcx, BinaryTrieNode.right(%rdx)
	mov	%rdx, BinaryTrieNode.left(%rcx)

	mov	BinaryTrie.height(%rdi), %edx
	jmp	5f

4:
	# Delete nodes on the path to the node
	mov	BinaryTrie.height(%rdi), %ecx
	sub	%rdx, %rcx
	dec	%rcx

	mov	DATA(%rbp), %r8
	shr	%cl, %r8
	and	$1, %r8

	push	%rax
	push	%rdx
	push	%rdi
	push	%r8
	mov	%rax, %rdi
	call	free
	pop	%r8
	pop	%rdi
	pop	%rdx
	pop	%rax

	mov	BinaryTrieNode.parent(%rax), %rax
	# If %r8 is 1 this will actually null out "right" instead of "left"
	movq	$NULL, BinaryTrieNode.left(%rax, %r8, 1<<3)

	# Check if the other child is NULL, if not we have gone far enough ...
	xor	$1, %r8						# Toggle %r8 (1 => 0 / 0 => 1)
	cmpq	$NULL, BinaryTrieNode.left(%rax, %r8, 1<<3)
	jne	6f

5:
	dec	%rdx
	test	%rdx, %rdx
	jns	4b

6:
	# Update "jump" pointers
	mov	PRED(%rbp), %rcx
	cmpq	$NULL, BinaryTrieNode.left(%rax)
	cmove	SUCC(%rbp), %rcx

	mov	%rcx, BinaryTrieNode.jump(%rax)
	jmp	8f

7:
	mov	BinaryTrieNode.jump(%rax), %rcx
	cmp	NODE(%rbp), %rcx
	jne	8f

	mov	PRED(%rbp), %rcx
	cmpq	$NULL, BinaryTrieNode.left(%rax)
	cmove	SUCC(%rbp), %rcx
	mov	%rcx, BinaryTrieNode.jump(%rax)

8:
	mov	BinaryTrieNode.parent(%rax), %rax
	test	%rax, %rax
	jnz	7b

	mov	THIS(%rbp), %rdi
	decl	BinaryTrie.size(%rdi)
	mov	$TRUE, %rax

9:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinaryTrie_log
# @description	Log the innards of a BinaryTrie
# @param	%rdi	Pointer to a BinaryTrie
# @return	void
.equ	THIS, -8
.equ	TEMP, -16
.type	BinaryTrie_log, @function
BinaryTrie_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$height_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	BinaryTrie.height(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$size_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	BinaryTrie.size(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$list_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	BinaryTrie.dummy(%rdi), %rax
	mov	%rax, TEMP(%rbp)
	jmp	2f

1:
	mov	BinaryTrieNode.data(%rax), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$list_mid, %rdi
	call	log

	mov	THIS(%rbp), %rdi
2:
	mov	TEMP(%rbp), %rax
	mov	BinaryTrieNode.right(%rax), %rax
	mov	%rax, TEMP(%rbp)
	cmp	BinaryTrie.dummy(%rdi), %rax
	jne	1b

	mov	$list_end, %rdi
	call	log

	mov	$raw_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	BinaryTrie.height(%rdi), %ecx
	mov	BinaryTrie.root(%rdi), %rdi
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
# @param	%rdi	Pointer to the BinaryTrieTreeNode to log
# @param	%rsi	The depth of the node
# @param	%rdx	The max depth
# @return	void
.equ	THIS, -8
.equ	DPTH, -16
.equ	LIMT, -24
.equ	NODE, -32
.equ	TEMP, -40
log_node:
	push	%rbp
	mov	%rsp, %rbp

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DPTH(%rbp)
	mov	%rdx, LIMT(%rbp)

	mov	$spacer, %rdi
	call	log

	mov	DPTH(%rbp), %rsi
	test	%rsi, %rsi
	jz	2f

	mov	DPTH(%rbp), %rax
	mov	%rax, TEMP(%rbp)
	mov	$vert, %rdi
	call	log

1:
	cmpq	$1, TEMP(%rbp)
	jle	2f

	mov	$horz, %rdi
	call	log
	decq	TEMP(%rbp)
	jmp	1b

2:
	mov	$ds_delim, %rdi
	call	log
	
	mov	LIMT(%rbp), %rax
	cmp	DPTH(%rbp), %rax
	je	9f

	mov	THIS(%rbp), %rax
	mov	%rax, NODE(%rbp)
	jmp	4f

3:
	mov	BinaryTrieNode.data(%rax), %rdi
	push	%rdi
	mov	BinaryTrieNode.parent(%rax), %rax

4:
	cmpq	$NULL, BinaryTrieNode.parent(%rax)
	jne	3b

	mov	DPTH(%rbp), %rax
	mov	%rax, TEMP(%rbp)
	jmp	6f
	
5:
	pop	%rdi
	call	itoa
	mov	%rax, %rdi
	call	log
	decq	TEMP(%rbp)

6:
	mov	TEMP(%rbp), %rax
	test	%rax, %rax
	jnz	5b

	mov	LIMT(%rbp), %rax
	sub	DPTH(%rbp), %rax
	mov	%rax, TEMP(%rbp)
	jmp	8f

7:
	mov	$star, %rdi
	call	log
	decq	TEMP(%rbp)

8:
	mov	TEMP(%rbp), %rax
	test	%rax, %rax
	jnz	7b

	jmp	11f

9:
	mov	THIS(%rbp), %rdi
	test	%rdi, %rdi
	jnz	10f

	mov	$null, %rdi
	call	log
	jmp	11f

10:
	mov	BinaryTrieNode.data(%rdi), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

11:
	mov	$de_delim, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	traverse
# @description	File private helper to traverse the subtree at a given node and invoke a callback
# @param	%rdi	Pointer to the root of a subtree to traverse (BinaryTrieNode)
# @param	%rsi	Pointer to a callback. Callback will recieve the node in %rdi
# @param	%rdx	The depth
# @param	%rcx	Limit depth
# @return	void
.equ	THIS, -8
.equ	FUNC, -16
.equ	DPTH, -24
.equ	LMT, -32
traverse:
	push	%rbp
	mov	%rsp, %rbp

	cmp	%rcx, %rdx
	jg	1f

	test	%rdi, %rdi
	jz	1f

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, FUNC(%rbp)
	mov	%rdx, DPTH(%rbp)
	mov	%rcx, LMT(%rbp)

	mov	%rdx, %rsi
	mov	%rcx, %rdx
	call	*FUNC(%rbp)

	mov	THIS(%rbp), %rdi
	mov	DPTH(%rbp), %rsi
	test	%rdi, %rdi
	jz	1f

	incq	DPTH(%rbp)

	mov	FUNC(%rbp), %rsi
	mov	DPTH(%rbp), %rdx
	mov	LMT(%rbp), %rcx
	mov	BinaryTrieNode.left(%rdi), %rdi
	call	traverse

	mov	THIS(%rbp), %rdi
	mov	FUNC(%rbp), %rsi
	mov	DPTH(%rbp), %rdx
	mov	LMT(%rbp), %rcx
	mov	BinaryTrieNode.right(%rdi), %rdi
	call	traverse

1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

