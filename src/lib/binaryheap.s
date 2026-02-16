# lib/binaryheap.s - BinaryHeap

.include	"common.inc"

.globl	BinaryHeap_ctor, BinaryHeap_add, BinaryHeap_remove, BinaryHeap_log, BinaryHeap_trickle_down

# BinaryHeap
	.struct	0
BinaryHeap.data:
	.struct	BinaryHeap.data + 1<<3
BinaryHeap.len:
	.struct	BinaryHeap.len + 1<<2
BinaryHeap.size:
	.struct	BinaryHeap.size + 1<<2
	.equ	BINARYHEAP_SIZE, .

.equ	BINARYHEAP_MIN_SIZE, 2

.section .rodata

newline:
	.byte	LF, NULL
len_label:
	.ascii	"Length => \0"
size_label:
	.ascii	"Size   => \0"
raw_label:
	.ascii	"Raw    => \0"
tree_label:
	.ascii	"Tree   => {\0"
tree_end:
	.ascii	"}\n\0"
raw_start:
	.ascii	"[ \0"
raw_mid:
	.ascii	", \0"
raw_end:
	.ascii	" ]\0"
node_start:
	.ascii	"[\0"
node_end:
	.ascii	"]\0"
vert:
	.ascii	"|--\0"
horz:
	.ascii	"---\0"
spacer:
	.byte	SPACE, SPACE, NULL

.section .text

# @function	BinaryHeap_ctor
# @description	Constructor for a BinaryHeap
# @return	%rax	Pointer to the new BinaryHeap
.equ	DATA, -8
.type	BinaryHeap_ctor, @function
BinaryHeap_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp

	# Allocate backing array
	mov	$BINARYHEAP_MIN_SIZE * 1<<3, %rdi
	call	alloc
	mov	%rax, DATA(%rbp)

	# Allocate BinaryHeap
	mov	$BINARYHEAP_SIZE, %rdi
	call	alloc

	mov	DATA(%rbp), %rcx
	mov	%rcx, BinaryHeap.data(%rax)
	movl	$0, BinaryHeap.len(%rax)
	movl	$BINARYHEAP_MIN_SIZE, BinaryHeap.size(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinaryHeap_add
# @description	Adds an item to the BinaryHeap
# @param	%rdi	Pointer to the BinaryHeap
# @param	%rsi	The item to add
# @return	%rax	The added item on success, NULL on failure
.equ	ITEM, -8
.type	BinaryHeap_add, @function
BinaryHeap_add:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rsi, ITEM(%rbp)

	# Check if a resize is needed
	mov	BinaryHeap.len(%rdi), %ecx
	cmp	%ecx, BinaryHeap.size(%rdi)
	jg	1f

	call	resize
	mov	ITEM(%rbp), %rsi

1:
	mov	BinaryHeap.data(%rdi), %rax
	mov	BinaryHeap.len(%rdi), %ecx
	mov	%rsi, (%rax, %rcx, 1<<3)

	mov	BinaryHeap.len(%rdi), %esi
	call	bubble_up

	incl	BinaryHeap.len(%rdi)
	mov	ITEM(%rbp), %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinaryHeap_remove
# @description	Removes the next item from the BinaryHeap
# @param	%rdi	Pointer to the BinaryHeap
# @return	%rax	The item
.equ	ITEM, -8
.type	BinaryHeap_remove, @function
BinaryHeap_remove:
	push	%rbp
	mov	%rsp, %rbp

	xor	%rax, %rax
	cmpl	$0, BinaryHeap.len(%rdi)
	je	2f

	sub	$8, %rsp

	# Capture and save the root of the tree (eg the "next" item)
	mov	BinaryHeap.data(%rdi), %rax
	mov	(%rax), %rcx
	mov	%rcx, ITEM(%rbp)

	# Get the "last" item in the backing array and locate it at the root
	mov	BinaryHeap.len(%rdi), %ecx
	mov	-8(%rax, %rcx, 1<<3), %rdx

	# Probably not necessary but will send NULL into here just for bookeeping / sanity
	movq	$NULL, -8(%rax, %rcx, 1<<3)
	mov	%rdx, (%rax)

	decl	BinaryHeap.len(%rdi)
	
	xor	%rsi, %rsi
	call	BinaryHeap_trickle_down

	mov	BinaryHeap.len(%rdi), %eax
	imul	$3, %rax
	cmp	BinaryHeap.size(%rdi), %eax
	jge	1f

	call	resize

1:
	mov	ITEM(%rbp), %rax

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinaryHeap_log
# @description	Logs the innards of a BinaryHeap
# @param	%rdi	Pointer to a BinaryHeap
# @return	%rax
.equ	THIS, -8
.equ	CTR, -16
.type	BinaryHeap_log, @function
BinaryHeap_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)

	mov	$len_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	BinaryHeap.len(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$size_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	BinaryHeap.size(%rdi), %edi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$raw_label, %rdi
	call	log

	mov	$raw_start, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	BinaryHeap.size(%rdi), %ecx
	movq	$0, CTR(%rbp)
	jmp	3f

1:
	cmp	BinaryHeap.len(%rdi), %ecx
	jge	2f

	mov	BinaryHeap.data(%rdi), %rax
	mov	(%rax, %rcx, 1<<3), %rdi
	call	log

2:
	incq	CTR(%rbp)

	mov	THIS(%rbp), %rdi
	mov	CTR(%rbp), %rcx
	cmp	BinaryHeap.size(%rdi), %ecx
	je	3f

	mov	$raw_mid, %rdi
	call	log

	mov	THIS(%rbp), %rdi
3:
	mov	CTR(%rbp), %rcx
	cmp	BinaryHeap.size(%rdi), %ecx
	jl	1b

	mov	$raw_end, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$tree_label, %rdi
	call	log

	mov	$newline, %rdi
	call	log


	mov	THIS(%rbp), %rdi
	xor	%rsi, %rsi
	mov	$log_node, %rdx
	xor	%rcx, %rcx
	call	traverse

	mov	$tree_end, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	log_node
# @description	File private helper to log an individual node
# @param	%rdi	The value of the current node
# @param	%rsi	The current depth of the tree
# @return	void
.equ	DATA, -8
.equ	DPTH, -16
log_node:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, DATA(%rbp)
	mov	%rsi, DPTH(%rbp)

	mov	$spacer, %rdi
	call	log

	mov	DPTH(%rbp), %rsi
	test	%rsi, %rsi
	jz	2f

	mov	$vert, %rdi
	call	log

1:
	decq	DPTH(%rbp)
	cmpq	$0, DPTH(%rbp)
	je	2f

	mov	$horz, %rdi
	call	log
	jmp	1b

2:
	mov	$node_start, %rdi
	call	log

	mov	DATA(%rbp), %rdi
	call	log

	mov	$node_end, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	traverse
# @description	File private helper to traverse the BinaryHeap as a tree and invoke a callback
# @param	%rdi	Pointer to the BinaryHeap
# @param	%rsi	Current index
# @param	%rdx	A callback
# @param	%rcx	Current depth
# @return	void
.equ	THIS, -8
.equ	IDX, -16
.equ	FUNC, -24
.equ	DPTH, -32
traverse:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, IDX(%rbp)
	mov	%rdx, FUNC(%rbp)
	mov	%rcx, DPTH(%rbp)

	cmp	BinaryHeap.len(%rdi), %esi
	jge	2f

	mov	BinaryHeap.data(%rdi), %rax
	mov	(%rax, %rsi, 1<<3), %rdi
	mov	%rcx, %rsi
	call	*FUNC(%rbp)

	incq	DPTH(%rbp)

	# Restore all the things ...
	mov	THIS(%rbp), %rdi
	mov	IDX(%rbp), %rsi
	mov	FUNC(%rbp), %rdx
	mov	DPTH(%rbp), %rcx

	call	left

	cmp	BinaryHeap.len(%rdi), %eax
	jge	1f

	# Call ourselves with the "left" child index
	mov	%rax, %rsi
	call	traverse

1:
	# Restore all the things ...
	mov	THIS(%rbp), %rdi
	mov	IDX(%rbp), %rsi
	mov	FUNC(%rbp), %rdx
	mov	DPTH(%rbp), %rcx

	call	right

	cmp	BinaryHeap.len(%rdi), %eax
	jge	2f

	# Call ourselves with the "right" child index
	mov	%rax, %rsi
	call	traverse
	
2:
	mov	THIS(%rbp), %rdi

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	left
# @description	File private helper that given the index of an item returns the index of its left
#		child
# @param	%rdi	Pointer to the BinaryHeap
# @param	%rsi	The index of the item
# @return	%rax	The index of the left child
left:
	mov	%rsi, %rax
	shl	%rax
	inc	%rax
	ret

# @function	right
# @description	File private helper that given the index of an item returns the index of its right
#		child
# @param	%rdi	Pointer to the BinaryHeap
# @param	%rsi	The index of the item
# @return	%rax	The index of the right child
right:
	mov	%rsi, %rax
	inc	%rax
	shl	%rax
	ret

# @function	parent
# @description	File private helper that given the index of an item returns the index of its parent
# @param	%rdi	Pointer to the BinaryHeap
# @param	%rsi	The index of the item
# @return	%rax	The index of the parent
parent:
	mov	%rsi, %rax

	test	%rax, %rax
	jz	1f

	dec	%rax

1:
	shr	%rax
	ret

# @function	bubble_up
# @description	File private helper to maintain the heap property of a BinaryHeap after additions
# @param	%rdi	Pointer to the BinaryHeap
# @param	%rsi	The index of the item which was just added
# @return	void
.equ	THIS, -8
.equ	CIDX, -16	# Child index
.equ	PIDX, -24	# Parent index
bubble_up:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)

1:
	# Each iteration starts with the current child index in and the call to parent puts the 
	# parent index in %rax
	call	parent

	# Check if child index (i) has reached zero, if so we are done looping
	test	%rsi, %rsi
	jz	2f

	# Preserve indexes for call to strcmp
	mov	%rsi, CIDX(%rbp)
	mov	%rax, PIDX(%rbp)

	# Check if the heap property exists at this level, if so we are done looping
	mov	BinaryHeap.data(%rdi), %rcx
	mov	(%rcx, %rsi, 1<<3), %rdi	# Value of child
	mov	(%rcx, %rax, 1<<3), %rsi	# Value of parent
	call	strcmp

	# Restore "this" after strcmp
	mov	THIS(%rbp), %rdi

	test	%rax, %rax
	jns	2f

	# Restore indexes after strcmp call
	mov	CIDX(%rbp), %rsi
	mov	PIDX(%rbp), %rax

	# Swap parent and child values
	mov	BinaryHeap.data(%rdi), %rcx
	mov	(%rcx, %rsi, 1<<3), %r8		# Value of child
	mov	(%rcx, %rax, 1<<3), %r9		# Value of parent
	mov	%r8, (%rcx, %rax, 1<<3)
	mov	%r9, (%rcx, %rsi, 1<<3)
	mov	%rax, %rsi
	jmp	1b

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	resize
# @description	File private helper to resize the backing array to two times the length
# @param	%rdi	Pointer to the BinaryHeap
# @return	void
.equ	THIS, -8
.equ	SIZE, -16
.equ	DATA, -24
resize:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)

	# Calculate the new size
	mov	BinaryHeap.len(%rdi), %edi
	shl	%rdi				# New size is = 2 * length

	# Ensure we don't drop below zero because then that would be unrecoverable
	cmp	$BINARYHEAP_MIN_SIZE, %rdi
	jle	1f

	mov	%rdi, SIZE(%rbp)

	# Allocate a new backing array
	shl	$3, %rdi
	call	alloc
	mov	%rax, DATA(%rbp)		# Save the pointer to DATA since movsq will change

	# Migrate the data over to the new backing array
	mov	%rax, %rdi			# Destination for movsq
	mov	THIS(%rbp), %rax
	mov	BinaryHeap.len(%rax), %ecx	# Count for rep
	mov	BinaryHeap.data(%rax), %rsi	# Source for movsq
	rep	movsq

	# Free the old backing array
	mov	BinaryHeap.data(%rax), %rdi
	call	free

	mov	THIS(%rbp), %rdi
	mov	DATA(%rbp), %rax
	mov	%rax, BinaryHeap.data(%rdi)
	mov	SIZE(%rbp), %rax
	mov	%eax, BinaryHeap.size(%rdi)
	
1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	BinaryHeap_trickle_down
# @description	Helper to restore the heap property after a removal
# @param	%rdi	Pointer to the BinaryHeap
# @param	%rsi	Index of last removed item (in backing array) which may violate heap
# @return	void
.equ	THIS, -8
.equ	CIDX, -16
.equ	PIDX, -24
.equ	RGHT, -32
.equ	LEFT, -40
BinaryHeap_trickle_down:
	push	%rbp
	mov	%rsp, %rbp

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	movq	%rsi, CIDX(%rbp)
	jmp	6f

1:
	# Reset parent index to -1
	movq	$-1, PIDX(%rbp)

	call	right
	mov	%rax, RGHT(%rbp)

	cmp	BinaryHeap.len(%rdi), %eax
	jge	3f

	mov	BinaryHeap.data(%rdi), %rcx
	mov	(%rcx, %rax, 1<<3), %rdi	# Right child of target
	mov	(%rcx, %rsi, 1<<3), %rsi	# Target
	call	strcmp

	# Restore "this" pointer (%rdi) and target index (%rsi)
	mov	THIS(%rbp), %rdi
	mov	CIDX(%rbp), %rsi

	test	%rax, %rax
	jns	3f

	call	left
	mov	%rax, LEFT(%rbp)

	mov	BinaryHeap.data(%rdi), %rcx
	mov	(%rcx, %rax, 1<<3), %rdi
	mov	RGHT(%rbp), %rax
	mov	(%rcx, %rax, 1<<3), %rsi
	call	strcmp

	# Restore "this" pointer (%rdi) and target index (%rsi)
	mov	THIS(%rbp), %rdi
	mov	CIDX(%rbp), %rsi

	test	%rax, %rax
	jns	2f

	mov	LEFT(%rbp), %rax
	mov	%rax, PIDX(%rbp)
	jmp	4f

2:
	mov	RGHT(%rbp), %rax
	mov	%rax, PIDX(%rbp)
	jmp	4f

3:
	call	left
	mov	%rax, LEFT(%rbp)

	cmp	BinaryHeap.len(%rdi), %eax
	jge	4f

	mov	BinaryHeap.data(%rdi), %rcx
	mov	(%rcx, %rax, 1<<3), %rdi	# Left child of target
	mov	(%rcx, %rsi, 1<<3), %rsi	# Target
	call	strcmp

	# Restore "this" pointer (%rdi) and target index (%rsi)
	mov	THIS(%rbp), %rdi
	mov	CIDX(%rbp), %rsi

	mov	CIDX(%rbp), %rsi

	test	%rax, %rax
	jns	4f

	mov	LEFT(%rbp), %rax
	mov	%rax, PIDX(%rbp)

4:
	mov	PIDX(%rbp), %rax
	test	%rax, %rax
	js	5f

	# Swap parent and child values
	mov	BinaryHeap.data(%rdi), %rcx
	mov	(%rcx, %rsi, 1<<3), %r8		# Value of child
	mov	(%rcx, %rax, 1<<3), %r9		# Value of parent
	mov	%r8, (%rcx, %rax, 1<<3)
	mov	%r9, (%rcx, %rsi, 1<<3)

5:
	mov	PIDX(%rbp), %rsi
	mov	%rsi, CIDX(%rbp)

6:
	test	%rsi, %rsi
	jns	1b

	mov	%rbp, %rsp
	pop	%rbp
	ret
