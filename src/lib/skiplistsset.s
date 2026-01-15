# lib/skiplistsset.s - SkiplistSSet

.include	"common.inc"

.globl	SkiplistSSet_ctor, SkiplistSSet_find, SkiplistSSet_add, SkiplistSSet_remove
.globl	SkiplistSSet_log

# SkiplistSSet
	.struct	0
SkiplistSSet.head:
	.struct	SkiplistSSet.head + 1<<3
SkiplistSSet.height:
	.struct	SkiplistSSet.height + 1<<3
SkiplistSSet.size:
	.struct	SkiplistSSet.size + 1<<3
	.equ	SKIPLISTSSET_SIZE, .

# SkiplistSSetItem
	.struct	0
SkiplistSSetItem.next:
	.struct	SkiplistSSetItem.next + 1<<3
SkiplistSSetItem.height:
	.struct SkiplistSSetItem.height + 1<<3
SkiplistSSetItem.data:
	.struct	SkiplistSSetItem.data + 1<<3
	.equ	SKIPLISTSSETITEM_SIZE, .

.equ	MAX_HEIGHT, 1<<6			# 64 is the highest possible random height

.section .rodata

lfeed:
	.byte	LF, NULL
comma:
	.ascii	",\n\0"
sdelim:
	.ascii	"[ \0"
mdelim:
	.ascii	", \0"
edelim:
	.ascii	" ]\n\0"
hlabel:
	.ascii	"Height => \0"
slabel:
	.ascii	"Size   => \0"
rlabel:
	.ascii	"Raw    => \0"
alabel:
	.ascii	" => \0"
rsdelim:
	.ascii	"{\0"
rmdelim:
	.ascii	" -> \0"
redelim:
	.ascii	"}\0"
spacer:
	.ascii	"  \0"
null:
	.ascii	"NULL\0"

.section .text

# @function	SkiplistSSet_ctor
# @description	Constructor for a SkiplistSSet
# @return	%rax	Pointer to the new SKiplistSSet
.equ	THIS, -8
.type	SkiplistSSet_ctor, @function
SkiplistSSet_ctor:
	push	%rbp
	mov	%rsp, %rbp

	# Space for locals
	sub	$8, %rsp

	mov	$SKIPLISTSSET_SIZE, %rdi
	call	alloc
	mov	%rax, THIS(%rbp)
	movq	$0, SkiplistSSet.height(%rax)

	# Create sentinel node with value NULL and height 1
	mov	$NULL, %rdi
	mov	$MAX_HEIGHT - 1, %rsi
	call	add_node

	mov	%rax, %rcx
	mov	THIS(%rbp), %rax
	mov	%rcx, SkiplistSSet.head(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	SkiplistSSet_find
# @description	Finds a value in the set
# @param	%rdi	Pointer to the SkiplistSSet
# @param	%rsi	The element to find
# @return	%rax	The found element or NULL on failure
.equ	THIS, -8
.equ	ELEM, -16
.equ	CURR, -24
.equ	NEXT, -32
.equ	CTR, -40
.type	SkiplistSSet_find, @function
SkiplistSSet_find:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, ELEM(%rbp)
	mov	SkiplistSSet.head(%rdi), %rax
	mov	%rax, CURR(%rbp)
	mov	SkiplistSSet.height(%rdi), %rcx
	mov	%rcx, CTR(%rbp)

	jmp	4f

1:
	mov	NEXT(%rbp), %rax
	mov	%rax, CURR(%rbp)
	mov	CTR(%rbp), %rcx

2:
	mov	SkiplistSSetItem.next(%rax), %rax
	mov	(%rax, %rcx, 1<<3), %rax
	mov	%rax, NEXT(%rbp)
	cmp	$NULL, %rax
	je	3f

	mov	SkiplistSSetItem.data(%rax), %rdi
	mov	ELEM(%rbp), %rsi
	call	strcmp

	cmp	$0, %rax
	jl	1b

3:
	decq	CTR(%rbp)
	mov	CURR(%rbp), %rax
	mov	CTR(%rbp), %rcx

4:
	cmp	$0, %rcx
	jge	2b

	mov	SkiplistSSetItem.next(%rax), %rax
	mov	(%rax), %rax
	cmp	$NULL, %rax
	je	4f

	mov	SkiplistSSetItem.data(%rax), %rax

4:
	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	SkiplistSSet_add
# @description	Adds an element to the set
# @param	%rdi	Pointer to the SkiplistSSet
# @param	%rsi	The element to add
# @return	%rax	The added element
.equ	THIS, -8	# This pointer
.equ	VAL, -16	# Value to add
.equ	CTR, -24	# Counter for use in loops
.equ	CURR, -32	# "Current" node pointer for use in loops
.equ	NEXT, -40	# "Next" node pointer for use in loops
.equ	CMP, -48	# Cached result of an strcmp comparison
.type	SkiplistSSet_add, @function
SkiplistSSet_add:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$48, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, VAL(%rbp)

	# Initialize "current" node and loop "counter"
	mov	SkiplistSSet.head(%rdi), %rax
	mov	%rax, CURR(%rbp)			# Start are "head"
	mov	SkiplistSSet.height(%rdi), %rax
	mov	%rax, CTR(%rbp)				# Start loop "counter" at list height

	# Intialize stack space for us to record the "search path"
	sub	$MAX_HEIGHT * 8, %rsp				# Space for height 64
	jmp	5f

1:
	# Inner loop for when "next" is not null and the "value" at next is lexicographically less
	# than the value we are adding, which means the value belongs later in the list
	mov	NEXT(%rbp), %rax
	mov	%rax, CURR(%rbp)

2:
	# Inner loop condition
	mov	CURR(%rbp), %rax
	mov	CTR(%rbp), %rcx
	mov	SkiplistSSetItem.next(%rax), %rax
	mov	(%rax, %rcx, 1<<3), %rax
	mov	%rax, NEXT(%rbp)
	cmp	$NULL, %rax
	je	3f

	mov	SkiplistSSetItem.data(%rax), %rdi
	mov	VAL(%rbp), %rsi
	call	strcmp
	mov	%rax, CMP(%rbp)				# Cache result of strcmp
	cmp	$0, %rax
	jl	1b

3:
	# Outer loop exit hatch. If the "next" node is NOT the end of the list and we find in there
	# the value we are adding already exists there, we are done and need to exit
	mov	NEXT(%rbp), %rax
	cmp	$NULL, %rax
	je	4f

	# Check if value was found to be equal
	cmpq	$0, CMP(%rbp)
	je	10f

4:
	# Push "current" node onto the stack in order to preserve the search path we followed
	mov	CURR(%rbp), %rax
	mov	CTR(%rbp), %rcx
	mov	%rax, (%rsp, %rcx, 1<<3)
	decq	CTR(%rbp)

5:
	# Outer loop condition
	cmpq	$0, CTR(%rbp)
	jge	2b

	# Add new node
	call	random_height
	mov	VAL(%rbp), %rdi
	mov	%rax, %rsi
	call	add_node

	mov	THIS(%rbp), %rdi
	mov	SkiplistSSetItem.height(%rax), %rcx
	jmp	7f


6:
	# We increment the height of our skiplist and push a "head" node to the search path ...
	incq	SkiplistSSet.height(%rdi)
	mov	SkiplistSSet.height(%rdi), %rsi
	mov	SkiplistSSet.head(%rdi), %rdx
	mov	%rdx, (%rsp, %rsi, 1<<3)

7:
	# ... while the height of the skiplist is less than the height of the new node
	cmp	%rcx, SkiplistSSet.height(%rdi)
	jl	6b

	# Lastly we need to "link" the new node into the list. We start at the top of the node and
	# move down
	xor	%rcx, %rcx
	jmp	9f

8:
	# Insert the new node into the search path ...
	mov	(%rsp, %rcx, 1<<3), %rdx
	mov	SkiplistSSetItem.next(%rdx), %rdx	# Next of most recent search path node
	mov	SkiplistSSetItem.next(%rax), %r8	# Next of new node
	mov	(%rdx, %rcx, 1<<3), %rsi		# Get the next value from the search path
	mov	%rsi, (%r8, %rcx, 1<<3)			# And insert that as next of the new node
	mov	%rax, (%rdx, %rcx, 1<<3)		# Make the new node point to next in path
	inc	%rcx

9:
	cmp	SkiplistSSetItem.height(%rax), %rcx
	jle	8b

	incq	SkiplistSSet.size(%rdi)

10:
	mov	THIS(%rbp), %rdi
	mov	VAL(%rbp), %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	SkiplistSSet_remove
# @description	Remove an item from a set
# @param	%rdi	Pointer to the SkiplistSSet
# @param	%rsi	Element to remove
# @return	%rax	The removed element or NULL on failure
.equ	THIS, -8
.equ	ELEM, -16
.equ	CURR, -24
.equ	CTR, -32
.equ	NEXT, -40
.equ	FOUND, -48
.type	SkiplistSSet_remove, @function
SkiplistSSet_remove:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$48, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, ELEM(%rbp)
	mov	SkiplistSSet.head(%rdi), %rax
	mov	%rax, CURR(%rbp)
	mov	SkiplistSSet.height(%rdi), %rcx
	mov	%rcx, CTR(%rbp)
	movq	$NULL, FOUND(%rbp)

	jmp	5f
1:
	mov	NEXT(%rbp), %rax
	mov	%rax, CURR(%rbp)

2:
	mov	CURR(%rbp), %rax
	mov	CTR(%rbp), %rcx
	mov	SkiplistSSetItem.next(%rax), %rax
	mov	(%rax, %rcx, 1<<3), %rax
	mov	%rax, NEXT(%rbp)

	cmp	$NULL, %rax
	je	4f

	mov	SkiplistSSetItem.data(%rax), %rdi
	mov	ELEM(%rbp), %rsi
	call	strcmp
	cmp	$0, %rax
	jl	1b					# Element is < our search so move to next
	je	3f					# We found out element
	jg	4f					# Element is > our search, so go down level

3:
	mov	CURR(%rbp), %rax
	mov	CTR(%rbp), %rcx

	# Get the "next" of "next"
	mov	NEXT(%rbp), %rdx
	mov	%rdx, FOUND(%rbp)
	mov	SkiplistSSetItem.next(%rdx), %rdx
	mov	(%rdx, %rcx, 1<<3), %rdx

	# And insert that into where the matched element was found
	mov	SkiplistSSetItem.next(%rax), %rax
	mov	%rdx, (%rax, %rcx, 1<<3)

	# Check if the current node is the "head"
	mov	THIS(%rbp), %rdi
	mov	CURR(%rbp), %rax
	cmp	SkiplistSSet.head(%rdi), %rax
	jne	4f

	# Check if the next node is null
	cmp	$NULL, %rdx
	jne	4f

	# If the current node is the next and the next node is null we need to decrease the height
	decq	SkiplistSSet.height(%rdi)

4:
	decq	CTR(%rbp)

5:
	cmpq	$0, CTR(%rbp)
	jge	2b

	mov	FOUND(%rbp), %rax
	cmp	$NULL, %rax
	je	6f

	mov	%rax, %rdi
	call	free

	mov	ELEM(%rbp), %rax

6:
	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	SkiplistSSet_log
# @description	Log the innards of a SkiplistSSet
# @param	%rdi	Pointer to a SkiplistSSet
# @return	void
.equ	THIS, -8
.equ	CURR, -16
.equ	NEXT, -24
.equ	CTR, -32
.equ	C1, -40
.equ	N1, -48
.type	SkiplistSSet_log, @function
SkiplistSSet_log:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$48, %rsp
	mov	%rdi, THIS(%rbp)
	mov	SkiplistSSet.head(%rdi), %rax
	mov	%rax, CURR(%rbp)
	mov	SkiplistSSetItem.next(%rax), %rax
	mov	(%rax), %rax
	mov	%rax, NEXT(%rbp)

	mov	$sdelim, %rdi
	call	log
	jmp	2f

1:
	mov	NEXT(%rbp), %rax
	mov	SkiplistSSetItem.data(%rax), %rdi
	call	log

	mov	NEXT(%rbp), %rax
	mov	SkiplistSSetItem.next(%rax), %rax
	mov	(%rax), %rax
	mov	%rax, NEXT(%rbp)
	cmp	$NULL, %rax
	je	2f

	mov	$mdelim, %rdi
	call	log

	mov	NEXT(%rbp), %rax
2:
	cmpq	$NULL, NEXT(%rbp)
	jne	1b

	mov	$edelim, %rdi
	call	log

	mov	$lfeed, %rdi
	call	log

	mov	$slabel, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	SkiplistSSet.size(%rdi), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$lfeed, %rdi
	call	log

	mov	$hlabel, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	SkiplistSSet.height(%rdi), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$lfeed, %rdi
	call	log

	mov	$rlabel, %rdi
	call	log

	mov	$rsdelim, %rdi
	call	log

	mov	$lfeed, %rdi
	call	log

	# Raw view goes here ....
	mov	THIS(%rbp), %rdi
	mov	SkiplistSSet.head(%rdi), %rax
	mov	%rax, CURR(%rbp)
	jmp	4f

3:
	mov	$spacer, %rdi
	call	log

	mov	NEXT(%rbp), %rax
	mov	SkiplistSSetItem.data(%rax), %rdi
	call	log

	mov	$alabel, %rdi
	call	log

	mov	$rsdelim, %rdi
	call	log

	# Heights go here:
	mov	NEXT(%rbp), %rcx
	mov	SkiplistSSetItem.height(%rcx), %rcx
	mov	%rcx, CTR(%rbp)
	jmp	6f

5:
	mov	$lfeed, %rdi
	call	log
	
	mov	$spacer, %rdi
	call	log

	mov	$spacer, %rdi
	call	log

	mov	CTR(%rbp), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$alabel, %rdi
	call	log

	mov	$rsdelim, %rdi
	call	log

	mov	$spacer, %rdi
	call	log

	mov	%rax, N1(%rbp)
	# Loop elements in chain
	mov	NEXT(%rbp), %rax
	mov	CTR(%rbp), %rcx
	mov	%rax, C1(%rbp)
	jmp	8f
7:
	mov	SkiplistSSetItem.data(%rax), %rdi
	call	log

	mov	$rmdelim, %rdi
	call	log

	mov	N1(%rbp), %rax
	mov	%rax, C1(%rbp)
8:
	mov	C1(%rbp), %rax
	mov	CTR(%rbp), %rcx
	mov	SkiplistSSetItem.next(%rax), %rax
	mov	(%rax, %rcx, 1<<3), %rax
	mov	%rax, N1(%rbp)
	cmp	$NULL, %rax
	jne	7b

	mov	$null, %rdi
	call	log

	mov	$spacer, %rdi
	call	log
	mov	$redelim, %rdi
	call	log

	decq	CTR(%rbp)
6:
	cmpq	$0, CTR(%rbp)
	jge	5b

	mov	$lfeed, %rdi
	call	log

	mov	$spacer, %rdi
	call	log

	mov	$redelim, %rdi
	call	log

	mov	$comma, %rdi
	call	log

	mov	NEXT(%rbp), %rax
	mov	%rax, CURR(%rbp)

4:
	mov	CURR(%rbp), %rax
	mov	SkiplistSSetItem.next(%rax), %rax
	mov	(%rax), %rax
	mov	%rax, NEXT(%rbp)
	cmp	$NULL, %rax
	jne	3b

	mov	$redelim, %rdi
	call	log

	mov	$lfeed, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	add_node
# @description	File private helper that adds a node
# @param	%rdi	Value of the node
# @param	%rsi	Height of the node
# @return	%rax	Pointer to the new node
.equ	VALUE, -8
.equ	HEIGHT, -16
.equ	THIS, -24
add_node:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$24, %rsp
	mov	%rdi, VALUE(%rbp)
	mov	%rsi, HEIGHT(%rbp)

	# Allocation for the item itself
	mov	$SKIPLISTSSETITEM_SIZE, %rdi
	call	alloc
	mov	%rax, THIS(%rbp)

	# Allocation for "next" array
	mov	HEIGHT(%rbp), %rdi
	inc	%rdi
	imul	$8, %rdi
	call	alloc
	mov	%rax, %rcx				# Save "next" list pointer in %rcx

	# Assign attributes
	mov	THIS(%rbp), %rax
	mov	%rcx, SkiplistSSetItem.next(%rax)	# Next list
	mov	HEIGHT(%rbp), %rcx
	mov	%rcx, SkiplistSSetItem.height(%rax)	# Height
	mov	VALUE(%rbp), %rcx
	mov	%rcx, SkiplistSSetItem.data(%rax)	# Value
	
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	random_height
# @description	File private helper to calculate a random height for a node
# @return	%rax	The calculated height
random_height:
	xor	%rax, %rax

1:
	rdrand	%rcx
	jnc	1b		# This can fail in which case we need to retry

	jmp	3f
2:
	shr	$1, %rcx
	inc	%rax
3:
	mov	$1, %rdx
	and	%rcx, %rdx
	cmp	$0, %rdx
	jne	2b

	ret
