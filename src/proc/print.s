# proc/print.s - Printing output

.include	"common.inc"
.include	"linux.inc"
.include	"settings.inc"

.globl	log, print

# LogBuffer struct
	.struct	0
LogBuffer.length:
	.struct	LogBuffer.length + 1<<2
LogBuffer.data:
	.struct LogBuffer.data + LOG_BUFFER_LEN
	.equ	LOG_BUFFER_SIZE, .

.section .bss

.align	16
log_buffer:
	.zero	LOG_BUFFER_SIZE

.section .text

# @public	log
# @description	Writes to the log buffer and flushes the log buffer to STDOUT if it becomes full
# @param	%rdi	Address of the (null terminated) string to write to the buffer
# @return	%rax	The length of the log buffer at the end of the operation
.type	log, @function
log:
	push	%rbx					# Obtain some non-volatile storage

	mov	%rdi, %rbx				# Put address of str in non-volatile area

# Loop setup
1:
	mov	log_buffer + LogBuffer.length, %eax	# Cache buffer length during the operation

# Main loop
2:
	cmp	$LOG_BUFFER_LEN, %eax			# Check if the log buffer is full and needs
	jge	4f					# to be flushed

	mov	(%rbx), %dl				# The current character being examined
	mov	%dl, log_buffer + LogBuffer.data(, %eax)# Move character into buffer
	inc	%eax					# Increment length

	cmp	$NULL, %dl				# If char is null we are done
	je	3f

	inc	%rbx					# Increment next char address
	jmp	2b

3:
	mov	%eax, log_buffer + LogBuffer.length	# Update the length of the log buffer

	pop	%rbx					# Restore %rbx
	ret

# Log buffer is full and needs to be flushed before the operation can continue ...
4:
	mov	%eax, log_buffer + LogBuffer.length	# Set the log buffer length in memory
	call	print
	jmp	1b

# @public	print
# @description	Prints the log buffer to STDOUT
# @return	%rdi	The number of characters printed
.type	print, @function
print:
	mov	$SYS_WRITE, %rax
	mov	$STDOUT, %rdi
	mov	$log_buffer + LogBuffer.data, %rsi
	mov	log_buffer + LogBuffer.length, %edx
	syscall

	movl	$0, log_buffer + LogBuffer.length

	ret
