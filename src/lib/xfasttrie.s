# lib/xfasttrie.s - XFastTrie

.include	"common.inc"

.globl	XFastTrie_add, XFastTrie_ctor, XFastTrie_find, XFastTrie_log, XFastTrie_remove

# XFastTrie
	.struct	0
XFastTrie.root:
	.struct	XFastTrie.root + 1<<3
XFastTrie.list:
	.struct	XFastTrie.list + 1<<3
XFastTrie.hash:
	.struct	XFastTrie.hash + 1<<3
XFastTrie.size:
	.struct	XFastTrie.size + 1<<2
XFastTrie.hght:
	.struct	XFastTrie.hght + 1<<2
.equ	XFASTTRIE_SIZE, .

# XFastTrieNode
	.struct	0
XFastTrieNode.data:
	.struct	XFastTrieNode.data + 1<<3
XFastTrieNode.prnt:
	.struct	XFastTrieNode.prnt + 1<<3
XFastTrieNode.left:
	.struct	XFastTrieNode.left + 1<<3
XFastTrieNode.rght:
	.struct	XFastTrieNode.rght + 1<<3
XFastTrieNode.jump:
	.struct	XFastTrieNode.jump + 1<<3
.equ	XFASTTRIENODE_SIZE, .

# XPair
	.struct	0
XPair.key:
	.struct	XPair.key + 1<<3
XPair.val:
	.struct	XPair.val + 1<<3
.equ	XPAIR_SIZE, .

# XHashTable
	.struct	0
XHashTable.tab:
	.struct	XHashTable.tab + 1<<3
XHashTable.dim:
	.struct	XHashTable.dim + 1<<3
XHashTable.len:
	.struct	XHashTable.len + 1<<2
XHashTable.use:
	.struct	XHashTable.use + 1<<2
.equ	XHASHTABLE_SIZE, .

.equ	XHASHTABLE_START_DIM, 1
.equ	XHASHTABLE_NIL, -1
.equ	XHASHTABLE_DEL, -2

.section .rodata

newline:
	.byte	LF, NULL
size_label:
	.ascii	"Size   => \0"
height_label:
	.ascii	"Height => \0"
list_label:
	.ascii	"LList  => { <=> \0"
list_mid:
	.ascii	" <=> \0"
list_end:
	.ascii	" }\n\0"
hash_label:
	.ascii	"Hash   => {\n\0"
hkeyp:
	.ascii	"[\0"
hkeys:
	.ascii	"] => [ \0"
hrowdelim:
	.ascii	", \0"
hrowend:
	.ascii	" ]\n\0"
hash_end:
	.ascii	"}\n\0"
hidelims:
	.ascii	" (\0"
hidelime:
	.ascii	")\0"
raw_label:
	.ascii	"Trie   => {\n\0"
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

.section .bss

# Tabulation hash table
.equ	HASH_KEY_BITS, 32
.equ	HASH_CHUNK_BITS, 8
tab:
	.zero	1<<(HASH_CHUNK_BITS + (HASH_KEY_BITS / HASH_CHUNK_BITS))
.equ	TAB_SIZE, . - tab

.section .text

# @function	XFastTrie_ctor
# @description	Constructor for an XFastTrie
# @param	%rdi	The height of the XFastTrie
# @return	%rax	Pointer to a new XFastTrie
.equ	HGHT, -8
.equ	LIST, -16
.equ	ROOT, -24
.equ	HASH, -32
.equ	CNTR, -40
.type	XFastTrie_ctor, @function
XFastTrie_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$40, %rsp
	mov	%rdi, HGHT(%rbp)

	# Create the list node. Left and right of list node initially are a self-reference
	mov	$NULL, %rdi
	call	XFastTrieNode_ctor

	mov	%rax, XFastTrieNode.left(%rax)
	mov	%rax, XFastTrieNode.rght(%rax)
	mov	%rax, LIST(%rbp)

	# Create the root node. Initially since root has no children jump points to the list node
	call	XFastTrieNode_ctor

	mov	LIST(%rbp), %rcx
	mov	%rcx, XFastTrieNode.jump(%rax)
	mov	%rax, ROOT(%rbp)

	# Allocate the hash tables
	mov	HGHT(%rbp), %rdi
	mov	%rdi, CNTR(%rbp)
	inc	%rdi
	shl	$3, %rdi
	call	alloc
	mov	%rax, HASH(%rbp)
	jmp	2f

1:
	call	XHashTable_ctor
	mov	CNTR(%rbp), %rcx
	mov	HASH(%rbp), %rdx
	mov	%rax, (%rdx, %rcx, 1<<3)
	decq	CNTR(%rbp)

2:
	cmpq	$0, CNTR(%rbp)
	jge	1b

	# Allocate the XFastTrie
	mov	$XFASTTRIE_SIZE, %rdi
	call	alloc

	mov	LIST(%rbp), %rcx
	mov	%rcx, XFastTrie.list(%rax)
	mov	ROOT(%rbp), %rcx
	mov	%rcx, XFastTrie.root(%rax)
	mov	HASH(%rbp), %rcx
	mov	%rcx, XFastTrie.hash(%rax)
	movl	$0, XFastTrie.size(%rax)
	mov	HGHT(%rbp), %rcx
	mov	%ecx, XFastTrie.hght(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	XFastTrie_find
# @description	Find an item in an XFastTrie
# @param	%rdi	Pointer to an XFastTrie
# @param	%rsi	The item to find
# @return	%rax	The item on success or NULL on failure
.equ	THIS, -8
.equ	ITEM, -16
.equ	NODE, -24
.equ	LOW, -32
.equ	HGH, -40
.equ	LVL, -48
.equ	KEY, -56
.type	XFastTrie_find, @function
XFastTrie_find:
	push	%rbp
	mov	%rsp, %rbp

	sub	$56, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, ITEM(%rbp)

	movq	$0, LOW(%rbp)
	mov	XFastTrie.hght(%rdi), %eax
	inc	%rax
	mov	%rax, HGH(%rbp)

	mov	XFastTrie.root(%rdi), %rax
	mov	%rax, NODE(%rbp)
	jmp	3f

1:
	mov	HGH(%rbp), %rcx
	add	%rcx, %rdx
	shr	$1, %rdx
	mov	%rdx, LVL(%rbp)

	mov	XFastTrie.hght(%rdi), %ecx
	sub	%rdx, %rcx
	shr	%cl, %rsi
	mov	%rsi, KEY(%rbp)

	mov	XFastTrie.hash(%rdi), %rdi
	mov	(%rdi, %rdx, 1<<3), %rdi
	lea	KEY(%rbp), %rsi
	call	XHashTable_find

	# Restore some quantities
	mov	THIS(%rbp), %rdi
	mov	ITEM(%rbp), %rsi

	test	%rax, %rax
	jnz	2f

	mov	NODE(%rbp), %rax
	mov	LVL(%rbp), %rdx
	mov	%rdx, HGH(%rbp)
	jmp	3f

2:
	mov	XPair.val(%rax), %rax
	mov	%rax, NODE(%rbp)
	mov	LVL(%rbp), %rdx
	mov	%rdx, LOW(%rbp)

3:
	mov	HGH(%rbp), %rcx
	mov	LOW(%rbp), %rdx
	sub	%rdx, %rcx
	cmp	$1, %rcx
	jg	1b
	
	# If the low reaches the height of the tree we know we have found our node
	mov	XFastTrie.hght(%rdi), %ecx
	cmp	%rcx, %rdx
	je	4f

	# Otherwise we still have some work to do ... Determine if this is a left/right child
	sub	%rdx, %rcx
	dec	%rcx
	shr	%cl, %rsi
	and	$1, %rsi

	mov	XFastTrieNode.jump(%rax), %rax
	# If our target is a left child we can find the predecessor at prev
	test	%rsi, %rsi
	cmovz	XFastTrieNode.left(%rax), %rax

	# Return value is predecessor (right/next)
	mov	XFastTrieNode.rght(%rax), %rax

4:
	test	%rax, %rax
	cmovnz	XFastTrieNode.data(%rax), %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	XFastTrie_add
# @description	Add an item to an XFastTrie
# @param	%rdi	Pointer to an XFastTrie to add to
# @param	%rsi	The item to add
# @return	%rax	TRUE on success, NIL on failure
.equ	THIS, -8
.equ	ITEM, -16
.equ	NODE, -24
.equ	LEVL, -32
.equ	SIDE, -40
.equ	PRED, -48
.equ	HKEY, -56
.type	XFastTrie_add, @function
XFastTrie_add:
	push	%rbp
	mov	%rsp, %rbp

	sub	$56, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, ITEM(%rbp)
	
	mov	XFastTrie.root(%rdi), %rax
	xor	%rdx, %rdx
	jmp	2f

1:
	sub	%rdx, %rcx
	dec	%rcx

	mov	%rsi, %r8
	shr	%cl, %r8
	and	$1, %r8

	# This will find the "right" child if %r8 is one
	mov	XFastTrieNode.left(%rax, %r8, 1<<3), %rcx
	test	%rcx, %rcx
	jz	3f

	mov	%rcx, %rax
	inc	%rdx

2:
	mov	XFastTrie.hght(%rdi), %ecx
	cmp	%rcx, %rdx
	jl	1b

3:
	mov	$FALSE, %rcx
	cmp	XFastTrie.hght(%rdi), %edx
	cmove	%rcx, %rax
	je	10f

	# Find predecessor in the linked list. This depends on whether the search path proceeded 
	# left or right before reaching a null child. If we proceeded left, jump points at the
	# the smallest leaf in u's subtree but the new node is smaller (so we do jump.prev). If
	# we proceeded right, jump points to the largest node in u's subtree but our node is bigger
	# so we are good with just jump
	mov	XFastTrieNode.jump(%rax), %rcx
	test	%r8, %r8
	cmovz	XFastTrieNode.left(%rcx), %rcx

	# The node in %rax will soon have two children
	movq	$NULL, XFastTrieNode.jump(%rax)

	mov	%rax, NODE(%rbp)
	mov	%rcx, PRED(%rbp)
	mov	%rdx, LEVL(%rbp)
	jmp	5f

4:
	# Add in missing nodes to fill out the tree
	sub	LEVL(%rbp), %rcx
	dec	%rcx

	mov	ITEM(%rbp), %rdi
	shr	%cl, %rdi
	mov	%rdi, HKEY(%rbp)
	and	$1, %rdi
	mov	%rdi, SIDE(%rbp)

	call	XFastTrieNode_ctor
	mov	NODE(%rbp), %rcx
	mov	SIDE(%rbp), %rdx
	# This will find the "right" child if %rdi is one
	mov	%rax, XFastTrieNode.left(%rcx, %rdx, 1<<3)
	mov	%rcx, XFastTrieNode.prnt(%rax)
	mov	%rax, NODE(%rbp)

	# Create an XPair for the new node and add it to the appropriate hash table
	mov	HKEY(%rbp), %rdi
	mov	%rax, %rsi
	call	XPair_ctor

	mov	THIS(%rbp), %rdi
	mov	XFastTrie.hash(%rdi), %rdi
	mov	LEVL(%rbp), %rcx
	inc	%rcx
	mov	(%rdi, %rcx, 1<<3), %rdi
	mov	%rax, %rsi
	call	XHashTable_add

	mov	THIS(%rbp), %rdi
	incq	LEVL(%rbp)

5:
	mov	XFastTrie.hght(%rdi), %ecx
	cmp	%rcx, LEVL(%rbp)
	jl	4b

	mov	THIS(%rbp), %rdi
	mov	ITEM(%rbp), %rsi
	mov	NODE(%rbp), %rax
	mov	%rsi, XFastTrieNode.data(%rax)

	mov	PRED(%rbp), %rcx
	mov	%rcx, XFastTrieNode.left(%rax)		# u.prev <= pred
	mov	XFastTrieNode.rght(%rcx), %rdx
	mov	%rdx, XFastTrieNode.rght(%rax)		# u.next <= pred.next
	mov	%rax, XFastTrieNode.rght(%rcx)		# u.prev.next <= u
	mov	%rax, XFastTrieNode.left(%rdx)		# u.next.prev <= u
	jmp	9f

6:
	cmpq	$NULL, XFastTrieNode.left(%rax)
	jne	7f

	mov	XFastTrieNode.jump(%rax), %rcx
	test	%rcx, %rcx
	jz	8f

	cmp	%rsi, XFastTrieNode.data(%rcx)
	jg	8f

7:
	cmpq	$NULL, XFastTrieNode.rght(%rax)
	jne	9f

	mov	XFastTrieNode.jump(%rax), %rcx
	test	%rcx, %rcx
	jz	8f

	cmp	%rsi, XFastTrieNode.data(%rcx)
	jl	8f

8:
	mov	NODE(%rbp), %rcx
	mov	%rcx, XFastTrieNode.jump(%rax)

9:
	mov	XFastTrieNode.prnt(%rax), %rax
	test	%rax, %rax
	jnz	6b

	incl	XFastTrie.size(%rdi)
	mov	$TRUE, %rax

10:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	XFastTrie_remove
# @description	Remove an item from an XFastTrie
# @param	%rdi	Pointer to an XFastTrie
# @param	%rsi	The item to remove
# @return	%rax	TRUE on success, FALSE on failure
.equ	THIS, -8
.equ	ITEM, -16
.equ	NODE, -24
.equ	PRED, -32
.equ	SUCC, -40
.equ	PRNT, -48
.equ	SIDE, -56
.equ	LEVL, -64
.equ	HKEY, -72
.type	XFastTrie_remove, @function
XFastTrie_remove:
	push	%rbp
	mov	%rsp, %rbp

	sub	$72, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, ITEM(%rbp)

	mov	$FALSE, %r8			# Possible return value for CMOVcc
	mov	XFastTrie.root(%rdi), %rax
	xor	%rdx, %rdx
	jmp	2f

1:
	sub	%rdx, %rcx
	dec	%rcx

	mov	ITEM(%rbp), %rsi
	shr	%cl, %rsi
	and	$1, %rsi

	# This will actually find "right" when the bit is 1
	mov	XFastTrieNode.left(%rax, %rsi, 1<<3), %rcx

	# If we trigger these conditions the item is NOT in the tree
	test	%rcx, %rcx
	jz	11f

	mov	%rcx, %rax
	inc	%rdx

2:
	mov	XFastTrie.hght(%rdi), %ecx
	cmp	%rcx, %rdx
	jl	1b

3:
	# Remove item (%rax) from linked list
	mov	XFastTrieNode.left(%rax), %rcx
	mov	XFastTrieNode.rght(%rax), %rdx
	mov	%rdx, XFastTrieNode.rght(%rcx)
	mov	%rcx, XFastTrieNode.left(%rdx)

	mov	%rax, NODE(%rbp)
	mov	%rcx, PRED(%rbp)
	mov	%rdx, SUCC(%rbp)
	mov	%rax, PRNT(%rbp)
	mov	XFastTrie.hght(%rdi), %edx
	mov	%rdx, LEVL(%rbp)
	jmp	5f

4:
	mov	THIS(%rbp), %rdi
	mov	XFastTrie.hght(%rdi), %ecx
	sub	%rdx, %rcx
	dec	%rcx

	mov	ITEM(%rbp), %rsi
	shr	%cl, %rsi
	mov	%rsi, HKEY(%rbp)
	and	$1, %rsi
	mov	%rsi, SIDE(%rbp)

	mov	PRNT(%rbp), %rdi		# Put this here for the call to free
	mov	XFastTrieNode.prnt(%rdi), %rax
	mov	%rax, PRNT(%rbp)		# Update node to the parent

	# Free the node
	call	free

	# Remove hash table entry
	mov	THIS(%rbp), %rdi
	mov	XFastTrie.hash(%rdi), %rdi
	mov	LEVL(%rbp), %rcx
	mov	(%rdi, %rcx, 1<<3), %rdi
	lea	HKEY(%rbp), %rsi
	call	XHashTable_remove

	# NULL out the node's (parent's) child where the freed node was
	mov	PRNT(%rbp), %rax
	mov	SIDE(%rbp), %rcx
	# This will actually find "right" when the bit is 1
	movq	$NULL, XFastTrieNode.left(%rax, %rcx, 1<<3)

	# Once we reach a node where the other child is NOT null we no longer want to remove nodes
	xor	$1, %rcx					# Toggle the side
	cmpq	$NULL, XFastTrieNode.left(%rax, %rcx, 1<<3)
	jne	6f

	decq	LEVL(%rbp)

5:
	mov	LEVL(%rbp), %rdx
	dec	%rdx
	test	%rdx, %rdx
	jns	4b

6:
	mov	PRED(%rbp), %rcx
	cmpq	$NULL, XFastTrieNode.left(%rax)
	cmove	SUCC(%rbp), %rcx

	mov	%rcx, XFastTrieNode.jump(%rax)
	jmp	8f

7:
	# Replace any dangling jump pointers
	mov	XFastTrieNode.jump(%rax), %rcx
	cmp	%rcx, NODE(%rbp)
	jne	8f

	mov	PRED(%rbp), %rcx
	cmpq	$NULL, XFastTrieNode.left(%rbp)
	cmove	SUCC(%rbp), %rcx

	mov	%rcx, XFastTrieNode.jump(%rax)

8:
	mov	XFastTrieNode.prnt(%rax), %rax
	test	%rax, %rax
	jnz	7b

	mov	THIS(%rbp), %rdi
	decl	XFastTrie.size(%rdi)
	mov	$TRUE, %r8

11:
	mov	%r8, %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	XFastTrie_log
# @description	Log the innards of an XFastTrie
# @param	%rdi	Pointer to an XFastTrie
# @return	void
.equ	THIS, -8
.equ	TEMP, -16
.equ	LIMT, -24
.equ	HARR, -32
.equ	HASH, -40
.equ	TMP2, -48
.equ	LIM2, -56
.equ	VAL2, -64
.type	XFastTrie_log, @function
XFastTrie_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$64, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$height_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	XFastTrie.hght(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$size_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	XFastTrie.size(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$list_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	XFastTrie.list(%rdi), %rax
	mov	%rax, TEMP(%rbp)
	jmp	2f

1:
	mov	XFastTrieNode.data(%rax), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$list_mid, %rdi
	call	log

	mov	THIS(%rbp), %rdi
2:
	mov	TEMP(%rbp), %rax
	mov	XFastTrieNode.rght(%rax), %rax
	mov	%rax, TEMP(%rbp)
	cmp	XFastTrie.list(%rdi), %rax
	jne	1b

	mov	$list_end, %rdi
	call	log

	mov	$hash_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	XFastTrie.hght(%rdi), %eax
	mov	%rax, LIMT(%rbp)
	mov	XFastTrie.hash(%rdi), %rax
	mov	%rax, HARR(%rbp)
	movq	$0, TEMP(%rbp)
	jmp	6f

3:
	mov	$spacer, %rdi
	call	log

	mov	$hkeyp, %rdi
	call	log

	mov	TEMP(%rbp), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$hkeys, %rdi
	call	log

	mov	HARR(%rbp), %rax
	mov	TEMP(%rbp), %rcx
	mov	(%rax, %rcx, 1<<3), %rax
	mov	%rax, HASH(%rbp)
	mov	XHashTable.dim(%rax), %rcx
	mov	$1, %rax
	shl	%cl, %rax
	mov	%rax, LIM2(%rbp)
	movq	$0, TMP2(%rbp)
	jmp	5f

4:
	incq	TMP2(%rbp)
	mov	HASH(%rbp), %rax
	mov	XHashTable.tab(%rax), %rax
	mov	(%rax, %rcx, 1<<3), %rdi

	cmp	$XHASHTABLE_NIL, %rdi
	je	5f

	cmp	$XHASHTABLE_DEL, %rdi
	je	5f

	mov	XPair.key(%rdi), %rax
	mov	%rax, VAL2(%rbp)

	mov	VAL2(%rbp), %rdi
	mov	TEMP(%rbp), %rsi
	call	itoab
	mov	%rax, %rdi
	call	log

	mov	$hidelims, %rdi
	call	log

	mov	VAL2(%rbp), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$hidelime, %rdi
	call	log

	mov	$hrowdelim, %rdi
	call	log

5:
	mov	TMP2(%rbp), %rcx
	cmp	LIM2(%rbp), %rcx
	jl	4b

	mov	$hrowend, %rdi
	call	log

	incq	TEMP(%rbp)
6:
	mov	TEMP(%rbp), %rcx
	cmp	LIMT(%rbp), %rcx
	jle	3b

	mov	$hash_end, %rdi
	call	log

	mov	$raw_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	XFastTrie.hght(%rdi), %ecx
	mov	XFastTrie.root(%rdi), %rdi
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
# @param	%rdi	Pointer to an XFastTreeNode to log
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
	mov	XFastTrieNode.data(%rax), %rdi
	push	%rdi
	mov	XFastTrieNode.prnt(%rax), %rax

4:
	cmpq	$NULL, XFastTrieNode.prnt(%rax)
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
	mov	XFastTrieNode.data(%rdi), %rdi
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
# @param	%rdi	Pointer to the root of a subtree to traverse (XFastTrieNode)
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
	mov	XFastTrieNode.left(%rdi), %rdi
	call	traverse

	mov	THIS(%rbp), %rdi
	mov	FUNC(%rbp), %rsi
	mov	DPTH(%rbp), %rdx
	mov	LMT(%rbp), %rcx
	mov	XFastTrieNode.rght(%rdi), %rdi
	call	traverse

1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	XFastTrieNode_ctor
# @description	Constructor for an XFastTrieNode
# @param	%rdi	Data value of the node
# @return	%rax	Pointer to a new XFastTrieNode
XFastTrieNode_ctor:
	push	%rdi

	mov	$XFASTTRIENODE_SIZE, %rdi
	call	alloc

	pop	%rdi
	movq	%rdi, XFastTrieNode.data(%rax)
	movq	$NULL, XFastTrieNode.prnt(%rax)
	movq	$NULL, XFastTrieNode.left(%rax)
	movq	$NULL, XFastTrieNode.rght(%rax)
	movq	$NULL, XFastTrieNode.jump(%rax)

	ret

# @function	XPair_ctor
# @description	Constructor for an Xpair
# @param	%rdi	The key (hash code) of the item
# @param	%rsi	The value of the item
# @return	%rax	Pointer to the new XPair
.equ	KEY, -8
.equ	VAL, -16
XPair_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, KEY(%rbp)
	mov	%rsi, VAL(%rbp)

	mov	$XPAIR_SIZE, %rdi
	call	alloc

	mov	KEY(%rbp), %rdi
	mov	%rdi, XPair.key(%rax)
	mov	VAL(%rbp), %rsi
	mov	%rsi, XPair.val(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	XHashTable_ctor
# @description	Constructor for an XHashTable
# @return	%rax	Pointer to a new XHashTable
.equ	SIZ, -8
.equ	TAB, -16
XHashTable_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp

	# Calculate the size of the table
	mov	$1<<XHASHTABLE_START_DIM, %rdi
	mov	%rdi, SIZ(%rbp)

	# Allocate the table
	shl	$3, %rdi	
	call	alloc
	mov	%rax, TAB(%rbp)

	# Fill the table with XHASHTABLE_NIL values
	mov	SIZ(%rbp), %rcx
	mov	%rax, %rdi
	mov	$XHASHTABLE_NIL, %rax
	rep	stosq

	# Allocate the XHashTable
	mov	$XHASHTABLE_SIZE, %rdi
	call	alloc

	mov	TAB(%rbp), %rcx
	mov	%rcx, XHashTable.tab(%rax)
	movl	$0, XHashTable.len(%rax)
	movl	$0, XHashTable.use(%rax)
	movq	$XHASHTABLE_START_DIM, XHashTable.dim(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	XHashTable_find
# @description	Finds an item in an XHashTable
# @param	%rdi	Pointer to an XHashTable to find in
# @param	%rsi	The item (XPair) to find
# @return	%rax	The item (XPair) if found, otherwise NULL
XHashTable_find:
	call	hash
	mov	XHashTable.dim(%rdi), %rcx
	mov	XHashTable.tab(%rdi), %rdx

1:
	mov	(%rdx, %rax, 1<<3), %r8

	cmp	$XHASHTABLE_NIL, %r8
	je	3f

	cmp	$XHASHTABLE_DEL, %r8
	je	2f

	mov	XPair.key(%r8), %r9
	cmp	XPair.key(%rsi), %r9
	jne	2f

	mov	%r8, %rax
	ret

2:
	inc	%rax
	mov	$1, %r8
	shl	%cl, %r8
	dec	%r8
	and	%r8, %rax
	jmp	1b

3:
	mov	$NULL, %rax
	ret

# @function	XHashTable_add
# @description	Adds an item to an XHashTable
# @param	%rdi	Pointer to the XHashTable to add to
# @param	%rsi	An item to add (XPair)
# @return	%rax	TRUE on success, FALSE on failure
.equ	THIS, -8
.equ	ITEM, -16
XHashTable_add:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, ITEM(%rbp)

	call	XHashTable_find
	test	%rax, %rax
	jz	1f

	mov	$FALSE, %rax
	ret

1:
	mov	XHashTable.use(%rdi), %eax
	lea	2(%rax, %rax), %rax
	mov	XHashTable.dim(%rdi), %rcx
	mov	$1, %rdx
	shl	%cl, %rdx
	cmp	%rdx, %rax
	jle	2f

	call	resize
	mov	ITEM(%rbp), %rsi

2:
	call	hash
	mov	XHashTable.dim(%rdi), %rcx
	mov	XHashTable.tab(%rdi), %rdx

3:
	mov	(%rdx, %rax, 1<<3), %r8

	cmp	$XHASHTABLE_NIL, %r8
	je	4f

	cmp	$XHASHTABLE_DEL, %r8
	je	4f

	inc	%rax
	mov	$1, %r8
	shl	%cl, %r8
	dec	%r8
	and	%r8, %rax
	jmp	3b

4:
	cmp	$XHASHTABLE_NIL, %r8
	jne	5f

	incl	XHashTable.use(%rdi)

5:
	incl	XHashTable.len(%rdi)
	mov	%rsi, (%rdx, %rax, 1<<3)
	mov	$TRUE, %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	XHashTable_remove
# @description	Remove an item from a XHashTable
# @param	%rdi	Pointer to a XHashTable
# @param	%rsi	The item to remove
# @param	%rax	TRUE on success, FALSE on failure
.equ	THIS, -8
.equ	ITEM, -16
.equ	SIZE, -24
XHashTable_remove:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, ITEM(%rbp)

	call	hash

	# Obtain SIZE - 1 for use acquiring modulus
	mov	XHashTable.dim(%rdi), %rcx
	mov	$1, %rdx
	shl	%cl, %rdx
	mov	%rdx, SIZE(%rbp)
	dec	%rdx

	mov	XHashTable.tab(%rdi), %rcx

1:
	mov	(%rcx, %rax, 1<<3), %r8
	cmp	$XHASHTABLE_NIL, %r8
	je	4f

	cmp	$XHASHTABLE_DEL, %r8
	je	3f

	mov	XPair.key(%r8), %r9
	cmp	XPair.key(%rsi), %r9
	jne	3f

	# If we are here we FOUND the item so we just need to delete it and check if needs resize
	movq	$XHASHTABLE_DEL, (%rcx, %rax, 1<<3)
	decl	XHashTable.len(%rdi)

	mov	XHashTable.len(%rdi), %eax
	shl	$3, %rax
	cmp	SIZE(%rbp), %rax
	jge	2f

	call	resize

2:
	mov	ITEM(%rbp), %rax
	jmp	5f

3:
	inc	%rax
	and	%rdx, %rax
	jmp	1b

4:
	# If we are here it means the item WAS NOT found
	mov	$FALSE, %rax

5:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	hash
# @description	File private helper to hash an int
# @param	%rdi	Pointer to the XHashTable
# @param	%rsi	The integer to hash
# @return	%rax	The hash code
hash:
	push	%rsi
	mov	XPair.key(%rsi), %rsi

	# Lazy generate tabulation
	cmpq	$0, tab
	jne	3f

	xor	%rcx, %rcx
	jmp	2f

1:
	call	random
	mov	%rax, tab(, %rcx, 1<<3)
	inc	%rcx

2:
	cmpq	$TAB_SIZE>>3, %rcx
	jl	1b

3:
	# Tab 0
	mov	%rsi, %rcx
	and	$0xff, %rcx
	mov	tab + 1<<10 * 0(, %rcx, 1<<2), %eax

	# Tab 1
	mov	%rsi, %rcx
	shr	$1<<3, %rcx
	and	$0xff, %rcx
	xor	tab + 1<<10(, %rcx, 1<<2), %eax

	# Tab 2
	mov	%rsi, %rcx
	shr	$1<<4, %rcx
	and	$0xff, %rcx
	xor	tab + 1<<11(, %rcx, 1<<2), %eax

	# Tab 4
	mov	%rsi, %rcx
	shr	$1<<3 * 3, %rcx
	and	$0xff, %rcx
	xor	tab + 1<<10 * 3(, %rcx, 1<<2), %eax

	mov	$HASH_KEY_BITS, %rcx
	sub	XHashTable.dim(%rdi), %rcx
	shr	%cl, %rax

	pop	%rsi
	ret

# @function	resize
# @description	File private helper to resize an XHashTable backing array to be at least 3x the 
#		number of items
# @param	%rdi	Pointer to the XHashTable to resize
# @return	void
.equ	THIS, -8
.equ	DOLD, -16
.equ	TOLD, -24
.equ	SIZE, -32
.equ	TNEW, -40
resize:
	push	%rbp
	mov	%rsp, %rbp

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	XHashTable.dim(%rdi), %rax
	mov	%rax, DOLD(%rbp)
	mov	XHashTable.tab(%rdi), %rax
	mov	%rax, TOLD(%rbp)

	# Target length (3x)
	mov	XHashTable.len(%rdi), %eax
	lea	(%rax, %rax, 1<<1), %rax
	jmp	2f

1:
	# Acquire a new dimension that satisfies the target
	incq	XHashTable.dim(%rdi)

2:
	mov	XHashTable.dim(%rdi), %rcx
	mov	$1, %rdx
	shl	%cl, %rdx
	cmp	%rax, %rdx
	jl	1b
	
	mov	%rdx, SIZE(%rbp)

	# Allocate the new backing array
	mov	%rdx, %rdi
	shl	$3, %rdi
	call	alloc
	mov	%rax, TNEW(%rbp)

	# Initialize all members of the backing array to NIL (STOSL)
	mov	SIZE(%rbp), %rcx
	mov	%rax, %rdi
	mov	$XHASHTABLE_NIL, %rax
	rep	stosq

	# Migrate existing items from TOLD to TNEW
	mov	THIS(%rbp), %rdi
	mov	TOLD(%rbp), %r8
	mov	TNEW(%rbp), %r9
	mov	DOLD(%rbp), %rcx
	mov	$1, %rdx
	shl	%cl, %rdx
	jmp	6f

3:
	mov	(%r8, %rdx, 1<<3), %rsi

	cmp	$XHASHTABLE_NIL, %rsi
	je	6f

	cmp	$XHASHTABLE_DEL, %rsi
	je	6f

	call	hash

4:
	cmpq	$XHASHTABLE_NIL, (%r9, %rax, 1<<3)
	je	5f

	inc	%rax
	# For use obtaining modulus (SIZE - 1)
	mov	SIZE(%rbp), %rcx
	dec	%rcx	
	and	%rcx, %rax
	jmp	4b

5:
	mov	%rsi, (%r9, %rax, 1<<3)

6:
	dec	%rdx
	test	%rdx, %rdx
	jns	3b

	mov	%r9, XHashTable.tab(%rdi)
	mov	XHashTable.len(%rdi), %eax
	mov	%eax, XHashTable.use(%rdi)

	mov	%r8, %rdi
	call	free

	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret
