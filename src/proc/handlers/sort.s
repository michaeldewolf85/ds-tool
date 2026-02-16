# proc/handlers/sort.s - Handler for the "sort" command

.include	"common.inc"
.include	"structs.inc"

.globl	sort, sort_handler

.section .rodata

.type	sort, @object
sort:
	.ascii	"sort\0"

quick:
	.ascii	"quick\0"
merge:
	.ascii	"merge\0"
heap:
	.ascii	"heap\0"
counting:
	.ascii	"counting\0"
radix:
	.ascii	"radix\0"

commands:
	.quad	quick, merge, heap, counting, radix, NULL

handlers:
	.quad	quicksort, mergesort, heapsort, countingsort, radixsort

null:
	.ascii	"NULL\0"

malformed:
	.ascii	"Malformed command\n\0"


.section .text

# @function	sort_handler
# @description	Handler for the "sort" comand
# @param	%rdi	Pointer to user input data struct
# @return	void
.equ	INPT, -8
.equ	CIDX, -16
.equ	CTR, -24
.equ	ARR, -32
.type	sort_handler, @function
sort_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$32, %rsp
	mov	%rdi, INPT(%rbp)
	
	mov	Input.argv + 8(%rdi), %rdi
	movq	$0, CIDX(%rbp)

1:
	mov	CIDX(%rbp), %rcx
	mov	commands(, %rcx, 1<<3), %rsi

	# Check for sentinel
	test	%rsi, %rsi
	jz	error

	call	strcmp
	test	%rax, %rax
	jz	3f

	incq	CIDX(%rbp)
	jmp	1b

3:
	# Preserve the index of the handler
	mov	INPT(%rbp), %rdi
	mov	$2, %rsi
	xor	%rdx, %rdx
	call	Array_slice
	mov	%rax, ARR(%rbp)

	cmpq	$2, CIDX(%rbp)
	jle	6f

	movq	$0, CTR(%rbp)
	jmp	5f

4:	
	mov	8(%rdx, %rcx, 1<<3), %rdi
	call	atoi
	mov	CTR(%rbp), %rcx
	mov	ARR(%rbp), %rdx
	xchg	%rax, 8(%rdx, %rcx, 1<<3)
	incq	CTR(%rbp)

5:
	mov	CTR(%rbp), %rcx
	mov	ARR(%rbp), %rdx
	cmp	(%rdx), %rcx
	mov	%rdx, %rax
	jl	4b

6:
	mov	%rax, %rdi
	mov	CIDX(%rbp), %rcx
	call	*handlers(, %rcx, 1<<3)
	mov	%rax, %rdi

	mov	$1, %r10
	xor	%rsi, %rsi
	cmpq	$2, CIDX(%rbp)
	cmovg	%r10, %rsi
	call	Array_log

done:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp	done
