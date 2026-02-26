# lib/util.s - Common utilities

.include	"common.inc"
.include	"linux.inc"

.globl	atoi, hash_code, itoa, itoab, random, strcmp

.section .rodata

# Constants for hashing
p:
	.quad	(1<<32) - 5	# Prime 2^32 - 5
z:
	.quad	0x6b2625ba	# 32 random bits
z2:
	.long	0x12b20155	# Random odd 32-bit number

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

# @function	itoab
# @description	Converts an integer to an ascii string (binary representation)
# @param	%rdi	The integer to convert
# @param	%rsi	Min digits (will be zeroes if needed)
# @return	%rax	The address of the string
.equ	INT, -8
.type	itoab, @function
itoab:
	push	%rbp
	mov	%rsp, %rbp

	sub	$8, %rsp
	mov	%rdi, INT(%rbp)	# Preserve the int so it doesn't get clobbered

	xor	%rcx, %rcx	# Count the number of digits

	push	$NULL		# Adds null termination to string
	inc	%rcx

1:
	mov	$1, %rax
	and	%rdi, %rax
	add	$'0', %al
	push	%rax

	shr	%rdi
	inc	%rcx

	test	%rdi, %rdi
	jnz	1b
	
	jmp	3f
2:
	push	$'0'
	inc	%rcx

3:
	cmp	%rsi, %rcx
	jle	2b

	xor	%rdx, %rdx
	mov	$int_buffer, %r8

4:
	pop	%rax
	mov	%al, int_buffer(, %rdx)
	inc	%rdx
	cmp	%rcx, %rdx
	jl	4b

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
# @description	Hashes a (null-terminated) string into an 32-bit integer
# @param	%rdi	Pointer to the (null-terminated) string to hash
# @return	%rax	Integer hash code (32 bits long)
.type	hash_code, @function
hash_code:
	# LEGEND
	# %rdi - Pointer to the string
	# %rcx - Current index
	# %rax:%rdx - Intermediate values and division
	# %r8 - s
	# %r9 - zi
	xor	%rcx, %rcx

	xor	%r8, %r8	# s <- 0
	mov	$1, %r9		# zi <- 1
	jmp	2f

1:
	# xi <- ((x[i].hash_code() * z2) % 2^32) >> 1
	mull	z2
	shr	$1, %eax

	# s <- (s + zi * xi) % p
	mul	%r9
	add	%r8, %rax
	xor	%rdx, %rdx
	divq	p
	mov	%rdx, %r8

	# zi <- (zi * z) % p
	mov	%r9, %rax
	mulq	z
	xor	%rdx, %rdx
	divq	p
	mov	%rdx, %r9

	inc	%rcx

2:
	movzbq	(%rdi, %rcx), %rax
	test	%rax, %rax
	jnz	1b

	# s <- (s + zi * (p - 1)) % p
	mov	p, %rax
	dec	%rax
	mul	%r9
	add	%r8, %rax
	xor	%rdx, %rdx
	divq	p

	mov	%edx, %eax
	ret

# @function	random
# @description	Generate random bits
# @return	%rax	A random 64-bit integer
.type	random, @function
random:
	rdrand	%rax
	jnc	random

	ret
