# lib/alloc.s - Memory allocation utilities

.globl	alloc, free, realloc

.section .text

# Request a block of memory
# @param	%rdi	Size (in bytes) of the requested memory
# @return	%rax	Pointer to the allocated memory
.type	alloc, @function
alloc:
	push	%rbp
	mov	%rsp, %rbp

	mov	%rbp, %rsp
	pop	%rbp
	ret

# Free memory previously allocated with "alloc"
# @param	%rdi	Memory address of the block to free
# @return	Returns no value
.type	free, @function
free:
	push	%rbp
	mov	%rsp, %rbp

	mov	%rbp, %rsp
	pop	%rbp
	ret

# Resize an allocation previously allocated with "alloc". Will make every attempt to perform the
# reallocation "in-place" without relocating the block. If the memory needs to be relocated the 
# existing contents of the block are moved to the new location
# @param	%rdi	Address of the memory block to reallocate
# @param	$rsi	The new size to allocate
# @param	%rax	Address of the resized memory block
.type	realloc, @function
realloc:
	push	%rbp
	mov	%rsp, %rbp

	mov	%rbp, %rsp
	pop	%rbp
	ret
