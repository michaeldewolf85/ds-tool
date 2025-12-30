# lib/util.s - Common utilities

.include	"common.inc"
.include	"linux.inc"

.globl	atoi, strcmp

.section .text

# @function	atoi
# @description	Convert a string to an integer
# @param	%rdi	Pointer to null terminated string
# @return	%rax	The converted value or negative 1 on error
.type	atoi, @function
atoi:
	xor	%rax, %rax		# Result
	xor	%rcx, %rcx		# Current digit
1:
	movzbl	(%rdi), %ecx
	cmpb	$NULL, %cl		# When we get a zero char we are done
	je	2f

	sub	$'0', %cl
	jb	3f			# If there was borrow the character was < '0' (invalid)
	cmp	$9, %cl
	jg	3f			# Number was greater than 9 (invalid)

	imul	$10, %rax		# Multiply result by 10 for each digit
	add	%rcx, %rax

	inc	%rdi
	jmp	1b

2:
	ret
3:
	mov	$-1, %rax
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
