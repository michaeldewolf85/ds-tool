# proc/handlers/yfasttrie.s - Handler for the "yfasttrie" command

.include	"common.inc"
.include	"structs.inc"

.equ	YFASTTRIE_HEIGHT, 4
.globl	yfasttrie, yfasttrie_handler

.section .bss

this:
	.zero	1<<3

.section .rodata

yfasttrie:
	.ascii	"yfasttrie\0"

add:
	.ascii	"add\0"
remove:
	.ascii	"remove\0"
find:
	.ascii	"find\0"

commands:
	.quad	add
	.quad	remove
	.quad	find
	.quad	0	# Sentinel

handlers:
	.quad	YFastTrie_add
	.quad	YFastTrie_remove
	.quad	YFastTrie_find

newline:
	.byte	LF, NULL
true:
	.ascii	"TRUE\0"
false:
	.ascii	"FALSE\0"

malformed:
	.ascii	"Malformed command\n\0"

.section .text

# @function	yfasttrie_handler
# @description	Handler for the "yfasttrie" command
# @param	%rdi	User input
# @return	void
.equ	INPUT, -8
.equ	COUNTER, -16
.type	yfasttrie_handler, @function
yfasttrie_handler:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, INPUT(%rbp)
	movq	$0, COUNTER(%rbp)

	cmpq	$NULL, this
	jne	1f

	mov	$YFASTTRIE_HEIGHT, %rdi
	call	YFastTrie_ctor
	mov	%rax, this

1:
	mov	INPUT(%rbp), %rax		# Input
	cmpq	$1, Input.argc(%rax)		# If only 1 argument, print the BinaryTrie
	je	3f

	mov	Input.argv + 8(%rax), %rdi	# Current command in %rdi
check:
	mov	COUNTER(%rbp), %rcx
	mov	commands(, %rcx, 1<<3), %rsi	# Current command being examined
	cmp	$0, %rsi			# Check for NULL sentinel which indicates no ...
	je	error				# matching command was found

	call	strcmp
	cmp	$0, %rax
	je	match

	incq	COUNTER(%rbp)
	jmp	check

match:
	mov	INPUT(%rbp), %rax
	mov	Input.argv + 16(%rax), %rdi
	call	atoi

	mov	this, %rdi
	mov	%rax, %rsi

	mov	COUNTER(%rbp), %rcx
	call	*handlers(, %rcx, 1<<3)

	mov	$false, %rdi
	mov	$true, %rcx
	test	%rax, %rax
	cmovnz	%rcx, %rdi

	cmpq	$2, COUNTER(%rbp)
	jl	2f

	test	%rax, %rax
	jns	nxt

	mov	$false, %rdi
	jmp	2f

nxt:
	mov	%rax, %rdi
	call	itoa
	mov	%rax, %rdi

2:
	call	log

	mov	$newline, %rdi
	call	log

	mov	$newline, %rdi
	call	log

3:
	mov	this, %rdi
	call	YFastTrie_log

4:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp	4b
