# main.s - Application entry point

.include	"linux.inc"

.globl	_start

.section .rodata

logo:
	.ascii	" ___  ___   ___           _\n"
	.ascii	"| . \\/ __> |_ _|___  ___ | |\n"
	.ascii	"| | |\\__ \\  | |/ . \\/ . \\| |\n"
	.ascii	"|___/<___/  |_|\\___/\\___/|_|\n\n"
	.equ	logo_len, . - logo

prompt:
	.ascii	"ds⟩ "
	.equ	prompt_len, . - prompt

sample:
	.ascii	"Foo bar bax bax banana onions terrible lettuce boondoggle\0"

.section .text

_start:
	mov	$1000, %r12
lp:
	mov	$sample, %rdi
	call	print
	dec	%r12
	cmp	$0, %r12
	jne	lp

	# Print logo
	mov	$SYS_WRITE, %rax
	mov	$STDOUT, %rdi
	mov	$logo, %rsi
	mov	$logo_len, %rdx
	syscall

repl:
	# Print prompt
	mov	$SYS_WRITE, %rax
	mov	$STDOUT, %rdi
	mov	$prompt, %rsi
	mov	$prompt_len, %rdx
	syscall

	mov	$STDIN, %rdi
	call	read

	mov	%rax, %rdi
	call	evaluate

	jmp	repl
