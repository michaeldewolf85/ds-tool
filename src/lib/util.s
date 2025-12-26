# lib/util.s - Common utilities

.include	"common.inc"
.include	"linux.inc"

.globl	print, print_buffer_flush, strcmp

.equ	PRINT_BUFFER_SIZE, 1<<10

.section .bss

print_buffer:
	.skip	PRINT_BUFFER_SIZE
print_buffer_len:
	.zero	1<<3

.section .text

# @function	print
# @description	Print a string to standard output. The system call to write is buffered and does 
#		not happen immediately. Callers who need immediate output may need to ALSO call 
#		print_buffer_flush
# @param	%rdi	Address of the string to print. It is assumed to be NULL terminated
# @return	%rax	The number of characters added to the buffer
.type	print, @function
print:
	push	%rbp
	mov	%rsp, %rbp

	xor	%rcx, %rcx		# Zero out count register to use as an index
	mov	print_buffer_len, %rdx	# Keep track of the print buffer length in a register

1:
	movb	(%rdi, %rcx), %al
	movb	%al, print_buffer(, %rdx)
	inc	%rdx

	cmp	$PRINT_BUFFER_SIZE, %rdx
	jge	3f

	inc	%rcx
	cmp	$NULL, %al
	jne	1b

	mov	%rdx, print_buffer_len	# Store where the print buffer ended out

	mov	%rbp, %rsp
	pop	%rbp
	ret

3:
	mov	%rdx, print_buffer_len	# Update the print_buffer length
	call	print_buffer_flush
	
	mov	print_buffer_len, %rdx
	jmp	1b

# @function	print_buffer_flush
# @description	Flushes the print buffer to STDOUT
.type	print_buffer_flush, @function
print_buffer_flush:
	mov	$SYS_WRITE, %rax
	mov	$STDOUT, %rdi
	mov	$print_buffer, %rsi
	mov	print_buffer_len, %rdx
	syscall

	mov	$0, print_buffer_len
	ret
	

# @function	strcmp
# @description	Compare two (null terminated) strings for equality
# @param	%rdi	String one
# @param	%rsi	String two
# @return	%rax	Zero if equal, a negative if string one is less than string 2 or vice versa
.type	strcmp, @function
strcmp:
	push	%rbp
	mov	%rsp, %rbp

	xor	%rax, %rax		# Zero out all of %rax so they start equal
	xor	%rcx, %rcx		# Zero out an iterator

compare:
	movb	(%rdi, %rcx), %al	# Move first char of s1 into %al, if the result is not zero
	movb	(%rsi, %rcx), %dl	# Move first char of s2 into %dl
	subb	(%rsi, %rcx), %al	# If they aren't equal, %rax has the return
	jnz	end

	cmpb	$NULL, (%rdi, %rcx)	# Check for end of s1
	je	end
	cmpb	$NULL, %dl		# Check for end of s2
	je	end

	inc	%rcx
	jmp	compare

end:
	mov	%rbp, %rsp
	pop	%rbp
	ret
