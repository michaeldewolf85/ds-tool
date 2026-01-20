# lib/chainedhashtable.s - ChainedHashTable

.include	"common.inc"

.globl	ChainedHashTable_ctor, ChainedHashTable_add, ChainedHashTable_find, ChainedHashTable_remove

# ChainedHashTable
	.struct	0
ChainedHashTable.tab:
	.struct	ChainedHashTable.tab + 1<<3
ChainedHashTable.zee:
	.struct	ChainedHashTable.zee + 1<<3
ChainedHashTable.dim:
	.struct	ChainedHashTable.dim + 1<<2
ChainedHashTable.len:
	.struct	ChainedHashTable.len + 1<<2
	.equ	CHAINEDHASHTABLE_SIZE, .

.equ	START_DIMENSION, 1
.equ	INT_SIZE, 1<<5

.section .text

# @function	ChainedHashTable_ctor
# @description	Constructor for a ChainedHashTable
# @return	%rax	Pointer to the ChainedHashTable instance
.equ	SIZE, -8
.equ	TABLE, -16
.type	ChainedHashTable_ctor, @function
ChainedHashTable_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	$1, %rdi
	shl	$START_DIMENSION, %rdi
	mov	%rdi, SIZE(%rbp)

	# Allocation for table
	imul	$1<<3, %rdi
	call	alloc
	mov	%rax, TABLE(%rbp)
	jmp	2f

1:
	# Create an array stack for each table entry
	call	ArrayStack_ctor
	mov	SIZE(%rbp), %rcx
	mov	TABLE(%rbp), %rdx
	mov	%rax, (%rdx, %rcx, 1<<3)

2:
	decq	SIZE(%rbp)
	cmpq	$0, SIZE(%rbp)
	jge	1b

	# Allocate for instance
	mov	$CHAINEDHASHTABLE_SIZE, %rdi
	call	alloc

1:
	# Generate "z"
	rdrand	%rcx
	jnc	1b				# rdrand can fail
	or	$1, %rcx			# Force "zee" to be odd

	# Assign all the attributes
	mov	TABLE(%rbp), %rdx
	mov	%rdx, ChainedHashTable.tab(%rax)
	mov	%rcx, ChainedHashTable.zee(%rax)
	movl	$START_DIMENSION, ChainedHashTable.dim(%rax)
	movl	$0, ChainedHashTable.len(%rax)

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	ChainedHashTable_find
# @description	Find an element in the table
# @param	%rdi	Pointer to the ChainedHashTable
# @param	%rsi	Item to find
# @return	%rax	The item (if found) or NULL on failure
.equ	THIS, -8
.equ	VAL, -16
.equ	KEY, -24
.type	ChainedHashTable_find, @function
ChainedHashTable_find:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, VAL(%rbp)

	call	hash
	mov	ChainedHashTable.tab(%rdi), %rdi
	mov	(%rdi, %rax, 1<<3), %rdi
	call	ArrayStack_length
	mov	%rax, KEY(%rbp)
	jmp	2f

1:
	decq	KEY(%rbp)
	mov	KEY(%rbp), %rsi
	call	ArrayStack_get
	cmp	VAL(%rbp), %rax
	je	3f

2:
	cmpq	$0, KEY(%rbp)
	jg	1b

	xor	%rax, %rax			# If here it means the item was not found

3:
	mov	THIS(%rbp), %rdi

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	ChainedHashTable_add
# @description	Adds an item to the table
# @param	%rdi	Pointer to the ChainedHashTable
# @param	%rsi	The element to add
# @return	%rax	The added element
.equ	THIS, -8
.equ	VAL, -16
.type	ChainedHashTable_add, @function
ChainedHashTable_add:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, VAL(%rbp)

	# Try to find the element in the table
	call	ChainedHashTable_find
	cmp	$NULL, %rax
	jne	2f

	# Check if a resize is needed
	mov	ChainedHashTable.len(%rdi), %eax
	inc	%eax
	mov	ChainedHashTable.dim(%rdi), %ecx
	mov	$1, %rdx
	shl	%cl, %rdx
	cmp	%rdx, %rax
	jle	1f

	call	resize

1:
	mov	VAL(%rbp), %rsi
	call	hash
	mov	ChainedHashTable.tab(%rdi), %rdi
	mov	(%rdi, %rax, 1<<3), %rdi
	call	ArrayStack_length
	mov	%rax, %rsi
	mov	VAL(%rbp), %rdx
	call	ArrayStack_add

	mov	THIS(%rbp), %rdi
	incl	ChainedHashTable.len(%rdi)

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	ChainedHashTable_remove
# @description	Remove an element from the hash table
# @param	%rdi	Pointer to the ChainedHashTable
# @param	%rsi	Element to remove
# @param	%rax	The removed element
.equ	THIS, -8
.equ	VAL, -16
.equ	KEY, -24
.type	ChainedHashTable_remove, @function
ChainedHashTable_remove:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, VAL(%rbp)

	call	hash
	mov	ChainedHashTable.tab(%rdi), %rdi
	mov	(%rdi, %rax, 1<<3), %rdi
	call	ArrayStack_length
	mov	%rax, KEY(%rbp)
	jmp	2f

1:
	decq	KEY(%rbp)
	mov	KEY(%rbp), %rsi
	call	ArrayStack_get
	cmp	VAL(%rbp), %rax
	je	3f

2:
	cmpq	$0, KEY(%rbp)
	jg	1b

	# Item not found
	mov	THIS(%rbp), %rdi
	xor	%rax, %rax
	jmp	4f

3:
	# Remove the element
	mov	KEY(%rbp), %rsi
	call	ArrayStack_remove
	
	mov	THIS(%rbp), %rdi
	decl	ChainedHashTable.len(%rdi)
	
	# Check if a resize is needed
	mov	ChainedHashTable.len(%rdi), %edx
	imul	$3, %rdx
	mov	ChainedHashTable.dim(%rdi), %ecx
	mov	$1, %rsi
	shl	%cl, %rsi
	cmp	%rsi, %rdx
	jge	4f

	call	resize

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	hash
# @description	File private function to perform the multiplicative hashing and obtain the index
# @param	%rdi	Pointer to the ChainedHashTable
# @param	%rsi	Value to hash
# @return	%rax	The hashed index into the backing array
.equ	THIS, -8
hash:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, THIS(%rbp)

	mov	%rsi, %rdi
	call	hash_code

	mov	THIS(%rbp), %rdi
	mov	ChainedHashTable.zee(%rdi), %rcx
	imul	%rcx, %rax
	mov	$1, %rcx
	shl	$INT_SIZE, %rcx
	xor	%rdx, %rdx
	div	%rcx
	mov	%rdx, %rax

	mov	$INT_SIZE, %rcx
	sub	ChainedHashTable.dim(%rdi), %ecx
	shr	%cl, %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	resize
# @description	Resize the hash table to be always equal to the number of elements proportionate
#		to a power of two
# @param	%rdi	Pointer to the ChainedHashTable
# @return	void
.equ	THIS, -8
.equ	NEW, -16
.equ	ICTR, -24
.equ	JCTR, -32
.equ	CURR, -40
resize:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	# Store current size
	mov	ChainedHashTable.dim(%rdi), %ecx
	mov	$1, %rax
	shl	%cl, %rax
	mov	%rax, ICTR(%rbp)		# Put current "size" in the i loop counter

	xor	%rcx, %rcx

1:
	inc	%rcx
	mov	$1, %rax
	shl	%cl, %rax
	cmp	ChainedHashTable.len(%rdi), %eax
	jle	1b

	# Update the dimension
	mov	%rax, JCTR(%rbp)		# Put new "size" in the j loop counter
	mov	%ecx, ChainedHashTable.dim(%rdi)

	# Allocate a new table
	mov	%rax, %rdi
	imul	$8, %rdi
	call	alloc
	mov	%rax, NEW(%rbp)

2:
	# Create ArrayStack lists in each slot of the new table
	decq	JCTR(%rbp)			# j holds the new "size"
	call	ArrayStack_ctor
	mov	JCTR(%rbp), %rcx
	mov	NEW(%rbp), %rdx
	mov	%rax, (%rdx, %rcx, 1<<3)
	cmp	$0, %rcx
	jg	2b

	# Migrate data
	jmp	6f

3:
	# Setup for inner ArrayStack loop (populate JCTR and CURR)
	mov	THIS(%rbp), %rax
	mov	ChainedHashTable.tab(%rax), %rax
	mov	ICTR(%rbp), %rcx
	mov	(%rax, %rcx, 1<<3), %rdi
	mov	%rdi, CURR(%rbp)		# Current ArrayStack in "old" table
	call	ArrayStack_length
	mov	%rax, JCTR(%rbp)		# j holds the size of the "current" arraystack
	jmp	5f

4:
	# Get the current element (inner loop) into %rax
	mov	CURR(%rbp), %rdi
	mov	JCTR(%rbp), %rsi
	call	ArrayStack_get
	mov	%rax, %r11

	mov	THIS(%rbp), %rdi
	mov	%rax, %rsi
	call	hash

	# Retrieve the target ArrayStack in the "new" table
	mov	NEW(%rbp), %rcx
	mov	(%rcx, %rax, 1<<3), %rdi
	call	ArrayStack_length
	mov	%rax, %rsi
	mov	%r11, %rdx
	call	ArrayStack_add

5:
	decq	JCTR(%rbp)
	cmpq	$0, JCTR(%rbp)
	jge	4b

	# We are done emptying out an old ArrayStack so we can destroy it now
	mov	CURR(%rbp), %rdi
	call	ArrayStack_dtor

6:
	decq	ICTR(%rbp)			# i holds the old "size"
	cmpq	$0, ICTR(%rbp)
	jge	3b


	# All old ArrayStack's destroyed so we can free the old table
	mov	THIS(%rbp), %rdi
	mov	ChainedHashTable.tab(%rdi), %rdi
	call	free

	# Assign the new table
	mov	THIS(%rbp), %rdi
	mov	NEW(%rbp), %rax
	mov	%rax, ChainedHashTable.tab(%rdi)

	mov	%rbp, %rsp
	pop	%rbp
	ret
