# inc/linux.inc - Linux system constants

###### System call codes ######
.equ	SYS_EXIT, 0x3c
.equ	SYS_WRITE, 0x01
.equ	SYS_READ, 0x00
.equ	SYS_BRK, 0x0c
.equ	SYS_OPEN, 0x02
.equ	SYS_PREAD64, 0x11
.equ	SYS_PWRITE64, 0x12

###### File descriptors #######
.equ	STDIN, 0
.equ	STDOUT, 1

###### File flags ######
.equ	O_RDWR, 0x02		# Open for reading and writing
.equ	O_CREAT, 0x40		# Create file if it doesn't exist
.equ	O_EXCL, 0x80		# With O_CREAT: fail if file already exists

###### File errors ######
.equ	EEXIST, 0xffef

######## Exit statuses ########
.equ	EXIT_SUCCESS, 0
