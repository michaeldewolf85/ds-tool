# inc/settings.inc - Application flags and settings

## Maximum arguments
.equ	MAX_ARGS, 1<<5			# 32 arguments

## Length of input buffer
.equ	INPUT_BUFFER_LEN, MAX_ARGS<<3	# 256 bytes
