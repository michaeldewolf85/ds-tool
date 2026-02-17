# lib/sort.s - Sort algorithms

.include	"common.inc"

.globl	heapsort, mergesort, quicksort, countingsort, radixsort, Array_log, Array_slice

# Array - this matches the form of the InputData struct
	.struct
Array.len:
	.struct	Array.len + 1<<3
Array.val:
	.struct	Array.val + 1<<3
.equ	ARRAY_SIZE, .

.section .rodata

rlabel:
	.ascii	"Sorted    => \0"
llabel:
	.ascii	"Length    => \0"
sdelim:
	.ascii	"[ \0"
mdelim:
	.ascii	", \0"
edelim:
	.ascii	" ]\0"
newline:
	.byte	LF, NULL

.section .text

.equ	RADIX, 16
.equ	WIDTH, 4
.equ	PASSES, RADIX / WIDTH

.equ	LOG_STR, 0
.equ	LOG_INT, 1
# @function	Array_log
# @description	Logs the innards of an array
# @param	%rdi	Pointer to an Array
# @param	%rsi	Flag indicating if the array is comprised of strings or numbers
# @return	void
.equ	THIS, -8
.equ	FRMT, -16
.equ	IDX, -24
.type	Array_log, @function
Array_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, FRMT(%rbp)
	movq	$0, IDX(%rbp)

	mov	$llabel, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	Array.len(%rdi), %rdi
	call	itoa
	mov	%rax, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	$rlabel, %rdi
	call	log

	mov	$sdelim, %rdi
	call	log
	jmp	3f

1:
	mov	Array.val(%rdi, %rcx, 1<<3), %rdi
	cmpq	$LOG_STR, FRMT(%rbp)
	je	2f

	call	itoa
	mov	%rax, %rdi

2:
	call	log
	incq	IDX(%rbp)

	mov	THIS(%rbp), %rdi
	mov	IDX(%rbp), %rcx
	cmp	Array.len(%rdi), %rcx
	je	3f

	mov	$mdelim, %rdi
	call	log

3:
	mov	THIS(%rbp), %rdi
	mov	IDX(%rbp), %rcx
	cmp	Array.len(%rdi), %rcx
	jl	1b

	mov	$edelim, %rdi
	call	log

	mov	$newline, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	radixsort
# @description	Performs a radixsort on an array of numerics
# @param	%rdi	Pointer to the input array (numeric)
# @return	%rax	Pointer to the (sorted) output array
.equ	THIS, -8
.equ	PASS, -16
.equ	ZERO, -24
.equ	OUTP, -32
.equ	OUTO, -40
.type	radixsort, @function
radixsort:
	push	%rbp
	mov	%rsp, %rbp

	sub	$40, %rsp
	mov	%rdi, THIS(%rbp)
	movq	$NULL, OUTP(%rbp)
	movq	$NULL, OUTO(%rbp)

	xor	%rcx, %rcx
	movq	$0, PASS(%rbp)
	jmp	8f

1:
	# Allocate zero array (c)
	mov	$1<<WIDTH, %rdi
	call	new_zero_array
	mov	%rax, ZERO(%rbp)

	# Queue OLD auxiliary array for deletiong
	mov	OUTP(%rbp), %rax
	mov	%rax, OUTO(%rbp)

	# Allocate auxiliary array (b)
	mov	THIS(%rbp), %rdi
	mov	Array.len(%rdi), %rdi
	call	new_zero_array
	mov	%rax, OUTP(%rbp)

	mov	THIS(%rbp), %rdi
	mov	ZERO(%rbp), %rax
	mov	OUTP(%rbp), %r10
	xor	%r8, %r8
	jmp	3f

2:
	mov	Array.val(%rdi, %r8, 1<<3), %rdx
	mov	PASS(%rbp), %rcx
	imul	$WIDTH, %rcx
	shr	%cl, %rdx
	and	$1<<WIDTH - 1, %rdx
	incq	Array.val(%rax, %rdx, 1<<3)
	inc	%r8

3:
	cmp	Array.len(%rdi), %r8
	jl	2b

	mov	$1, %rcx
	jmp	5f

4:
	mov	Array.val - 8(%rax, %rcx, 1<<3), %rdx
	add	%rdx, Array.val(%rax, %rcx, 1<<3)
	inc	%rcx

5:
	cmp	$1<<WIDTH, %rcx
	jl	4b

	mov	Array.len(%rdi), %r8
	jmp	7f

6:
	mov	Array.val(%rdi, %r8, 1<<3), %rdx
	mov	%rdx, %r9
	mov	PASS(%rbp), %rcx
	imul	$WIDTH, %rcx
	shr	%cl, %rdx
	and	$1<<WIDTH - 1, %rdx
	decq	Array.val(%rax, %rdx, 1<<3)
	mov	Array.val(%rax, %rdx, 1<<3), %rdx
	mov	%r9, Array.val(%r10, %rdx, 1<<3)

7:
	dec	%r8
	test	%r8, %r8
	jns	6b

	mov	%r10, THIS(%rbp)

	# Free zero array
	mov	ZERO(%rbp), %rdi
	call	free

	cmpq	$NULL, OUTO(%rbp)
	je	8f

	mov	OUTO(%rbp), %rdi
	call	free

8:

	# Increment the pass
	incq	PASS(%rbp)

9:
	cmpq	$PASSES, PASS(%rbp)
	jl	1b
	
	mov	OUTP(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	countingsort
# @description	Performs a countingsort on an array of numerics
# @param	%rdi	Pointer to an input array (numeric)
# @return	%rax	Pointer to the (sorted) output array
.equ	THIS, -8
.equ	ZERO, -16
.equ	OUT, -24
.type	countingsort, @function
countingsort:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)

	mov	Array.len(%rdi), %rdi
	call	new_zero_array
	mov	%rax, ZERO(%rbp)

	mov	THIS(%rbp), %rdi
	xor	%rcx, %rcx
	jmp	2f

1:
	mov	Array.val(%rdi, %rcx, 1<<3), %rdx
	incq	Array.val(%rax, %rdx, 1<<3)
	inc	%rcx

2:
	cmp	Array.len(%rdi), %rcx
	jl	1b

	mov	$1, %rcx
	jmp	4f

3:
	mov	Array.val - 8(%rax, %rcx, 1<<3), %rdx
	add	%rdx, Array.val(%rax, %rcx, 1<<3)
	inc	%rcx

4:
	cmp	Array.len(%rax), %rcx
	jl	3b

	mov	Array.len(%rdi), %rdi
	call	new_zero_array
	mov	%rax, OUT(%rbp)

	mov	THIS(%rbp), %rdi
	mov	ZERO(%rbp), %rsi
	mov	Array.len(%rdi), %rcx
	jmp	6f

5:
	mov	Array.val(%rdi, %rcx, 1<<3), %rdx
	mov	Array.val(%rsi, %rdx, 1<<3), %r8
	dec	%r8
	mov	%r8, Array.val(%rsi, %rdx, 1<<3)
	mov	%rdx, Array.val(%rax, %r8, 1<<3)
6:
	dec	%rcx
	test	%rcx, %rcx
	jns	5b

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	heapsort
# @description	Performs a heapsort on an array
# @param	%rdi	Pointer to the input array
# @return	%rax	Pointer to the (sorted) output array
.equ	THIS, -8
.equ	HEAP, -16
.equ	I, -24
.equ	TMP, -32
.type	heapsort, @function
heapsort:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)

	mov	Array.len(%rdi), %rdi
	call	BinaryHeap_ctor
	mov	%rax, HEAP(%rbp)

	# Free the current backing array since we will be modifying it
	mov	(%rax), %rdi
	call	free

	# Assign size and backing array to the heap
	mov	HEAP(%rbp), %rax
	mov	THIS(%rbp), %rdi
	lea	Array.val(%rdi), %rcx
	mov	%rcx, (%rax)
	mov	Array.len(%rdi), %rcx
	mov	%ecx, 8(%rax)

	# Stage the BinaryHeap for calls to trickle_down
	mov	%rax, %rdi

	shr	%rcx
	mov	%rcx, I(%rbp)
	jmp	2f

1:
	call	BinaryHeap_trickle_down

2:
	decq	I(%rbp)
	mov	I(%rbp), %rsi
	test	%rsi, %rsi
	jns	1b

	jmp	4f

3:
	decl	8(%rdi)
	mov	(%rdi), %rax
	mov	8(%rdi), %ecx
	mov	(%rax, %rcx, 1<<3), %r8
	mov	(%rax), %r9
	mov	%r8, (%rax)
	mov	%r9, (%rax, %rcx, 1<<3)
	mov	$0, %rsi
	call	BinaryHeap_trickle_down

4:
	cmpl	$1, 8(%rdi)
	jg	3b

	# Free the BinaryHeap
	call	free

	mov	ARR(%rbp), %rdi
	call	reverse

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	mergesort
# @description	Performs a mergesort on an array
# @param	%rdi	Pointer to the input Array
# @return	%rax	Pointer to the (sorted) output array
.equ	ARR, -8
.equ	LEN2, -16
.equ	ARR0, -24
.equ	ARR1, -32
.type	mergesort, @function
mergesort:
	push	%rbp
	mov	%rsp, %rbp

	cmpq	$1, Array.len(%rdi)
	cmovle	%rsi, %rax
	jle	1f

	sub	$32, %rsp
	mov	%rdi, ARR(%rbp)

	xor	%rsi, %rsi
	mov	Array.len(%rdi), %rdx
	shr	%rdx
	mov	%rdx, LEN2(%rbp)

	call	Array_slice
	mov	%rax, ARR0(%rbp)

	# End of the first array is start of the second
	mov	%rdx, %rsi
	xor	%rdx, %rdx
	call	Array_slice
	mov	%rax, ARR1(%rbp)

	mov	ARR0(%rbp), %rdi
	call	mergesort

	mov	ARR1(%rbp), %rdi
	call	mergesort

	mov	ARR0(%rbp), %rdi
	mov	ARR1(%rbp), %rsi
	mov	ARR(%rbp), %rdx
	call	merge

1:
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	quicksort
# @description	Performs a quicksort on an array
# @param	%rdi	Pointer to the array to sort
# @return	%rax	Pointer to the (sorted) output array
.type	quicksort, @function
quicksort:
	xor	%rsi, %rsi
	mov	Array.len(%rdi), %rdx
	call	_quicksort
	ret

# @function	_quicksort
# @description	File private recursive quicksort helper
# @param	%rdi	Pointer to the array to sort
# @param	%rsi	Start index
# @param	%rdx	Limit (# of elements to sort)
.equ	ARR, -8
.equ	STRT, -16
.equ	LMT, -24
.equ	PVT, -32
.equ	P, -40
.equ	J, -48
.equ	Q, -56
_quicksort:
	push	%rbp
	push	%r8
	push	%r9
	mov	%rsp, %rbp

	cmp	$1, %rdx
	jle	5f

	sub	$56, %rsp
	mov	%rdi, ARR(%rbp)
	mov	%rsi, STRT(%rbp)
	mov	%rdx, LMT(%rbp)

	mov	%rdx, %rdi
	call	random_int

	add	%rsi, %rax
	mov	ARR(%rbp), %rdi
	mov	Array.val(%rdi, %rax, 1<<3), %rax
	mov	%rax, PVT(%rbp)

	mov	STRT(%rbp), %rax

	# i - 1
	mov	%rax, P(%rbp)
	decq	P(%rbp)

	# i
	mov	%rax, J(%rbp)

	# i + n
	mov	%rax, Q(%rbp)
	add	%rdx, Q(%rbp)

	jmp	4f

1:
	mov	ARR(%rbp), %rdi
	mov	Array.val(%rdi, %rax, 1<<3), %rdi
	mov	PVT(%rbp), %rsi
	call	strcmp

	# Restore source array and keep that in %rdi to avoid moving it all over the place
	mov	ARR(%rbp), %rdi

	test	%rax, %rax
	jns	2f
	jz	3f

	incq	P(%rbp)
	mov	J(%rbp), %r8
	mov	P(%rbp), %r9
	mov	Array.val(%rdi, %r8, 1<<3), %rcx
	mov	Array.val(%rdi, %r9, 1<<3), %rdx
	mov	%rcx, Array.val(%rdi, %r9, 1<<3)
	mov	%rdx, Array.val(%rdi, %r8, 1<<3)
	jmp	3f

2:
	decq	Q(%rbp)
	mov	J(%rbp), %r8
	mov	Q(%rbp), %r9
	mov	Array.val(%rdi, %r8, 1<<3), %rcx
	mov	Array.val(%rdi, %r9, 1<<3), %rdx
	mov	%rcx, Array.val(%rdi, %r9, 1<<3)
	mov	%rdx, Array.val(%rdi, %r8, 1<<3)
	jmp	4f

3:
	incq	J(%rbp)

4:
	mov	J(%rbp), %rax
	cmp	Q(%rbp), %rax
	jl	1b

	# Source array should ALREADY be in %rdi so we just need to restore the start (i)
	mov	STRT(%rbp), %rsi
	mov	P(%rbp), %rdx
	sub	%rsi, %rdx
	inc	%rdx
	call	_quicksort

	mov	Q(%rbp), %rsi
	mov	LMT(%rbp), %rdx
	mov	%rsi, %rax
	sub	STRT(%rbp), %rax
	sub	%rax, %rdx
	call	_quicksort

	# Restore start and limit so that parameters remain unscathed
	mov	STRT(%rbp), %rsi
	mov	LMT(%rbp), %rdx
	
5:
	mov	ARR(%rbp), %rax
	mov	%rbp, %rsp
	pop	%r9
	pop	%r8
	pop	%rbp
	ret

# @function	random_int
# @description	Generates random integer in the range of 0..n
# @param	%rdi	Maximum value (n)
# @return	%rax	An integer in the range 0..n
random_int:
	push	%rdx

1:
	rdrand	%rax
	jnc	1b

	xor	%rdx, %rdx
	div	%rdi

	mov	%rdx, %rax
	pop	%rdx
	ret

# @function	merge
# @description	File private helper for mergesort that merges the two subarrays into an output
#		array in sorted order
# @param	%rdi	Subarray 1
# @param	%rsi	Subarray 2
# @param	%rdx	Output array
# @return	%rax	The output array, now sorted
.equ	ARR0, -8
.equ	ARR1, -16
.equ	ARR, -24
.equ	I0, -32
.equ	I1, -40
.equ	I, -48
merge:
	push	%rbp
	mov	%rsp, %rbp

	# Local variables
	sub	$48, %rsp
	mov	%rdi, ARR0(%rbp)
	mov	%rsi, ARR1(%rbp)
	mov	%rdx, ARR(%rbp)
	movq	$0, I0(%rbp)
	movq	$0, I1(%rbp)
	movq	$0, I(%rbp)

	jmp	5f

1:
	mov	ARR0(%rbp), %rax
	mov	I0(%rbp), %rcx
	cmp	Array.len(%rax), %rcx
	je	2f

	mov	ARR1(%rbp), %rax
	mov	I1(%rbp), %rcx
	cmp	Array.len(%rax), %rcx
	je	3f

	mov	ARR0(%rbp), %rdi
	mov	I0(%rbp), %rax
	mov	Array.val(%rdi, %rax, 1<<3), %rdi
	mov	ARR1(%rbp), %rsi
	mov	I1(%rbp), %rax
	mov	Array.val(%rsi, %rax, 1<<3), %rsi
	call	strcmp
	cmp	$0, %rax
	jle	3f

2:
	# a[i] = a1[i1++]
	mov	ARR1(%rbp), %rax
	mov	I1(%rbp), %rcx
	mov	Array.val(%rax, %rcx, 1<<3), %rdx

	mov	ARR(%rbp), %rax
	mov	I(%rbp), %rcx
	mov	%rdx, Array.val(%rax, %rcx, 1<<3)
	incq	I1(%rbp)

	jmp	4f

3:
	# a[i] = a0[i0++]
	mov	ARR0(%rbp), %rax
	mov	I0(%rbp), %rcx
	mov	Array.val(%rax, %rcx, 1<<3), %rdx

	mov	ARR(%rbp), %rax
	mov	I(%rbp), %rcx
	mov	%rdx, Array.val(%rax, %rcx, 1<<3)
	incq	I0(%rbp)

4:
	incq	I(%rbp)

5:
	mov	ARR(%rbp), %rax
	mov	I(%rbp), %rcx
	cmp	Array.len(%rax), %rcx
	jl	1b

	mov	ARR(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	Array_slice
# @description	File private helper that returns a shallow copy of a portion of an array into a new
#		array object selected from start to end, where start and end represent the index of
#		items in that array
# @param	%rdi	Pointer to the source Array
# @param	%rsi	Start index
# @param	%rdx	End index. If NULL extraction will continue to the end of the array.
# @return	%rax	The shallow copy
.equ	THIS, -8
.equ	START, -16
.equ	END, -24
.equ	LEN, -32
.type	Array_slice, @function
Array_slice:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, START(%rbp)
	mov	%rdx, END(%rbp)

	test	%rdx, %rdx
	jnz	1f

	mov	Array.len(%rdi), %rdx

1:
	# Calculate the memory needed for the new array
	mov	%rdx, %rdi
	sub	%rsi, %rdi
	mov	%rdi, LEN(%rbp)
	inc	%rdi					# Add 1 to store the len
	shl	$3, %rdi
	call	alloc

	# Set the length (and also limit for movsq)
	mov	LEN(%rbp), %rcx
	mov	%rcx, Array.len(%rax)

	# MOVSQ
	lea	Array.val(%rax), %rdi			# Destination
	mov	THIS(%rbp), %rsi
	mov	START(%rbp), %rdx
	lea	Array.val(%rsi, %rdx, 1<<3), %rsi	# Source
	rep	movsq

	mov	THIS(%rbp), %rdi
	mov	START(%rbp), %rsi
	mov	END(%rbp), %rdx
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	reverse
# @description	File private helper to reverse an array in-place
# @param	%rdi	Pointer to an Array
# @return	%rax	The same pointer to the (reversed) array
reverse:
	# Use two counters, one which increments and one which decrements ...
	mov	Array.len(%rdi), %rax
	xor	%rcx, %rcx
	jmp	2f

1:
	dec	%rax
	mov	Array.val(%rdi, %rcx, 1<<3), %rdx
	xchg	%rdx, Array.val(%rdi, %rax, 1<<3)
	mov	%rdx, Array.val(%rdi, %rcx, 1<<3)
	inc	%rcx

2:
	cmp	%rax, %rcx
	jl	1b

	mov	%rdi, %rax
	ret

# @function	new_zero_array
# @description	Creates an array of length k with all the values set to zero
# @param	%rdi	The length of the array
# @return	%rax	Pointer to the new array
.equ	LEN, -8
.equ	ARR, -16
new_zero_array:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, LEN(%rbp)

	# Allocate
	inc	%rdi		# Add one for the count
	shl	$3, %rdi	# Convert to quadwords (multiply by eight)
	call	alloc
	mov	%rax, ARR(%rbp)

	# Set the length
	mov	LEN(%rbp), %rcx
	mov	%rcx, Array.len(%rax)

	# Zero out all the items STOSQ
	lea	Array.val(%rax), %rdi
	xor	%rax, %rax
	rep	stosq

	mov	LEN(%rbp), %rdi
	mov	ARR(%rbp), %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret
