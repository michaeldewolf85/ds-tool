# main.s - Application entrypoint

###### Constants ######

##### System call codes #####
.equ  SYS_EXIT, 0x3c
.equ  SYS_WRITE, 0x01

##### File descriptors #####
.equ  STDOUT, 1

##### Exit status codes #####
.equ  EXIT_SUCCESS, 69

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
