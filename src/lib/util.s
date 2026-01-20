# lib/util.s - Common utilities

.include	"common.inc"
.include	"linux.inc"

.globl	atoi, hash_code, itoa, strcmp

.section .rodata

# Constants for hashing
p:
	.long	1<<32 - 5	# Large prime number
z:
	.long	0xde07037a	# Random 32-bit number
z2:
	.long	0x37cf6d13	# Random ODD 32-bit number

.section .bss

int_buffer:
	.skip	1<<6		# 64 character buffer for int => string conversions

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

# @function	itoa
# @description	Convert an integer to a string
# @param	%rdi	The integer to convert
# @return	void
.type	itoa, @function
itoa:
	push	%rbp
	mov	%rsp, %rbp

	xor	%rcx, %rcx	# Count the number of digits
	mov	$10, %r8	# DIV requires the divisor to be in a register

	push	$NULL		# Adds null termination to string
	inc	%rcx

	mov	%rdi, %rax
1:
	xor	%rdx, %rdx
	div	%r8
	add	$'0', %rdx
	push	%rdx

	inc	%rcx

	cmp	$0, %eax
	jne	1b

	xor	%rdx, %rdx
2:
	pop	%rax
	mov	$int_buffer, %r8
	mov	%al, int_buffer(, %rdx)
	inc	%rdx
	cmp	%rcx, %rdx
	jl	2b

	mov	$int_buffer, %rax 

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
	movsbq	%al, %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	hash_code
# @description	Hashes a (null-terminated) string into a 32-bit number
# @param	%rdi	Pointer to the (null-terminated) string
# @return	%rax	The hash code
.type	hash_code, @function
hash_code:
	xor	%rcx, %rcx	# Loop counter
	xor	%r8, %r8	# s = 0
	mov	$1, %r9		# zi = 1

1:
	movzbq	(%rdi, %rcx), %rax
	cmp	$NULL, %rax
	je	2f

	# Calculate xi
	imul	z2, %eax
	mov	$1<<32, %r10
	xor	%rdx, %rdx
	div	%r10
	shr	$1, %rdx

	# Calculate s
	mov	%rdx, %rax
	imul	%r9, %rax
	add	%r8, %rax
	xor	%rdx, %rdx
	divl	p
	mov	%rdx, %r8

	# Calculate zi
	mov	%r9, %rax
	imul	z, %eax
	xor	%rdx, %rdx
	divl	p
	mov	%rdx, %r9

	inc	%rcx
	jmp	1b
2:
	mov	p, %eax
	sub	$1, %rax
	imul	%r9, %rax
	add	%r8, %rax
	xor	%rdx, %rdx
	divl	p

	mov	%rdx, %rax
	ret
