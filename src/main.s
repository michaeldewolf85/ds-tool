# main.s - Application entry point

.include	"settings.inc"
.include	"sys.inc"

.section  .rodata

logo:
	.ascii	" ___  ___   ___           _\n"
	.ascii	"| . \\/ __> |_ _|___  ___ | |\n"
	.ascii	"| | |\\__ \\  | |/ . \\/ . \\| |\n"
	.ascii	"|___/<___/  |_|\\___/\\___/|_|\n\n"
	.equ	logo_len, . - logo

prompt:
	.ascii	"ds⟩ "
	.equ	prompt_len, . - prompt

.section  .text

.globl  _start
_start:
	# Allocate some space on the stack for input buffer (TODO remove)
	sub	$INPUT_LENGTH, %rsp

	# Write logo
	mov	$SYS_WRITE, %rax
	mov	$STDOUT, %rdi
	mov	$logo, %rsi
	mov	$logo_len, %rdx
	syscall

repl:
	# Write prompt
	mov	$SYS_WRITE, %rax
	mov	$STDOUT, %rdi
	mov	$prompt, %rsi
	mov	$prompt_len, %rdx
	syscall

	# Wait for user input
	mov		$SYS_READ, %rax
	mov		$STDIN, %rdi
	mov		%rsp, %rsi
	mov		$INPUT_LENGTH, %rdx
	syscall

	jmp	repl

