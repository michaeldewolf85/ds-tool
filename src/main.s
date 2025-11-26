# main.s - Application entry point

.include	"sys.inc"

.section  .rodata

logo:
	.ascii	" ___  ___   ___           _\n"
	.ascii	"| . \\/ __> |_ _|___  ___ | |\n"
	.ascii	"| | |\\__ \\  | |/ . \\/ . \\| |\n"
	.ascii	"|___/<___/  |_|\\___/\\___/|_|\n"
  .equ    logo_len, . - logo

.section  .text

.globl  _start
_start:
  mov   $SYS_WRITE, %rax
  mov   $STDOUT, %rdi
  mov   $logo, %rsi
  mov   $logo_len, %rdx
  syscall

  mov   $SYS_EXIT, %rax
  mov   $EXIT_SUCCESS, %rdi
  syscall
