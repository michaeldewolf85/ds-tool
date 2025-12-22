# inc/linux.inc - Linux system constants

###### System call codes ######
.equ	SYS_EXIT, 0x3c
.equ	SYS_WRITE, 0x01
.equ	SYS_READ, 0x00
.equ	SYS_BRK, 0xc

###### File descriptors #######
.equ	STDIN, 0
.equ	STDOUT, 1

######## Exit statuses ########
.equ	EXIT_SUCCESS, 0
