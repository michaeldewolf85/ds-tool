# inc/settings.inc - Application flags and settings

## Maximum arguments
.equ	MAX_ARGS, 1<<5			# 32 arguments

## Length of input buffer
.equ	INPUT_BUFFER_LEN, MAX_ARGS<<3	# 256 bytes

## Length of the log buffer
.equ	LOG_BUFFER_LEN, 1<<9 - 1<<2	# 512 bytes, - 4 for 4 bit length
