# lib/util.s - Common utilities

.include	"common.inc"

.globl	print, strcmp, strlen

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

	mov	%rbp, %rsp
	pop	%rbp
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
