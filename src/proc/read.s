# proc/read.s - Reads user input

.include	"common.inc"
.include	"linux.inc"
.include	"settings.inc"
.include	"structs.inc"

.globl	read

.section .bss

.align	8
buffer:
	.skip	INPUT_BUFFER_LEN
input:
	.skip	INPUT_SIZE

.section .text

# Reads input from the specified file descriptor and parses it. Returns the address of the input
# @param	%rdi	A file descriptor	
# @return	%rax	The address of the parsed input struct
.type	read, @function
read:
	push	%rbp
	mov	%rsp, %rbp

	mov	$SYS_READ, %rax
	mov	$buffer, %rsi
	mov	$INPUT_BUFFER_LEN, %rdx
	syscall

	xor	%rcx, %rcx				# Set argc counter to 0
start:
	cmpb	$LF, (%rsi)				# Check for new line
	je	end
	cmpb	$SPACE, (%rsi)				# Check for word character
	jle	next

	movq	%rsi, input + Input.argv(, %rcx, 8)	# Move address to argv
	inc	%rcx					# Increment argc counter

scan_arg:
	inc	%rsi
	cmpb	$LF, (%rsi)
	je	end
	cmpb	$SPACE, (%rsi)
	jle	end_arg
	jmp	scan_arg

end_arg:
	movb	$NULL, (%rsi)			# Add a null termination instead of whatever it is

next:
	inc	%rsi
	jmp	start

end:
	movb	$NULL, (%rsi)			# Add a null termination to last char (LF)
	mov	%rcx, input			# Store argc in memory
	mov	$input, %rax			# Set return value to address of parsed input

	mov	%rbp, %rsp
	pop	%rbp
	ret
