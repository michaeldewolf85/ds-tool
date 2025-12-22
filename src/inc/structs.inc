# proc/read.inc - Resuable data structures

## Parsed user input
	.struct	0
Input.argc:
	.struct Input.argc + 1<<3
Input.argv:
	.struct Input.argv + 1<<3 * 63
	.equ	INPUT_SIZE, .


