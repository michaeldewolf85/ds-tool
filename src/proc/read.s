# proc/read.s - Reads user input

.include	"common.inc"
.include	"linux.inc"
.include	"settings.inc"
.include	"structs.inc"

.globl	read

.section .bss

.align	8
input:
	.skip	INPUT_SIZE

.section .text

# Reads input from the specified file descriptor and parses it. Returns the address of the input
# @param	%rdi	A file descriptor	
# @return	%rax	The address of the parsed input struct or NULL if an error occurred
.type	read, @function
read:
	# Function prologue
	push	%rbp
	push	%rbx
	mov	%rsp, %rbp

	# Create space on stack for an input buffer
	sub	$INPUT_BUFFER_LEN, %rsp

	# Read input and put it on the stack
	mov	$SYS_READ, %rax
	mov	%rsp, %rsi
	mov	$INPUT_BUFFER_LEN, %rdx
	syscall

	# Checks for read errors or missing input. SYS_READ returns -1 if there was an error
	cmp	$0, %rax
	jle	9f

	# Preserve a copy of the input length and subtract one so we can use it to cmp end index
	mov	%rax, %rbx
	dec	%rbx

	# Allocate memory to store the input. The length is in %rax and %rax has our pointer when
	# we are done
	mov	%rax, %rdi
	call	alloc

	# Load the input into memory, replacing non-word characters with NULL:
	# %rax	- Pointer to our allocated memory location
	# %rbx	- The length of the input
	# %rcx	- The offset (index) of our current position in the string
	# %dx	- Our current "status" (dl) and "history" (dh)
	# %sil	- The current character being examined + temporary address of argv location
	# %rdi	- Argc cache
	# %r8w	- Holds the character NULL. Neccessary because cmovcc can't move an immediate

	xor	%rcx, %rcx		# Zero out our offset
	xor	%dx, %dx		# Zero out our "status" and "history" flags
	xor	%rdi, %rdi		# Zero out argc
	xor	%r8w, %r8w		# Set to NULL

# Main loop
1:
	mov	(%rsp, %rcx), %sil	# Move the current character into position
	cmp	$SPACE, %sil		# Check for a word character

	setg	%dl			# Set "status" to 1 for a word character
	cmovle	%r8w, %si		# Replace non-word characters with NULL
	mov	%sil, (%rax, %rcx)	# Move the character to the allocated memory

	cmp	%rcx, %rbx		# Checks if we have reached the end of our input
	jle	4f

	# Applies the current "status" to the history and uses it to check for the start of an arg
	or	%dl, %dh
	cmp	$0b01, %dh
	je	3f

# Setup for next iteration. Left shift the "history" and mask the bytes we aren't using
2:
	shl	$1, %dh			# Left shift history
	and     $0b00000011, %dh        # Zero out history bytes we aren't using
	inc	%rcx			# Increment our position
	jmp	1b

# We've found the start of an argument. Move the pointer to argv and increment argc ...
3:
	# Load the effective address of the string in our alloc'd memory and add it to argv
	lea	(%rax, %rcx), %rsi
	mov	%rsi, input + Input.argv(, %rdi, 8)

	# Increment argc counter
	inc	%rdi

	# Continue iterating
	jmp	2b					

# Function epilogue
4:
	# Move the final argc value into the parsed input struct
	mov	%rdi, input + Input.argc

	# Set input struct as the return
	mov	$input, %rax

	mov	%rbp, %rsp
	pop	%rbx
	pop	%rbp
	ret

# An error occurred reading the input
9:
	xor	%rax, %rax				# Set %rax to NULL
	mov	%rbp, %rsp
	pop	%rbp
	ret
