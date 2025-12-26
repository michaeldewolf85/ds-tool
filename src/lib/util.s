# lib/util.s - Common utilities

.include	"common.inc"
.include	"linux.inc"

.globl	print, strcmp, strlen

.equ	PRINT_BUFFER_MAX, 3
# PrintBuffer
	.struct	0
PrintBuffer.length:
	.struct	PrintBuffer.length + 1<<3
PrintBuffer.data:
	.struct	PrintBuffer.data + 1<<3 * PRINT_BUFFER_MAX
	.equ	PRINT_BUFFER_SIZE, .

.section .bss

print_buffer:
	.zero	PRINT_BUFFER_SIZE

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

	xor	%rcx, %rcx	# Zero out count register to use as an index
	mov	print_buffer + PrintBuffer.length, %rdx
1:
	movb	(%rdi, %rcx), %al
	movb	%al, print_buffer + PrintBuffer.data(, %rdx)
	inc	%rdx

	cmp	$PRINT_BUFFER_MAX, %rdx
	jge	2f

	inc	%rcx
	cmp	$NULL, %al
	jne	1b
	
	mov	%rbp, %rsp
	pop	%rbp
	ret
2:
	mov	$SYS_WRITE, %rax
	mov	$STDOUT, %rdi
	mov	$print_buffer + PrintBuffer.data, %rsi
	mov	print_buffer + PrintBuffer.length, %rdx
	syscall
	mov	$0, print_buffer + PrintBuffer.length
	mov	$0, %rdx
	jmp	1b

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

# @function	strlen
# @description	Get the length of a (NULL terminated) string
# @param	%rdi	Address of the string
# @return	%rax	The length of the string
.type	strlen, @function
strlen:
	push	%rbp
	mov	%rsp, %rbp

	mov	%rbp, %rsp
	pop	%rbp
	ret
