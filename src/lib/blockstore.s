# lib/blockstore.s - BlockStore

.include	"common.inc"
.include	"linux.inc"

.globl	BlockStore_ctor, BlockStore_read, BlockStore_write, BlockStore_place, BlockStore_free

# Block
	.struct	0
Block.fr:
	.struct	Block.fr + 1<<2
Block.sz:
	.struct	Block.sz + 1<<2
.equ	BLOCK_SIZE, .

# BlockStore
	.struct	0
BlockStore.fr:
	.struct	BlockStore.fr + 1<<2
BlockStore.sz:
	.struct	BlockStore.sz + 1<<2
BlockStore.ln:
	.struct	BlockStore.ln + 1<<2
.equ	BLOCKSTORE_SIZE, .
BlockStore.fd:
	.struct	BlockStore.fd + 1<<2
.equ	BLOCKSTORE_INSTANCE_SIZE, .

# Constants
.equ	BLOCKSTORE_RESERVED, -1

.section .text

# @public	BlockStore_ctor
# @description	Creates a new BlockStore
# @param	%rdi	Filename of backing file
# @param	%rsi	Block size
# @return	%rax	Pointer to a new BlockStore
.equ	FILE, -8
.equ	SIZE, -16
.equ	THIS, -24
.type	BlockStore_ctor, @function
BlockStore_ctor:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, FILE(%rbp)

	# Update the requested size to include space for, and be a multiple of the block header
	add	$(2 * BLOCK_SIZE - 1), %rsi
	and	$~(BLOCK_SIZE - 1), %rsi
	mov	%rsi, SIZE(%rbp)

	# Allocate memory for the BlockStore struct
	mov	$BLOCKSTORE_INSTANCE_SIZE, %rdi
	call	alloc
	mov	%rax, THIS(%rbp)
	
	mov	FILE(%rbp), %rdi
	mov	$(O_CREAT|O_EXCL|O_RDWR), %rsi
	mov	$0644, %rdx
	mov	$SYS_OPEN, %rax
	syscall

	cmp	$EEXIST, %al
	je	1f

	# Backing file does not exist. Initialize default header and write it to file
	mov	THIS(%rbp), %rdi
	movl	$0, BlockStore.fr(%rdi)		# Free
	movl	$0, BlockStore.ln(%rdi)		# Length
	mov	%eax, BlockStore.fd(%rdi)	# File descriptor
	mov	SIZE(%rbp), %rax
	mov	%eax, BlockStore.sz(%rdi)	# Block size

	# Write the new head information to disk
	mov	%rdi, %rsi
	mov	$BLOCKSTORE_SIZE, %rdx
	xor	%rcx, %rcx
	call	_BlockStore_write
	jmp	2f

1:
	# Backing file DOES exist. Read the head directly into the alloc'd space
	mov	FILE(%rbp), %rdi
	mov	$O_RDWR, %rsi
	mov	$SYS_OPEN, %rax
	syscall

	mov	THIS(%rbp), %rdi
	mov	%rax, BlockStore.fd(%rdi)
	mov	%rdi, %rsi
	mov	$BLOCKSTORE_SIZE, %rdx
	xor	%rcx, %rcx
	call	_BlockStore_read

2:
	mov	%rdi, %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public	BlockStore_read
# @description	Return the contents of the specified block
# @param	%rdi	BlockStore
# @param	%rsi	Index of the block
# @param	%rdx	Buffer
# @return	%rax	TRUE on success, FALSE on failure
.equ	THIS, -8
.equ	INDX, -16
.equ	BUFF, -24
.type	BlockStore_read, @function
BlockStore_read:
	push	%rbp
	mov	%rsp, %rbp

	xor	%rax, %rax			# Default return value if out of bounds
	cmp	%esi, BlockStore.ln(%rdi)
	jc	2f				# If there's carry it's either too big or negative
	jz	2f				# Also need to check for equals

	# Locals
	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, INDX(%rbp)
	mov	%rdx, BUFF(%rbp)

	# Preparations for reading ...
	mov	BlockStore.sz(%rdi), %edx		# Number of bytes (to read)

	mov	%rsi, %rcx
	imul	%rdx, %rcx
	add	$BLOCKSTORE_SIZE, %rcx			# Offset in the file (to read)

	sub	%rdx, %rsp			
	mov	%rsp, %rsi				# Buffer (to read to)

	call	_BlockStore_read			# Read block onto temp buffer on stack

	xor	%rax, %rax				# Return value if block is freed
	cmpl	$BLOCKSTORE_RESERVED, Block.fr(%rsp)
	jne	1f

	# Block is valid/reserved. Copy block contents to user buffer (MOVSB)
	lea	BLOCK_SIZE(%rsp), %rsi			# Source
	mov	BUFF(%rbp), %rdi			# Destination
	mov	Block.sz(%rsp), %ecx			# Count (of moves)
	rep	movsb

	# Return value
	mov	$TRUE, %rax

1:
	# Restore user parameters
	mov	THIS(%rbp), %rdi
	mov	INDX(%rbp), %rsi
	mov	BUFF(%rbp), %rdx

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public	BlockStore_write
# @description	Write the specified contents to the specified block
# @param	%rdi	BlockStore
# @param	%rsi	Index of the block to write to
# @param	%rdx	Contents to write
# @return	%rax	The number of characters written (on success) or a negative error code
.equ	INDX, -8
.equ	DATA, -16
.type	BlockStore_write, @function
BlockStore_write:
	push	%rbp
	mov	%rsp, %rbp

	xor	%rax, %rax			# Return value (if out of bounds)
	cmp	%esi, BlockStore.ln(%rdi)
	jc	2f				# If there's carry it's either too big or negative
	jz	2f				# Also need to check for equals

	sub	$24, %rsp
	mov	%rsi, INDX(%rbp)
	mov	%rdx, DATA(%rbp)

	# Calculate the offset
	mov	%rsi, %rcx
	imul	BlockStore.sz(%rdi), %ecx
	add	$BLOCKSTORE_SIZE, %rcx			# Offset in the file (to read)

	# Read the header of the block to ensure it hasn't been freed ...
	mov	%rsp, %rsi
	mov	$BLOCK_SIZE, %rdx
	call	_BlockStore_read

	xor	%rax, %rax				# Return value if block is freed
	cmpl	$BLOCKSTORE_RESERVED, Block.fr(%rsp)
	jne	1f

	# Calculate the offset
	mov	INDX(%rbp), %rcx
	imul	BlockStore.sz(%rdi), %ecx
	add	$BLOCKSTORE_SIZE + BLOCK_SIZE, %rcx	# Offset in the file (to write)

	# Since this is (presumably) an existing block we don't need to write the header
	mov	DATA(%rbp), %rsi			# Buffer (to write from)
	mov	BlockStore.sz(%rsp), %edx		# Number of bytes (to write)
	call	_BlockStore_write

	# Return value
	mov	$TRUE, %rax

1:
	# Restore user parameters
	mov	INDX(%rbp), %rsi
	mov	BUFF(%rbp), %rdx

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public	BlockStore_place
# @description	Return a new index and store the specified contents at this index
# @param	%rdi	BlockStore
# @param	%rsi	Data buffer
# @return	%rax	The index of the new block
.equ	THIS, -8
.equ	DATA, -16
.equ	INDX, -24
.equ	OFFS, -32
.equ	FREE, -40
.type	BlockStore_place, @function
BlockStore_place:
	push	%rbp
	mov	%rsp, %rbp

	# Locals
	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)		# BlockStore
	mov	%rsi, DATA(%rbp)		# Date to write
	mov	BlockStore.fr(%rdi), %eax
	mov	%rax, INDX(%rbp)		# Insertion index

	# Calculate the offset in the backing file of the free block
	mov	BlockStore.sz(%rdi), %ecx
	imul	%ecx, %eax
	add	$BLOCKSTORE_SIZE, %rax
	mov	%rax, OFFS(%rbp)		# Offset of the write

	# Create a temp buffer on the stack block header/contents
	# TODO: Can we allocate this stack space all at once?
	sub	%rcx, %rsp

	# Try to read the header of the free block to see if it has its own free pointer
	mov	%rsp, %rsi			# Stack buffer (to read to)
	mov	$BLOCK_SIZE, %rdx		# Number of bytes (to read)
	mov	OFFS(%rbp), %rcx		# Offset in the file (to read)
	call	_BlockStore_read

	# If any bytes were read it means the free block has a free pointer of its own
	test	%rax, %rax
	cmovnz	Block.fr(%rsp), %eax
	jnz	1f

	# Otherwise free points to the end of the list so we will just increment it
	# TODO: See if we really need to store this here/now
	mov	BlockStore.fr(%rdi), %eax
	inc	%rax

1:
	mov	%rax, FREE(%rbp)

	# MOVSB
	mov	BlockStore.sz(%rdi), %ecx
	sub	$BLOCK_SIZE, %rcx			# Count
	mov	DATA(%rbp), %rsi			# Source
	lea	BLOCK_SIZE(%rsp), %rdi			# Destination
	
	# Set the headers and the data ...
	mov	%ecx, Block.sz(%rsp)			# Size (temp buffer) ...
	movl	$BLOCKSTORE_RESERVED, Block.fr(%rsp)	# Free (temp buffer)
	rep	movsb					# Data (temp buffer)

	# FINALLY ready to write data to the file
	mov	THIS(%rbp), %rdi			# BlockStore
	mov	%rsp, %rsi				# Buffer (to write from)
	mov	BlockStore.sz(%rdi), %edx		# Number of bytes (to write)
	mov	OFFS(%rbp), %rcx			# Offset in the file (to write)
	call	_BlockStore_write

	# Update the block stores headers (free pointer and length)
	mov	FREE(%rbp), %rax
	mov	%eax, BlockStore.fr(%rdi)
	incl	BlockStore.ln(%rdi)

	# Save the block store header to disk
	mov	%rdi, %rsi				# Buffer (to write from)
	mov	$BLOCKSTORE_SIZE, %rdx			# Number of bytes (to write)
	xor	%rcx, %rcx				# Offset in the file (to write)
	call	_BlockStore_write

	# Return value
	mov	INDX(%rbp), %rax

	# Restore user parameters
	mov	DATA(%rbp), %rsi

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @public	BlockStore_free
# @description	Free the block at the specified index
# @param	%rdi	BlockStore
# @param	%rsi	Index to free
# @return	%rax	TRUE on success, FALSE on failure
.equ	INDX, -8
.equ	FREE, -16
.type	BlockStore_free, @function
BlockStore_free:
	push	%rbp
	mov	%rsp, %rbp
	
	xor	%rax, %rax			# Return value (if out of bounds)
	cmp	%esi, BlockStore.ln(%rdi)
	jc	2f				# If there's carry it's either too big or negative
	jz	2f				# Also need to check for equals

	sub	$16, %rsp
	mov	%rsi, INDX(%rbp)

	# Stage the updated block header (8 bytes) on the stack
	mov	BlockStore.fr(%rdi), %eax
	mov	%eax, Block.fr(%rsp)
	movl	$0, Block.sz(%rsp)

	# Set the free pointer to the new index and decrement the length
	mov	%esi, BlockStore.fr(%rdi)
	decl	BlockStore.ln(%rdi)

	# Calculate the offset of the block
	mov	%rsi, %rcx
	imul	BlockStore.sz(%rdi), %ecx	# Offset in the file (to write)
	add	$BLOCKSTORE_SIZE, %rcx

	# Move current free pointer to be the free pointer on the block
	mov	%rsp, %rsi			# Buffer (to write header from) on stack
	mov	$BLOCK_SIZE, %rdx		# Number of bytes (to write)
	call	_BlockStore_write

	# Save the block store header to disk
	mov	%rdi, %rsi				# Buffer (to write from)
	mov	$BLOCKSTORE_SIZE, %rdx			# Number of bytes (to write)
	xor	%rcx, %rcx				# Offset in the file (to write)
	call	_BlockStore_write

	# Return value
	mov	$TRUE, %rax

1:
	# Restore user parameters
	mov	INDX(%rbp), %rsi

2:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @private	_BlockStore_write
# @description	Writes the specified contents to the BlockStore at the specified offset
# @param	%rdi	BlockStore
# @param	%rsi	Buffer to write
# @param	%rdx	Number of bytes
# @param	%rcx	Offset
# @return	%rax	The number of bytes written on success, an error code on failure
_BlockStore_write:
	push	%rdi
	mov	BlockStore.fd(%rdi), %edi
	mov	%rcx, %r10
	mov	$SYS_PWRITE64, %rax
	syscall
	pop	%rdi
	ret

# @private	_BlockStore_read
# @description	Reads the specified contents of the BlockStore into the specified memory location
# @param	%rdi	BlockStore
# @param	%rsi	Buffer to read to
# @param	%rdx	Number of bytes
# @param	%rcx	Offset
# @return	%rax	The number of bytes read on success, an error code on failure
_BlockStore_read:
	push	%rdi
	mov	BlockStore.fd(%rdi), %edi
	mov	%rcx, %r10
	mov	$SYS_PREAD64, %rax
	syscall
	pop	%rdi
	ret
