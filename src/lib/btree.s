# lib/btree.s - BTree

.include	"common.inc"

.globl	BTree_ctor, BTree_add, BTree_find, BTree_remove, BTree_log

# B setting for B-tree children derivation
.equ	B, 2
.equ	NIL, -1

# BTree
	.struct	0
BTree.bs:
	.struct	BTree.bs + 1<<3
BTree.ri:
	.struct	BTree.ri + 1<<2
BTree.ln:
	.struct	BTree.ln + 1<<2
.equ	BTREE_SIZE, .

# BTreeNode
	.struct	0
BTreeNode.keys:
	.struct BTreeNode.keys + 1<<2 * B<<1
BTreeNode.children:
	.struct	BTreeNode.children + 1<<2 * (B<<1 + 1)
BTreeNode.len:
	.struct	BTreeNode.len + 1<<2
BTreeNode.heap:
	.struct	BTreeNode.heap + 1<<2
.equ	BTREENODE_SIZE, B<<7 - 1<<3	# Plenty of space for strings and subtract block header

.section .rodata

llabel:
	.ascii	"Size => \0"
rlabel:
	.ascii	"Raw  => {\n\0"
rend:
	.ascii	"}\n\0"
kstart:
	.ascii	"[\0"
kdelim:
	.ascii	"|\0"
kend:
	.ascii	"]\n\0"
nil:
	.ascii	"NIL\0"
vert:
	.ascii	"|--\0"
horz:
	.ascii	"---\0"
slabel:
	.ascii	"SSet => \0"
sstart:
	.ascii	"[ \0"
send:
	.ascii	" ]\n\0"
smid:
	.ascii	", \0"
newline:
	.byte	LF, NULL
indent:
	.byte	SPACE, SPACE, SPACE, NULL

.section .text

# @public	BTree_ctor
# @description	Constructor for a BTree
# @param	%rdi	Filename of backing file
# @return	%rax	BTree
.equ	BS, -8
.equ	THIS, -16
.type	BTree_ctor, @function
BTree_ctor:
	push	%rbp
	mov	%rsp, %rbp

	# Locals
	sub	$16, %rsp

	# Block store
	mov	$BTREENODE_SIZE, %rsi
	call	BlockStore_ctor
	mov	%rax, BS(%rbp)

	# We will load or save the instance from a temporary buffer on the stack
	sub	$BTREENODE_SIZE, %rsp

	# Checks if the BlockStore has any blocks. If it does there is instance information in
	# block zero. If it doesn't create block zero
	cmpl	$0, 1<<3(%rax)
	jg	1f

	# Place a zeroed out buffer
	mov	%rsp, %rdi
	mov	$NULL, %rax
	mov	$BTREENODE_SIZE, %rcx
	rep	stosb

	# For an EMPTY BlockStore we assume the root index will be one which is probably OK?
	# We'd have to write the information block twice otherwise
	movl	$1, BTree.ri(%rsp)
	movl	$0, BTree.ln(%rsp)

	mov	BS(%rbp), %rdi
	mov	%rsp, %rsi
	call	BlockStore_place

	# Create the root node
	call	BTreeNode_ctor

	mov	BS(%rbp), %rdi
	mov	%rax, %rsi
	call	BlockStore_place

1:
	mov	$BTREE_SIZE, %rdi
	call	alloc
	mov	%rax, THIS(%rbp)

	# The BlockStore has existing instance information saved. We will load that into the buffer
	mov	BS(%rbp), %rdi
	mov	$0, %rsi
	mov	%rsp, %rdx
	call	BlockStore_read

	mov	THIS(%rbp), %rax
	mov	BS(%rbp), %rcx
	mov	%rcx, BTree.bs(%rax)
	mov	BTree.ri(%rdx), %ecx
	mov	%ecx, BTree.ri(%rax)
	mov	BTree.ln(%rdx), %ecx
	mov	%ecx, BTree.ln(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public	BTree_log
# @description	Logs the innards of a BTree
# @param	%rdi	BTree
# @return	void
.equ	THIS, -8
.type	BTree_log, @function
BTree_log:
	push	%rbp
	mov	%rsp, %rbp
	
	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$llabel, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	BTree.ln(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$slabel, %rdi
	call	log

	mov	$sstart, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	BTree.ri(%rdi), %esi
	mov	$_log_val, %rdx
	xor	%rcx, %rcx
	call	_BTreeNode_traverse

	mov	$send, %rdi
	call	log

	mov	$rlabel, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	BTree.ri(%rdi), %esi
	mov	$_log_key, %rdx
	xor	%rcx, %rcx
	call	_BTreeNode_traverse

	mov	$rend, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private	_BTreeNode_traverse
# @description	Traverse a Btree recursively, invoking a callback at each key
# @param	%rdi	BTree
# @param	%rsi	Block store index for a node
# @param	%rdx	Callback
# @param	%rcx	Current depth
# @return	void
.equ	THIS, -8
.equ	BIDX, -16
.equ	FUNC, -24
.equ	DPTH, -32
.equ	ITER, -40
_BTreeNode_traverse:
	push	%rbp
	mov	%rsp, %rbp

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, BIDX(%rbp)
	mov	%rdx, FUNC(%rbp)
	mov	%rcx, DPTH(%rbp)
	movq	$0, ITER(%rbp)

	test	%rsi, %rsi
	js	5f

1:
	sub	$BTREENODE_SIZE, %rsp

	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi
	mov	%rsp, %rdx
	call	BlockStore_read
	jmp	4f

2:
	mov	THIS(%rbp), %rdi
	mov	ITER(%rbp), %rcx
	movslq	BTreeNode.children(%rsp, %rcx, 1<<2), %rsi
	mov	FUNC(%rbp), %rdx
	mov	DPTH(%rbp), %rcx
	inc	%rcx
	call	_BTreeNode_traverse

	mov	ITER(%rbp), %rcx
	mov	BTreeNode.keys(%rsp, %rcx, 1<<2), %eax
	lea	(%rsp, %rax), %rdi
	mov	DPTH(%rbp), %rsi
	mov	BIDX(%rbp), %rdx
	call	*FUNC(%rbp)

3:
	incq	ITER(%rbp)

4:
	mov	ITER(%rbp), %rcx
	cmp	BTreeNode.len(%rsp), %ecx
	jl	2b

	# There is ONE more child to log ...
	mov	THIS(%rbp), %rdi
	mov	ITER(%rbp), %rcx
	movslq	BTreeNode.children(%rsp, %rcx, 1<<2), %rsi
	mov	FUNC(%rbp), %rdx
	mov	DPTH(%rbp), %rcx
	inc	%rcx
	call	_BTreeNode_traverse

5:
	mov	THIS(%rbp), %rdi
	mov	BIDX(%rbp), %rsi
	mov	FUNC(%rbp), %rdx
	mov	DPTH(%rbp), %rcx

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private	_log_key
# @description	Logs an individual value in the tree
# @param	%rdi	The string value
# @param	%rsi	The depth
# @param	%rdi	Block index
# @return	void
.equ	THIS, -8
.equ	DPTH, -16
.equ	BIDX, -24
.equ	ITER, -32
_log_key:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, DPTH(%rbp)
	mov	%rdx, BIDX(%rbp)
	movq	$0, ITER(%rbp)

	mov	$indent, %rdi
	call	log

	test	%rsi, %rsi
	jz	4f

1:
	mov	$vert, %rdi
	call	log
	jmp	3f

2:
	mov	$horz, %rdi
	call	log

3:
	incq	ITER(%rbp)
	mov	ITER(%rbp), %rcx
	cmp	DPTH(%rbp), %rcx
	jl	2b

4:
	mov	$kstart, %rdi
	call	log

	mov	BIDX(%rbp), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$kdelim, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	call	log

	mov	$kend, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	DPTH(%rbp), %rsi

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private	_log_val
# @description	Logs a value in the tree
# @param	%rdi	String value
# @return	void
_log_val:
	cmp	$nil, %rdi
	je	1f

	call	log
	mov	$smid, %rdi
	call	log

1:
	ret

# @public/	BTree_find
# @description	Search for a value in a BTree
# @param	%rdi	BTree
# @param	%rsi	Search key
# @param	%rdx	Result buffer
# @return	%rax	A pointer to the result buffer containing the smallest element x such that 
#			x is GREATER THAN or EQUAL TO the search or -1 if no such value exists
.equ	THIS, -8
.equ	SKEY, -16
.equ	RESB, -24
.equ	NIDX, -32
.equ	BUFF, -40
.equ	RET, -48
.type	BTree_find, @function
BTree_find:
	push	%rbp
	mov	%rsp, %rbp

	sub	$48, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, SKEY(%rbp)
	mov	%rdx, RESB(%rbp)
	mov	BTree.ri(%rdi), %eax
	mov	%rax, NIDX(%rbp)
	movq	$-1, RET(%rbp) 

	mov	$BTREENODE_SIZE, %rdi
	call	alloc
	mov	%rax, BUFF(%rbp)
	jmp	3f

1:
	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi
	mov	BUFF(%rbp), %rdx
	call	BlockStore_read

	mov	%rdx, %rdi
	mov	SKEY(%rbp), %rsi
	call	_BTreeNode_findit

	test	%rax, %rax
	jns	2f

	inc	%rax
	neg	%rax
	mov	BTreeNode.keys(%rdi, %rax, 1<<2), %eax

	# Load found result into the result buffer
	lea	(%rdi, %rax), %rdi
	call	strlen
	mov	%rax, %rcx
	mov	%rdi, %rsi
	mov	RESB(%rbp), %rdi
	rep	movsb

	mov	RESB(%rbp), %rdx
	mov	%rdx, RET(%rbp)
	jmp	4f

2:
	# Tee up next node to search
	movslq	BTreeNode.children(%rdi, %rax, 1<<2), %rcx
	mov	%rcx, NIDX(%rbp)

	mov	BTreeNode.keys(%rdi, %rax, 1<<2), %ecx

	# Check if search came up dry ...
	test	%ecx, %ecx
	js	3f

	# Load immediate result into result buffer
	lea	(%rdi, %rcx), %rdi
	call	strlen
	mov	%rax, %rcx
	mov	%rdi, %rsi
	mov	RESB(%rbp), %rdi
	rep	movsb

	mov	RESB(%rbp), %rdx
	mov	%rdx, RET(%rbp)

3:
	mov	NIDX(%rbp), %rsi
	test	%rsi, %rsi
	jns	1b

4:
	mov	BUFF(%rbp), %rdi
	call	free

	mov	THIS(%rbp), %rdi
	mov	SKEY(%rbp), %rsi
	mov	RESB(%rbp), %rdx

	mov	RET(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public	BTree_add
# @description	Add a value to the BTree
# @param	%rdi	BTree
# @param	%rsi	Value to add
# @return	%rax	TRUE on success or a negative value on failure
.equ	THIS, -8
.equ	ITEM, -16
.equ	NODE, -24
.equ	ROOT, -32
.equ	SVAL, -40
.equ	SIDX, -48
.type	BTree_add, @function
BTree_add:
	push	%rbp
	mov	%rsp, %rbp

	sub	$48, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, ITEM(%rbp)

	mov	BTree.ri(%rdi), %edx
	call	_BTree_add_recursive
	test	%rax, %rax
	js	2f
	jz	1f

	# We recieved a split node in the return packet from _BTree_add_recursive which means that
	# the root was split. When this happens we need to make a NEW root with the old root and
	# the split node as children

	# Obtain/store the string value of key on split node to be the sole value on the new root
	mov	%rax, NODE(%rbp)		# Split node
	mov	BTreeNode.keys(%rax), %ecx	# Get key at idx 0 of split node
	lea	(%rax, %rcx), %rcx		# Get value of idx 0 of split node
	mov	%rcx, SVAL(%rbp)

	# Create a new root that the split node (and the OLD root) will be children of
	call	BTreeNode_ctor
	mov	%rax, ROOT(%rbp)		# New root

	mov	%rax, %rdi
	mov	SVAL(%rbp), %rsi
	mov	$NIL, %rdx			# We don't have the CID yet, we will set manually
	call	BTreeNode_add

	# Now that we've transferred the string to the new root, we can safely remove it
	mov	NODE(%rbp), %rdi
	mov	$0, %rsi
	call	BTreeNode_remove

	# Write the split node to disk
	mov	%rdi, %rsi
	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi
	call	BlockStore_place
	mov	%rax, SIDX(%rbp)

	# Done with split node so we can call free
	mov	%rsi, %rdi
	call	free

	# Manually move in the children nodes to the new root
	mov	THIS(%rbp), %rdi
	mov	ROOT(%rbp), %rsi
	mov	BTree.ri(%rdi), %eax
	mov	%eax, BTreeNode.children(%rsi)
	mov	SIDX(%rbp), %rax
	mov	%eax, BTreeNode.children + 1<<2(%rsi)

	# Save the new root to disk
	mov	BTree.bs(%rdi), %rdi
	call	BlockStore_place

	# Update the root index on the tree
	mov	THIS(%rbp), %rdi
	mov	%eax, BTree.ri(%rdi)

	# Done with new root node so we can call free
	mov	%rsi, %rdi
	call	free

	mov	THIS(%rbp), %rdi

1:
	incl	BTree.ln(%rdi)

	# Save meta information to disk, this needs to be saved as a whole block despite being only
	# two attributes
	# FIXME: This whole deal is a little clunky but it gets the job done
	sub	$BTREENODE_SIZE, %rsp
	mov	%rsp, %rdi
	mov	$NULL, %rax
	mov	$BTREENODE_SIZE, %rcx
	rep	stosb

	mov	%rsp, %rdx
	mov	THIS(%rbp), %rdi
	mov	BTree.ri(%rdi), %eax
	mov	%eax, BTree.ri(%rdx)
	mov	BTree.ln(%rdi), %eax
	mov	%eax, BTree.ln(%rdx)
	mov	BTree.bs(%rdi), %rdi
	mov	$0, %rsi
	call	BlockStore_write

	mov	$TRUE, %rax

2:
	mov	THIS(%rbp), %rdi
	mov	ITEM(%rbp), %rsi

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public	BTree_remove
# @description	Removes an item from a BTree
# @param	%rdi	BTree
# @param	%rsi	Search key to remove
# @return	%rax	TRUE on success, FALSE on failure
.equ	THIS, -8
.equ	SKEY, -16
.type	BTree_remove, @function
BTree_remove:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, SKEY(%rbp)

	mov	BTree.ri(%rdi), %edx
	call	_BTree_remove_recursive
	test	%rax, %rax
	jz	1f

	decl	BTree.ln(%rdi)

	# Save meta information to disk, this needs to be saved as a whole block despite being only
	# two attributes
	# FIXME: This whole deal is a little clunky but it gets the job done
	sub	$BTREENODE_SIZE, %rsp
	mov	%rsp, %rdi
	mov	$NULL, %rax
	mov	$BTREENODE_SIZE, %rcx
	rep	stosb

	mov	%rsp, %rdx
	mov	THIS(%rbp), %rdi
	mov	BTree.ri(%rdi), %eax
	mov	%eax, BTree.ri(%rdx)
	mov	BTree.ln(%rdi), %eax
	mov	%eax, BTree.ln(%rdx)
	mov	BTree.bs(%rdi), %rdi
	mov	$0, %rsi
	call	BlockStore_write

	mov	$TRUE, %rax

1:
	mov	THIS(%rbp), %rdi
	mov	SKEY(%rbp), %rsi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private	_BTree_remove_recursive
# @description	Recursive remove utility
# @param	%rdi	Btree
# @param	%rsi	Search key to remove
# @param	%rdx	Index of a node/subtree
.equ	THIS, -8
.equ	SKEY, -16
.equ	BIDX, -24
.equ	BUFF, -32
.equ	CHLD, -40
.equ	FIDX, -48
.equ	RET, -56
_BTree_remove_recursive:
	push	%rbp
	mov	%rsp, %rbp

	# If we receive a negative index we didn't find it
	xor	%rax, %rax
	test	%rdx, %rdx
	js	4f

	sub	$56, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, SKEY(%rbp)
	mov	%rdx, BIDX(%rbp)
	movq	$FALSE, RET(%rbp)

	mov	$BTREENODE_SIZE, %rdi
	call	alloc
	mov	%rax, BUFF(%rbp)

	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi
	mov	BIDX(%rbp), %rsi
	mov	%rax, %rdx
	call	BlockStore_read

	mov	%rdx, %rdi
	mov	SKEY(%rbp), %rsi
	call	_BTreeNode_findit
	mov	%rax, FIDX(%rbp)

	test	%rax, %rax
	js	2f

	mov	BTreeNode.children(%rdi, %rax, 1<<2), %edx
	mov	THIS(%rbp), %rdi
	call	_BTree_remove_recursive

	test	%rax, %rax
	jz	5f

	movq	$TRUE, RET(%rbp)
	jmp	4f

2:
	# Found it
	inc	%rax
	neg	%rax
	mov	%rax, FIDX(%rbp)

	# Check if the node is a leaf (i.e. its first child is -1)
	cmpl	$NIL, BTreeNode.children(%rdi)
	jne	3f

	# If the node is a leaf we can just remove the child and we are done
	mov	%rax, %rsi
	call	BTreeNode_remove
	movq	$TRUE, RET(%rbp)

	# Save the updated node (%rdi) to disk
	mov	%rdi, %rdx			# Populated node (buffer)
	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi		# BlockStore
	mov	BIDX(%rbp), %rsi		# Node idx
	call	BlockStore_write

	jmp	5f

3:
	# If the node is NOT a leaf we need to drill down into the tree to find the smallest
	# element that is LARGER than our node in a leaf
	mov	BTreeNode.children + 1<<2(%rdi, %rax, 1<<2), %esi
	mov	THIS(%rbp), %rdi
	sub	$BTREENODE_SIZE, %rsp
	mov	%rsp, %rdx
	call	_BTree_remove_smallest

	# %rdx holds a pointer to the smallest element which is LARGER than the search key so
	# we need to replace the search key with what's in %rdx
	mov	BUFF(%rbp), %rdi
	mov	FIDX(%rbp), %rsi
	call	BTreeNode_remove

	mov	BTreeNode.children + 1<<2(%rdi, %rsi, 1<<2), %edx
	mov	%rsp, %rsi
	call	BTreeNode_add

	# Move the children all left to undo what was done by BTreeNode_add
	mov	FIDX(%rbp), %rax
	lea	BTreeNode.children + 1<<3(%rdi, %rax, 1<<2), %rsi	# Source
	lea	BTreeNode.children + 1<<2(%rdi, %rax, 1<<2), %rdi	# Destination
	mov	$B<<1 - 1, %rcx
	sub	%rax, %rcx
	rep	movsl

	mov	BUFF(%rbp), %rdx
	movl	$NIL, BTreeNode.children + B<<3(%rdx)

	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi
	mov	BIDX(%rbp), %rsi
	call	BlockStore_write

	incq	FIDX(%rbp)
	movq	$TRUE, RET(%rbp)

4:
	mov	THIS(%rbp), %rdi
	mov	BUFF(%rbp), %rsi
	mov	FIDX(%rbp), %rdx
	call	_BTree_check_underflow

5:
	# Free the buffer
	mov	BUFF(%rbp), %rdi
	call	free

	mov	THIS(%rbp), %rdi
	mov	SKEY(%rbp), %rsi
	mov	BIDX(%rbp), %rdx
	mov	RET(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private	_Btree_remove_smallest
# @description	Given a block index, drill down into the subtree and remove the SMALLEST element,
#		balancing underflow on the way back up. Store the element's value in the buffer
# @param	%rdi	Btree
# @param	%rsi	Block index
# @param	%rdx	Buffer to store the string
# @return	%rax	Pointer to the buffer which contains the string value of the removed elem
.equ	THIS, -8
.equ	BIDX, -16
.equ	BUFF, -24
.equ	NODE, -32
_BTree_remove_smallest:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, BIDX(%rbp)
	mov	%rdx, BUFF(%rbp)

	sub	$BTREENODE_SIZE, %rsp
	mov	%rsp, NODE(%rbp)

	mov	BTree.bs(%rdi), %rdi
	mov	NODE(%rbp), %rdx
	call	BlockStore_read

	# Check if the child is a leaf. If it is a leaf we can remove it
	mov	BTreeNode.children(%rdx), %esi
	test	%esi, %esi
	jns	1f

	mov	%rdx, %rdi
	mov	BTreeNode.keys(%rdi), %eax
	lea	(%rdi, %rax), %rdi		# String value of the elem TODO save

	# Save the string to the user-provided buffer
	call	strlen
	mov	%rax, %rcx
	mov	%rdi, %rsi
	mov	BUFF(%rbp), %rdi
	rep	movsb

	mov	%rsp, %rdi
	movq	$0, %rsi
	call	BTreeNode_remove

	mov	%rdi, %rdx
	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi
	mov	BIDX(%rbp), %rsi
	call	BlockStore_write

	mov	BUFF(%rbp), %rax
	jmp	2f

1:
	mov	THIS(%rbp), %rdi
	mov	BUFF(%rbp), %rdx
	call	_BTree_remove_smallest

	mov	NODE(%rbp), %rsi
	mov	$0, %rdx
	call	_BTree_check_underflow

2:
	mov	THIS(%rbp), %rdi
	mov	BIDX(%rbp), %rsi
	mov	BUFF(%rbp), %rdx
	mov	%rbp, %rsp
	pop	%rbp
	ret


# @private	_BTree_check_underflow
# @description	Check for and correct underflow in a node
# @param	%rdi	BTree
# @param	%rsi	BTreeNode
# @param	%rdx	Child index
# @return	void
.equ	THIS, -8
.equ	NODE, -16
.equ	CIDX, -24
.equ	CHD1, -32
.equ	CHD2, -40
.equ	CHI1, -48
.equ	CHI2, -56
_BTree_check_underflow:
	push	%rbp
	mov	%rsp, %rbp

	sub	$56, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, NODE(%rbp)
	mov	%rdx, CIDX(%rbp)

	cmpl	$0, BTreeNode.children(%rsi, %rdx, 1<<2)
	jl	8f

	# Load the child
	sub	$BTREENODE_SIZE, %rsp

	mov	BTreeNode.children(%rsi, %rdx, 1<<2), %esi
	mov	%rsi, CHI1(%rbp)
	mov	%rsp, %rdx
	mov	BTree.bs(%rdi), %rdi
	call	BlockStore_read
	mov	%rdx, CHD1(%rbp)

	# Child index IS zero check for underflow. If there's no underflow there's nothing to do
	cmpl	$B - 1, BTreeNode.len(%rdx)
	jge	8f

	# Different corrections are needed depending upon whether the child index is zero or not
	cmpq	$0, CIDX(%rbp)
	jne	3f

	sub	$BTREENODE_SIZE, %rsp
	mov	%rsp, %rdx						# CHD2
	mov	%rdx, CHD2(%rbp)

	mov	NODE(%rbp), %rax
	mov	CIDX(%rbp), %rcx
	mov	BTreeNode.children + 1<<2(%rax, %rcx, 1<<2), %esi	# Right child of CHD1
	mov	%rsi, CHI2(%rbp)
	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi
	call	BlockStore_read

	cmpl	$B, BTreeNode.len(%rdx)
	jle	2f

	# Adjacent child has an extra key which can be "borrowed"
	mov	NODE(%rbp), %rdi
	mov	CIDX(%rbp), %rsi
	mov	CHD2(%rbp), %rdx
	mov	CHD1(%rbp), %rcx
	call	_BTreeNode_shift_rl
	jmp	6f

2:
	# Adjacent child DOES NOT have an extra key so both children must be "merged"
	mov	NODE(%rbp), %rdi
	mov	CIDX(%rbp), %rsi
	mov	CHD1(%rbp), %rdx
	mov	CHD2(%rbp), %rcx
	call	_BTreeNode_merge

	jmp	5f

3:
	# Child index IS NOT zero
	sub	$BTREENODE_SIZE, %rsp
	mov	%rsp, %rdx						# CHD2
	mov	%rdx, CHD2(%rbp)

	mov	NODE(%rbp), %rax
	mov	CIDX(%rbp), %rcx
	mov	BTreeNode.children - 1<<2(%rax, %rcx, 1<<2), %esi	# Right child of CHD1
	mov	%rsi, CHI2(%rbp)
	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi
	call	BlockStore_read

	cmpl	$B, BTreeNode.len(%rdx)
	jle	4f

	# Adjacent child has an extra key which can be "borrowed"
	mov	NODE(%rbp), %rdi
	mov	CIDX(%rbp), %rsi
	mov	CHD2(%rbp), %rdx
	mov	CHD1(%rbp), %rcx
	call	_BTreeNode_shift_lr
	jmp	6f

4:
	# Adjacent child DOES NOT have an extra key so both children must be "merged"
	mov	NODE(%rbp), %rdi
	mov	CIDX(%rbp), %rsi
	mov	CHD1(%rbp), %rdx
	mov	CHD2(%rbp), %rcx
	call	_BTreeNode_merge

5:
	# CHD2 need to be DELETED (post-merge)
	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi
	mov	CHI2(%rbp), %rsi
	call	BlockStore_free

	jmp	7f

6:
	# CHD2 needs to be WRITTEN (modified)
	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi
	mov	CHI2(%rbp), %rsi
	mov	CHD2(%rbp), %rdx
	call	BlockStore_write

7:
	# CHD1 and NODE need to be WRITTEN (modified)
	mov	CHI1(%rbp), %rsi
	mov	CHD1(%rbp), %rdx
	call	BlockStore_write

	mov	CIDX(%rbp), %rsi
	mov	NODE(%rbp), %rdx
	call	BlockStore_write

8:
	# Epilogue
	mov	THIS(%rbp), %rdi
	mov	NODE(%rbp), %rsi
	mov	CIDX(%rbp), %rdx

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private	_BTreeNode_shift_rl
# @description	Shift a key from right to left between a parent and right/left child combo in order
#		to fix an underflow
# @param	%rdi	BTreeNode (parent)
# @param	%rsi	Parent index of the node that is underflowing
# @param	%rdx	BTreeNode on the right (source)
# @param	%rcx	BTreeNode on the left (destination)
# @return	void
.equ	PRT, -8
.equ	IDX, -16
.equ	SRC, -24
.equ	DST, -32
.equ	MVS, -40
.equ	CNT, -48
_BTreeNode_shift_rl:
	push	%rbp
	mov	%rsp, %rbp

	# Locals
	sub	$48, %rsp
	mov	%rdi, PRT(%rbp)
	mov	%rsi, IDX(%rbp)
	mov	%rdx, SRC(%rbp)
	mov	%rcx, DST(%rbp)

	# Add the parent key to the destination (+1)
	mov	BTreeNode.keys(%rdi, %rsi, 1<<2), %eax
	lea	(%rdi, %rax), %rsi			# String value
	mov	%rcx, %rdi				# Destination node
	mov	BTreeNode.children(%rdx), %edx		# First child on the right
	call	BTreeNode_add

	# Remove the parent key from the parent
	mov	PRT(%rbp), %rdi
	mov	IDX(%rbp), %rsi
	call	BTreeNode_remove

	# Calculate number of moves
	mov	SRC(%rbp), %rax
	mov	BTreeNode.len(%rax), %eax
	mov	DST(%rbp), %rcx
	mov	BTreeNode.len(%rcx), %ecx
	add	%rcx, %rax
	shr	%rax
	sub	%rcx, %rax
	mov	%rax, MVS(%rbp)

	movq	$1, CNT(%rbp)
	jmp	2f

1:
	# Add the 0th value in the source to the destination
	mov	DST(%rbp), %rdi					# Target for addition
	mov	SRC(%rbp), %rax
	mov	BTreeNode.keys(%rax), %esi
	lea	(%rax, %rsi), %rsi				# String value from source
	mov	BTreeNode.children(%rax, %rcx, 1<<2), %rdx	# Corresponding child
	call	BTreeNode_add

	# Remove the 0th value in the source
	mov	SRC(%rbp), %rdi
	mov	$0, %rsi
	call	BTreeNode_remove

	incq	CNT(%rbp)

2:
	mov	CNT(%rbp), %rcx
	cmpq	MVS(%rbp), %rcx
	jl	1b

	# Move the current first element from the source up to the parent
	mov	PRT(%rbp), %rdi					# Target for addition
	mov	SRC(%rbp), %rax
	mov	BTreeNode.keys(%rax), %esi
	lea	(%rax, %rsi), %rsi				# String value
	mov	IDX(%rbp), %rcx
	mov	BTreeNode.children(%rdi, %rcx, 1<<2), %rdx	# Child should stay the same
	call	BTreeNode_add

	# Final corrections for children on source
	# Move existing children to the left by the required number of places
	std
	mov	SRC(%rbp), %rsi
	mov	MVS(%rbp), %rcx
	lea	BTreeNode.children(%rsi, %rcx, 1<<2), %rsi
	lea	BTreeNode.children(%rsi, %rdi), %rdi
	rep	movsl
	cld

	# Fill in the vacated children with NIL
	mov	$B<<1 + 1, %rcx
	sub	MVS(%rbp), %rcx
	mov	SRC(%rbp), %rdi
	lea	BTreeNode.children(%rdi, %rcx, 1<<2), %rdi
	mov	$NIL, %rax
	rep	stosl

	# Restore params
	mov	PRT(%rbp), %rdi
	mov	IDX(%rbp), %rsi
	mov	SRC(%rbp), %rcx
	mov	DST(%rbp), %rdx

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private	_BTreeNode_shift_lr
# @description	Shift a key from left to right between a parent and right/left child combo in order
#		to fix an underflow
# @param	%rdi	BTreeNode (parent)
# @param	%rsi	Parent index of the node that is underflowing
# @param	%rdx	BTreeNode on the left (source)
# @param	%rcx	BTreeNode on the right (destination)
# @return	void
.equ	PRT, -8
.equ	IDX, -16
.equ	SRC, -24
.equ	DST, -32
.equ	MVS, -40
.equ	CNT, -48
_BTreeNode_shift_lr:
	push	%rbp
	mov	%rsp, %rbp

	# Locals
	sub	$48, %rsp
	mov	%rdi, PRT(%rbp)
	mov	%rsi, IDX(%rbp)
	mov	%rdx, SRC(%rbp)
	mov	%rcx, DST(%rbp)

	# Add the parent key to the destination (+1)
	mov	BTreeNode.keys(%rdi, %rsi, 1<<2), %eax
	lea	(%rdi, %rax), %rsi				# String value
	mov	%rcx, %rdi					# Destination node
	mov	BTreeNode.len(%rdx), %eax
	// ?? Is this the correct child??
	mov	BTreeNode.children(%rdx, %rax, 1<<2), %edx	# Last child on the left
	call	BTreeNode_add

	# Remove the parent key from the parent
	mov	PRT(%rbp), %rdi
	mov	IDX(%rbp), %rsi
	call	BTreeNode_remove

	# Calculate number of moves
	mov	SRC(%rbp), %rax
	mov	BTreeNode.len(%rax), %eax
	mov	DST(%rbp), %rcx
	mov	BTreeNode.len(%rcx), %ecx
	add	%rcx, %rax
	shr	%rax
	sub	%rcx, %rax
	mov	%rax, MVS(%rbp)

	movq	$1, CNT(%rbp)
	jmp	2f

1:
	# Add the last value in the source to the destination
	mov	DST(%rbp), %rdi					# Target for addition
	mov	SRC(%rbp), %rax
	mov	BTreeNode.len(%rax), %ecx
	mov	BTreeNode.keys - 1<<2(%rax, %rcx, 1<<2), %esi
	lea	(%rax, %rsi), %rsi				# String value from source
	mov	BTreeNode.children(%rax, %rcx, 1<<2), %rdx	# Corresponding child
	call	BTreeNode_add

	# Remove the last value in the source
	mov	SRC(%rbp), %rdi
	mov	BTreeNode.len(%rdi), %esi
	dec	%rsi
	call	BTreeNode_remove

	incq	CNT(%rbp)

2:
	mov	CNT(%rbp), %rcx
	cmpq	MVS(%rbp), %rcx
	jl	1b

	# Move the current last element from the source up to the parent
	mov	PRT(%rbp), %rdi					# Target for addition
	mov	SRC(%rbp), %rax
	mov	BTreeNode.len(%rax), %ecx
	mov	BTreeNode.keys - 1<<2(%rax, %rcx), %esi
	lea	(%rax, %rsi), %rsi				# String value
	mov	IDX(%rbp), %rcx
	mov	BTreeNode.children(%rdi, %rcx, 1<<2), %rdx	# Child should stay the same
	call	BTreeNode_add

	# Final corrections for children on source
	# Move existing children to the left by the required number of places
	std
	mov	SRC(%rbp), %rsi
	mov	MVS(%rbp), %rcx
	lea	BTreeNode.children(%rsi, %rcx, 1<<2), %rsi
	lea	BTreeNode.children(%rsi), %rdi
	rep	movsl
	cld

	# Fill in the vacated children with NIL
	mov	$B<<1 + 1, %rcx
	sub	MVS(%rbp), %rcx
	mov	SRC(%rbp), %rdi
	lea	BTreeNode.children(%rdi, %rcx, 1<<2), %rdi
	mov	$NIL, %rax
	rep	stosl

	# Restore params
	mov	PRT(%rbp), %rdi
	mov	IDX(%rbp), %rsi
	mov	SRC(%rbp), %rcx
	mov	DST(%rbp), %rdx

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private	_BTreeNode_merge
# @description	Merge to child nodes
# @param	%rdi	BTreeNode (parent)
# @param	%rsi	Child index
# @param	%rdx	BTreeNode (child 1)
# @param	%rcx	BTreeNode (child 2)
# @return	void
.equ	PRT, -8
.equ	IDX, -16
.equ	CH1, -24
.equ	CH2, -32
.equ	CNT, -40
_BTreeNode_merge:
	push	%rbp
	mov	%rsp, %rbp

	# Locals
	sub	$40, %rsp
	mov	%rdi, PRT(%rbp)
	mov	%rsi, IDX(%rbp)
	mov	%rcx, CH1(%rbp)
	mov	%rdx, CH2(%rbp)
	movq	$0, CNT(%rbp)

	# Add the parent key (at idx) to child 1 associated with the first of child 2's children
	mov	BTreeNode.keys(%rdi, %rsi, 1<<2), %esi
	lea	(%rdi, %rsi), %rsi
	mov	BTreeNode.children(%rdx), %edx
	mov	CH1(%rbp), %rdi
	call	BTreeNode_add

	jmp	2f

1:
	mov	BTreeNode.keys(%rax, %rcx, 1<<2), %esi
	lea	(%rax, %rsi), %rsi
	mov	BTreeNode.children + 1<<2(%rax, %rcx, 1<<2), %edx
	call	BTreeNode_add
	incq	CNT(%rbp)

2:
	mov	CH2(%rbp), %rax
	mov	CNT(%rbp), %rcx
	cmp	BTreeNode.len(%rax), %ecx
	jl	1b

	# Move children of the parent left by one
	mov	PRT(%rbp), %rax
	mov	IDX(%rbp), %rcx
	lea	BTreeNode.children + 1<<3(%rax, %rcx, 1<<2), %rsi
	lea	BTreeNode.children + 1<<2(%rax, %rcx, 1<<2), %rdi
	mov	$B<<1, %rcx
	sub	IDX(%rbp), %rcx
	rep	movsl

	# Move NIL into the last child on the parent
	movl	$NIL, BTreeNode.children + B<<2 - 1<<2(%rax)

	# Free the second child
	mov	CH2(%rbp), %rdi
	call	free

	# Restore params
	mov	PRT(%rbp), %rdi
	mov	IDX(%rbp), %rsi
	mov	CH1(%rbp), %rcx
	mov	CH2(%rbp), %rdx

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private	_BTree_add_recursive
# @description	Recursive add utility
# @param	%rdi	BTree
# @param	%rsi	Value to add
# @param	%rdx	Index of a node/subtree
# @return	%rax	A BTreeNode if a new one was created via a split, NULL (no split), or a 
#			negative value (which indicates an error)
.equ	THIS, -8
.equ	VALU, -16
.equ	NIDX, -24
.equ	NODE, -32
.equ	SPLT, -40
.equ	RET, -48
_BTree_add_recursive:
	push	%rbp
	mov	%rsp, %rbp

	sub	$48, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, VALU(%rbp)
	mov	%rdx, NIDX(%rbp)
	movq	$NULL, RET(%rbp)

	# Allocate a buffer to load a node from disk for processing ...
	mov	$BTREENODE_SIZE, %rdi
	call	alloc
	mov	%rax, NODE(%rbp)

	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi		# BlockStore
	mov	NIDX(%rbp), %rsi		# Node idx
	mov	%rax, %rdx			# Node buffer
	call	BlockStore_read

	mov	%rdx, %rdi			# Populated node (buffer)
	mov	VALU(%rbp), %rsi
	call	_BTreeNode_findit

	# Check if key ALREADY exists on a node. If this is the case we bypass everything
	test	%rax, %rax

	# Conditionally set RET to the findit outcome if it is < 0
	mov	RET(%rbp), %rcx
	cmovs	%rax, %rcx
	mov	%rcx, RET(%rbp)
	js	4f

	# At this point we can upgrade the return value to NULL, since the node wasn't found ...
	mov	BTreeNode.children(%rdi, %rax, 1<<2), %edx	# Child idx to follow down the tree
	test	%edx, %edx
	jns	1f

	# Children was NIL for this key so we can just store it on this node
	call	BTreeNode_add
	jmp	2f

1:
	# Children existed for this key so we need to progress deeper into the tree ...
	mov	THIS(%rbp), %rdi
	call	_BTree_add_recursive
	mov	%rax, RET(%rbp)

	test	%rax, %rax
	js	4f
	jz	4f

	mov	%rax, SPLT(%rbp)
	# Finish processing on split node (%rax)
	# Obtain/store the string value of key on split node to be the sole value on the new root
	mov	BTreeNode.keys(%rax), %ecx	# Get key at idx 0 of split node
	lea	(%rax, %rcx), %rdi		# Get value of idx 0 of split node

	# FIXME: We have a chicken and egg situation where we can't remove the 0th key / save the
	# split node to the blockstore BEFORE adding it to the target. We can't add to the target
	# BEFORE saving to the blockstore (to get the child id). To work around this we temporarily
	# store the value on the stack
	call	strlen
	# Make a multiple of 8
	add	$7, %rax	
	and	$-8, %rax

	sub	%rax, %rsp
	mov	%rax, %rcx
	mov	%rdi, %rsi
	mov	%rsp, %rdi
	rep	movsb

	# Remove key 0 from the split node
	mov	SPLT(%rbp), %rdi
	mov	$0, %rsi
	call	BTreeNode_remove

	# Write the split node to disk
	mov	%rdi, %rsi			# Split node
	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi		# BlockStore
	call	BlockStore_place

	# Add the 0th key we removed from the split node (and BlockStore idx) to the target
	mov	NODE(%rbp), %rdi
	mov	%rsp, %rsi
	mov	%rax, %rdx
	call	BTreeNode_add

	# Done with the split node now so we can call free
	mov	SPLT(%rbp), %rdi
	call	free

	# Null out return value because we handled the split. If it is split again the return value
	# will be overwritten there
	movq	$NULL, RET(%rbp)

2:
	# In either case we arrive here after a key was added to the target node and we need to 
	# check for overflow and persist it to disk
	mov	NODE(%rbp), %rdi
	cmpl	$B<<1, BTreeNode.len(%rdi)
	jl	3f

	call	BTreeNode_split
	mov	%rax, RET(%rbp)

3:
	# Save the current node at this level (%rdi) to disk
	mov	%rdi, %rdx			# Populated node (buffer)
	mov	THIS(%rbp), %rdi
	mov	BTree.bs(%rdi), %rdi		# BlockStore
	mov	NIDX(%rbp), %rsi		# Node idx
	call	BlockStore_write

4:
	# Free the populated node (buffer)
	mov	NODE(%rbp), %rdi
	call	free

	# Restore parameters
	mov	THIS(%rbp), %rdi
	mov	VALU(%rbp), %rsi
	mov	NIDX(%rbp), %rdx

	mov	RET(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret
# @public	BTreeNode_ctor
# @description	Constructor for a BTreeNode
# @return	%rax	BTreeNode
.equ	THIS, -8
BTreeNode_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp

	mov	$BTREENODE_SIZE, %rdi
	call	alloc
	mov	%rax, THIS(%rbp)

	# Zero out the node to avoid storing any residual garbage bits
	mov	%rax, %rdi
	xor	%rax, %rax
	mov	$BTREENODE_SIZE, %rcx
	rep	stosb

	# Set keys/child arrays to NIL (STOSL)
	mov	THIS(%rbp), %rax
	lea	BTreeNode.keys(%rax), %rdi		# Destination
	mov	$NIL, %rax				# Value
	mov	$B<<2 + 1, %rcx				# Count
	rep	stosl

	# Populate heap pointer and key length
	mov	THIS(%rbp), %rax
	movl	$0, BTreeNode.len(%rax)
	movl	$BTREENODE_SIZE, BTreeNode.heap(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public	BTreeNode_add
# @description	Adds an item to a BTreeNode
# @param	%rdi	BTreeNode
# @param	%rsi	Item to add
# @param	%rdx	Child index (in BlockStore). The child is the next greatest in the sequence
# @return	%rax	True on success, FALSE on failure
.equ	THIS, -8
.equ	ITEM, -16
.equ	CHLD, -24
.equ	IDX, -32
BTreeNode_add:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, ITEM(%rbp)
	mov	%rdx, CHLD(%rbp)

	call	_BTreeNode_findit
	mov	%rax, IDX(%rbp)

	# Check if item is already in the node, and return false if it is ...
	test	%rax, %rax
	mov	$FALSE, %rax
	js	1f

	mov	%rsi, %rdi
	call	strlen

	# Move the item onto the heap (MOVSB)
	mov	THIS(%rbp), %rdi
	sub	%eax, BTreeNode.heap(%rdi)			# Update the heap pointer
	mov	BTreeNode.heap(%rdi), %edx
	lea	(%rdi, %rdx), %rdi				# Destination (MOVSB)
	mov	%rax, %rcx					# Number of moves (MOVSB)
	rep	movsb

	# Shift keys right by one element to make room for the new key (MOVSL)
	mov	THIS(%rbp), %rdi
	mov	IDX(%rbp), %rax
	std
	mov	$B<<1 - 1, %rcx
	lea	BTreeNode.keys - 1<<2(%rdi, %rcx, 1<<2), %rsi		# Source
	lea	BTreeNode.keys(%rdi, %rcx, 1<<2), %rdi			# Destination
	sub	%rax, %rcx						# No. of moves
	rep	movsl

	# Shift children right by one element to make room for the new child (MOVSL)
	mov	THIS(%rbp), %rdi
	mov	$B<<1 - 1, %rcx
	lea	BTreeNode.children(%rdi, %rcx, 1<<2), %rsi		# Source
	lea	BTreeNode.children + 1<<2(%rdi, %rcx, 1<<2), %rdi	# Destination
	sub	%rax, %rcx						# No. of moves
	rep	movsl
	cld

	# Insert the new key which is just the current heap pointer
	mov	THIS(%rbp), %rdi
	mov	BTreeNode.heap(%rdi), %ecx
	mov	%ecx, BTreeNode.keys(%rdi, %rax, 1<<2)

	# Insert the new child as the next child in sequence
	mov	CHLD(%rbp), %rcx
	mov	%ecx, BTreeNode.children + 1<<2(%rdi, %rax, 1<<2)

	# Increment the length
	incl	BTreeNode.len(%rdi)

	# Return value
	mov	$TRUE, %rax

1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public	BTreeNode_remove
# @description	Removes an item to a BTreeNode
# @param	%rdi	BTreeNode
# @param	%rsi	Index to remove
# @return	%rax	True on success, FALSE on failure
.equ	THIS, -8
.equ	IDX, -16
.equ	HPOS, -24
BTreeNode_remove:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, IDX(%rbp)

	# Check for out of bounds
	xor	%rax, %rax			# Default return value if out of bounds
	cmp	%esi, BTreeNode.len(%rdi)
	jc	4f				# If there's carry it's either too big or negative
	jz	4f				# Also need to check for equals

	# Determine the string length of the item
	mov	BTreeNode.keys(%rdi, %rsi, 1<<2), %eax	# Heap offset
	mov	%rax, HPOS(%rbp)
	lea	(%rdi, %rax), %rdi
	call	strlen

	mov	THIS(%rbp), %rdi
	mov	HPOS(%rbp), %rcx		# Heap offset of removed element's string value
	xor	%rdx, %rdx			# Loop counter
	jmp	4f

1:
	# Check for offsets which are LESS THAN the offset of the element being removed
	cmp	%ecx, BTreeNode.keys(%rdi, %rdx, 1<<2)
	jge	2f

	# These offsets need to be INCREMENTED exactly by the string length
	add	%eax, BTreeNode.keys(%rdi, %rdx, 1<<2)

2:
	# Check if we are at an index GREATER THAN the index being removed, if not we are done
	cmp	%rsi, %rdx
	jle	3f

	# Move each key which is AFTER the removed to the left by one position
	mov	BTreeNode.keys(%rdi, %rdx, 1<<2), %r8d
	mov	%r8d, BTreeNode.keys - 1<<2(%rdi, %rdx, 1<<2)

3:
	inc	%rdx

4:
	cmp	BTreeNode.len(%rdi), %edx
	jl	1b

	# Move NIL into the last key
	movl	$NIL, BTreeNode.keys - 1<<2(%rdi, %rdx, 1<<2)

	# Remove the item's string from the heap (MOVSB)
	std
	lea	-1(%rdi, %rcx), %rsi		# Source
	sub	BTreeNode.heap(%rdi), %ecx	# Number of moves (item position minus heap)
	lea	(%rsi, %rax), %rdi		# Destination
	rep	movsb
	cld

	# Restore parameter registers
	mov	THIS(%rbp), %rdi
	mov	IDX(%rbp), %rsi

	# Update the heap
	add	%eax, BTreeNode.heap(%rdi)

	# Decrease the length
	decl	BTreeNode.len(%rdi)

	# Return value
	mov	$TRUE, %rax

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private	_BTreeNode_findit
# @description	Searches keys (s) for the specified item (x), and returns the index (i) of the 
#		smallest such that a[i] > x or a[i] = nil
# @param	%rdi	BTreeNode
# @param	%rsi	Search item
# @return	%rax	The index of the item. If a match is found, findit returns a negative value
.equ	THIS, -8
.equ	ITEM, -16
.equ	LO, -24
.equ	HI, -32
.equ	IDX, -40
_BTreeNode_findit:
	push	%rbp
	mov	%rsp, %rbp

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, ITEM(%rbp)
	movq	$0, LO(%rbp)
	movq	$B<<1, HI(%rbp)
	jmp	4f

1:
	add	LO(%rbp), %rax
	shr	%rax
	mov	%rax, IDX(%rbp)

	mov	BTreeNode.keys(%rdi, %rax, 1<<2), %ecx
	test	%ecx, %ecx
	js	3f

	lea	(%rdi, %rcx), %rdi
	call	strcmp
	test	%rax, %rax

	mov	IDX(%rbp), %rax
	mov	THIS(%rbp), %rdi
	jz	5f
	jns	3f

	# Current key was less than the search
	mov	%rax, LO(%rbp)				# Make current key the new LO and increment
	incq	LO(%rbp)
	jmp	4f

3:
	# Current key was GREATER THAN the search or was NIL
	mov	%rax, HI(%rbp)				# Makes current key the new HI

4:
	mov	HI(%rbp), %rax
	cmp	LO(%rbp), %rax
	jne	1b

	mov	LO(%rbp), %rax
	jmp	6f

5:
	# Found it, return -i - 1
	mov	IDX(%rbp), %rax
	neg	%rax
	dec	%rax

6:
	mov	THIS(%rbp), %rdi
	mov	ITEM(%rbp), %rsi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public	BTreeNode_split
# @description	Creates a new node that adopts the children[B],...children[2B] and 
#		keys[B]..keys[B-1] from the target node
# @param	%rdi	BTreeNode
# @return	%rax	BTreeNode
.equ	THIS, -8
.equ	NODE, -16
.equ	IDX, -24
BTreeNode_split:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)

	call	BTreeNode_ctor
	mov	%rax, NODE(%rbp)

	mov	THIS(%rbp), %rdi

1:
	# FIXME: Consider unrolling these calls to BTreeNode_add and BTreeNode_remove to 
	# consolidate the number of moves/sorts. For example, while the heaps must still be updated
	# separately, the keys/children are already sorted and can be moved in a single movsl

	# Extract the key at index B
	mov	BTreeNode.keys + B<<2(%rdi), %ecx
	test	%ecx, %ecx
	js	2f

	# Add the key + child to the new node
	lea	(%rdi, %rcx), %rsi
	mov	NODE(%rbp), %rdi
	mov	$NIL, %rdx
	call	BTreeNode_add

	# Remove the key/child from the old node
	mov	THIS(%rbp), %rdi
	mov	$B, %rsi
	call	BTreeNode_remove
	jmp	1b

2:
	# Split children
	lea	BTreeNode.children + B<<2 + 1<<2(%rdi), %rsi
	mov	NODE(%rbp), %rax
	lea	BTreeNode.children(%rax), %rdi
	mov	$B, %rcx
	rep	movsl

	mov	THIS(%rbp), %rdi
	lea	BTreeNode.children + B<<2 + 1<<2(%rdi), %rdi
	mov	$NIL, %eax
	mov	$B, %rcx
	rep	stosl

	mov	THIS(%rbp), %rdi
	mov	NODE(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public	BTreeNode_merge
# @description	Merges BTreeNode 2 into BTreeNode 1
# @param	%rdi	BTreeNode 1
# @param	%rsi	BTreeNode 2
# @return	%rax	BTreeNode 1
.equ	THIS, -8
.equ	THAT, -16
BTreeNode_merge:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, THAT(%rbp)

	mov	%rbp, %rsp
	pop	%rbp
	ret
