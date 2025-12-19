# lib/util.s - Common utilities

.globl strcmp

.section .text

# Compare two (null terminated) strings for equality
# @param	%rdi	String one
# @param	%rsi	String two
# @return	%rax	Zero if equal, a negative if string one is less than string 2 or vice versa
.type strcmp, @function
strcmp:
	push	%rbp
	mov	%rsp, %rbp

	xor	%rax, %rax		# Zero out all of %rax so they start equal
	xor	%rcx, %rcx		# Zero out an iterator

compare:
	movb	(%rdi, %rcx), %al	# Move first char of s1 into %al, if the result is not zero
	subb	(%rsi, %rcx), %al	# than they aren't equal and %rax has the return
	jnz	done

	cmpb	$NULL, (%rdi, %rcx)	# Check for end of s1
	je	done
	cmpb	$NULL, (%rsi, %rcx)	# Check for end of s2
	je	done

	inc	%rcx
	jmp	compare

done:
	mov	%rbp, %rsp
	pop	%rbp
	ret
