# lib/meldableheap.s - MeldableHeap

.include	"common.inc"

.globl	MeldableHeap_ctor, MeldableHeap_add, MeldableHeap_remove, MeldableHeap_log

# MeldableHeap
	.struct	0
MeldableHeap.root:
	.struct	MeldableHeap.root + 1<<3
MeldableHeap.size:
	.struct	MeldableHeap.size + 1<<3
.equ	MELDABLEHEAP_SIZE, .

# MeldableHeapNode
	.struct	0
MeldableHeapNode.data:
	.struct	MeldableHeapNode.data + 1<<3
MeldableHeapNode.parent:
	.struct	MeldableHeapNode.parent + 1<<3
MeldableHeapNode.left:
	.struct	MeldableHeapNode.left + 1<<3
MeldableHeapNode.right:
	.struct	MeldableHeapNode.right + 1<<3
.equ	MELDABLEHEAPNODE_SIZE, .

.section .rodata

newline:
	.byte	LF, NULL
height_label:
	.ascii	"Height => \0"
size_label:
	.ascii	"Size   => \0"
raw_label:
	.ascii	"Raw    => {\n\0"
spacer:
	.byte	SPACE, SPACE, NULL
horz:
	.ascii	"---\0"
vert:
	.ascii	"|--\0"
raw_end:
	.ascii	"}\n\0"
raw_vlwrap:
	.ascii	"[\0"
raw_vrwrap:
	.ascii	"]\0"

.section .text

# @function	MeldableHeap_ctor
# @description	Constructor for a MeldableHeap
# @return	%rax	Pointer to a new MeldableHeap
.type	MeldableHeap_ctor, @function
MeldableHeap_ctor:
	mov	$MELDABLEHEAP_SIZE, %rdi
	call	alloc

	movq	$NULL, MeldableHeap.root(%rax)
	movq	$0, MeldableHeap.size(%rax)

	ret

# @function	MeldableHeap_add
# @description	Adds a node to a MeldableHeap
# @param	%rdi	Pointer to a MeldableHeap
# @param	%rsi	Item to add
# @return	%rax	The added item
.equ	THIS, -8
.equ	NODE, -16
.type	MeldableHeap_add, @function
MeldableHeap_add:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	mov	%rsi, %rdi
	call	new_node
	mov	%rax, NODE(%rbp)

	mov	%rax, %rdi
	mov	THIS(%rbp), %rsi
	mov	MeldableHeap.root(%rsi), %rsi
	call	merge

	# Make the outcome of the merge operation the new "root"
	mov	THIS(%rbp), %rdi
	mov	%rax, MeldableHeap.root(%rdi)
	movq	$NULL, MeldableHeapNode.parent(%rax)
	incq	MeldableHeap.size(%rdi)

	# Tee up return value
	mov	NODE(%rbp), %rax
	mov	MeldableHeapNode.data(%rax), %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	MeldableHeap_remove
# @description	Remove the next queue item from a MeldableHeap
# @param	%rdi	Pointer to a MeldableHeap
# @return	%rax	The item
.equ	THIS, -8
.equ	DATA, -16
.type	MeldableHeap_remove, @function
MeldableHeap_remove:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	MeldableHeap.root(%rdi), %rdi

	# Check if we are already empty
	xor	%rax, %rax
	test	%rdi, %rdi
	jz	2f

	mov	MeldableHeapNode.data(%rdi), %rax
	mov	%rax, DATA(%rbp)

	mov	MeldableHeapNode.right(%rdi), %rsi	
	mov	MeldableHeapNode.left(%rdi), %rdi
	call	merge

	mov	THIS(%rbp), %rdi
	mov	%rax, MeldableHeap.root(%rdi)
	test	%rax, %rax

	# Skip decrementing count/setting parent if root is now NULL which means the tree is empty
	jz	1f
	movq	$NULL, MeldableHeapNode.parent(%rax)
	decq	MeldableHeap.size(%rdi)

1:
	# Stage return value
	mov	DATA(%rbp), %rax

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	MeldableHeap_log
# @description	Logs the innards of a MeldableHeap
# @param	%rdi	Pointer to a MeldableHeap
# @return	void
.equ	THIS, -8
.type	MeldableHeap_log, @function
MeldableHeap_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$size_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	MeldableHeap.size(%rdi), %rdi
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
	call	log

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
	decq	DEPTH(%rbp)
	cmpq	$0, DEPTH(%rbp)
	jle	2f

	mov	$horz, %rdi
	call	log
	jmp	1b

2:
	mov	$raw_vlwrap, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	MeldableHeapNode.data(%rdi), %rdi
	call	log

	mov	$raw_vrwrap, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	splice
# @function	new_node
# @description	Creates a new MeldableHeapNode
# @param	%rdi	The value of the node
# @return	%rax	Pointer to a new MeldableHeapNode
.equ	DATA, -8
new_node:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, DATA(%rbp)

	mov	$MELDABLEHEAPNODE_SIZE, %rdi
	call	alloc

	mov	DATA(%rbp), %rcx
	mov	%rcx, MeldableHeapNode.data(%rax)
	movq	$NULL, MeldableHeapNode.parent(%rax)
	movq	$NULL, MeldableHeapNode.left(%rax)
	movq	$NULL, MeldableHeapNode.right(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	merge
# @description	Merges two heap nodes, returning a a heap node that is the root of a heap that
#		contains all the elements in both trees
# @param	%rdi	Heap node 1
# @param	%rsi	Heap node 2
# @return	%rax	A MeldableHeapNode that is the root of a heap containing both subtrees
.equ	H1, -8
.equ	H2, -16
merge:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, H1(%rbp)
	mov	%rsi, H2(%rbp)

	test	%rdi, %rdi
	cmovz	%rsi, %rax
	jz	3f

	test	%rsi, %rsi
	cmovz	%rdi, %rax
	jz	3f

	mov	MeldableHeapNode.data(%rsi), %rdi
	mov	H1(%rbp), %rsi
	mov	MeldableHeapNode.data(%rsi), %rsi
	call	strcmp

	# Restore the subtrees
	mov	H1(%rbp), %rdi
	mov	H2(%rbp), %rsi

	test	%rax, %rax
	jns	1f

	# The root of heap 2 is LESS THAN the root of heap 1 so we swap them
	mov	%rdi, H2(%rbp)
	mov	%rsi, H1(%rbp)
	mov	H1(%rbp), %rdi
	mov	H2(%rbp), %rsi

1:
	call	random_bit
	test	%rax, %rax
	jz	2f

	mov	MeldableHeapNode.left(%rdi), %rdi
	call	merge

	mov	H1(%rbp), %rdi
	mov	%rdi, MeldableHeapNode.parent(%rax)
	mov	%rax, MeldableHeapNode.left(%rdi)
	mov	%rdi, %rax
	jmp	3f

2:
	mov	MeldableHeapNode.right(%rdi), %rdi
	call	merge

	mov	H1(%rbp), %rdi
	mov	%rdi, MeldableHeapNode.parent(%rax)
	mov	%rax, MeldableHeapNode.right(%rdi)
	mov	%rdi, %rax

3:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	random_bit
# @description	Return a random bit (1 / 0, TRUE / FALSE)
# @return	%rax	One or zero (e.g. TRUE or FALSE)
random_bit:
	rdrand	%rax
	jnc	random_bit

	and	$1, %rax
	ret
