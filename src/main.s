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

.section	.bss

.lcomm	input, INPUT_LENGTH

.section  .text

.globl  _start
_start:
	# Write logo
  mov   $SYS_WRITE, %rax
  mov   $STDOUT, %rdi
  mov   $logo, %rsi
  mov   $logo_len, %rdx
  syscall

	# Write prompt
  mov   $SYS_WRITE, %rax
  mov   $STDOUT, %rdi
  mov   $prompt, %rsi
  mov   $prompt_len, %rdx
  syscall

	# Wait for user input
	mov		$SYS_READ, %rax
	mov		$STDIN, %rdi
	mov		$input, %rsi
	mov		$INPUT_LENGTH, %rdx
	syscall

	call strlen

  mov   %rax, %rdi
  mov   $SYS_EXIT, %rax
  syscall

strlen:
	push	%rbp
	mov		%rsp, %rbp

	mov		$input, %rbx

	cld														# Clear direction clag so that scasb increments
	mov		$input, %rdi						# Move address of first char to %rdi
	mov		$'\n', %al							# Stop scanning at first newline char
	movl	$INPUT_LENGTH, %ecx			# Set count register to our max input length

	repne	scasb

	sub		%rbx, %rdi							# %rdi - %rbx (original) = length + 1 (newline)
	dec		%rdi										# Remove extra char
	mov		%rdi, %rax

	mov		%rbp, %rsp
	pop		%rbp
	ret
