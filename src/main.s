# main.s - Application entry point

.include	"sys.inc"

.section  .rodata

hello:
  .ascii  "Hello Donkey!\n"
  .equ    hello_len, . - hello

.section  .text

.globl  _start
_start:
  mov   $SYS_WRITE, %rax
  mov   $STDOUT, %rdi
  mov   $hello, %rsi
  mov   $hello_len, %rdx
  syscall

  mov   $SYS_EXIT, %rax
  mov   $EXIT_SUCCESS, %rdi
  syscall
