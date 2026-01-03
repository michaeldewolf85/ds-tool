# proc/handlers/dualarraydeque.s - Handlers for DualArrayDeque

.include	"structs.inc"

.globl	dualarraydeque, dualarraydeque_handler

# DualArrayDeque struct
	.struct	0
DualArrayDeque.front:
	.struct	DualArrayDeque.front + 1<<3
DualArrayDeque.back:
	.struct	DualArrayDeque.back + 1<<3
	.equ	DUALARRAYDEQUE_SIZE, .

.section .rodata

.type	dualarraydeque, @object
dualarraydeque:
	.ascii	"dualarraydeque\0"

get:
	.ascii	"get\0"
set:
	.ascii	"set\0"
add:
	.ascii	"add\0"
remove:
	.ascii	"remove\0"

commands:
	.quad	get
	.quad	set
	.quad	add
	.quad	remove
	.quad	0	# Sentinel

handlers:
	.quad	DualArrayDeque_get
	.quad	DualArrayDeque_set
	.quad	DualArrayDeque_add
	.quad	DualArrayDeque_remove

start_delim:
	.ascii	"[ \0"

mid_delim:
	.ascii	", \0"

end_delim:
	.ascii	" ]\n\n\0"

newline:
	.ascii	"\n\0"

malformed:
	.ascii	"Malformed command\n\0"

null:
	.ascii	"NULL\0"

front_label:
	.ascii	"## Front ##\n\0"

back_label:
	.ascii	"## Back ##\n\0"

.section .bss

# DualArrayDeque singleton pointer
instance:
	.zero	1<<3

.section .text

# @function	dualarraydeque_handler
# @description	Handler for the "dualarraydeque" command
# @param	%rdi	Pointer to the Input args struct
# @return	void
.type	dualarraydeque_handler, @function
dualarraydeque_handler:
	push	%rbp
	mov	%rsp, %rbp

	# Check for initialization
	cmpq	$0, instance
	je	new

1:
	mov	Input.argv + 8(%rbx), %rdi	# Second argument is the operation
	xor	%r12, %r12			# Index of found operation

	cmpq	$1, Input.argc(%rbx)		# If only one argument, print the arraystack ... 
	je	4f

	cmpq	$3, Input.argc(%rbx)		# Otherwise, we must have 3 arguments to be valid
	jl	error

check:
	mov	commands(, %r12, 8), %rsi
	cmp	$0, %rsi			# Check for the sentinel, if we match here the 
	je	error				# command was not found

	call	strcmp
	cmp	$0, %rax
	je	match

	inc	%r12
	jmp	check

match:
	mov	Input.argv + 16(%rbx), %rdi	# Third argument is always an index
	call	atoi
	cmp	$0, %rax
	jl	error

	mov	%rax, %rsi
	mov	Input.argv + 24(%rbx), %rdx	# Third argument may be a string pointer

	mov	instance, %rdi			# Ensure instance is in place
	call	*handlers(, %r12, 8)		# Call the handler

	mov	$null, %r12
	mov	%rax, %rdi
	cmp	$0, %rax
	cmove	%r12, %rdi
	call	log

	mov	$newline, %rdi
	call	log

4:
	mov	instance, %rdi
	call	DualArrayDeque_log
3:
	mov	%rbp, %rsp
	pop	%rbp
	ret

error:
	mov	$malformed, %rdi
	call	log
	jmp 3b

# DualArrayDeque singleton NOT initialized yet
new:
	call	DualArrayDeque_ctor
	mov	%rax, instance
	jmp	1b

# @function	DualArrayDeque_ctor
# @description	Constructor for DualArrayDeque
# @return	%rax	Pointer to the DualArrayDeque instance
.equ	THIS, -8
DualArrayDeque_ctor:
	push	%rbp
	mov	%rsp, %rbp

	mov	$DUALARRAYDEQUE_SIZE, %rdi
	call	alloc

	sub	$8, %rsp
	mov	%rax, THIS(%rbp)

	# Intialize "front" ArrayStack
	call	ArrayStack_ctor
	mov	THIS(%rbp), %rcx
	mov	%rax, DualArrayDeque.front(%rcx)

	# Intialize "back" ArrayStack
	call	ArrayStack_ctor
	mov	THIS(%rbp), %rcx
	mov	%rax, DualArrayDeque.back(%rcx)

	mov	%rcx, %rax
	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	DualArrayDeque_length
# @description	Returns the length of the DualArrayDeque
# @param	%rdi	Pointer to the DualArrayDeque
# @return	%rax	Length of the DualArrayDeque
.equ	THIS, -8
.equ	LENGTH, -16
DualArrayDeque_length:
	push	%rbp
	mov	%rsp, %rbp

	sub	$16, %rsp
	mov	%rdi, THIS(%rbp)
	movq	$0, LENGTH(%rbp)

	# Get the length of "front" and add it to our length
	mov	DualArrayDeque.front(%rdi), %rdi
	call	ArrayStack_length
	add	%rax, LENGTH(%rbp)

	# Get the length of "back" and add it to our length
	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.back(%rdi), %rdi
	call	ArrayStack_length
	add	%rax, LENGTH(%rbp)

	# Tee up the return value and restore DualArrayDeque pointer to %rdi
	mov	THIS(%rbp), %rdi
	mov	LENGTH(%rbp), %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret
	
# @description	Get the element at the specified index
# @param	%rdi	Pointer to the DualArrauDeque
# @param	%rsi	Index of the element to get
# @return	%rax	Pointer to the element or NULL if not found
.equ	THIS, -8
.equ	INDEX, -16
.equ	FRONT_LENGTH, -24
DualArrayDeque_get:
	push	%rbp
	mov	%rsp, %rbp

	# Store variables
	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, INDEX(%rbp)
	mov	DualArrayDeque.front(%rdi), %rdi
	call	ArrayStack_length
	mov	%rax, FRONT_LENGTH(%rbp)

	# Check if the requested element is in the "front" or "back"
	mov	INDEX(%rbp), %rsi
	cmp	FRONT_LENGTH(%rbp), %rsi
	jge	1f

# Index indicates the "front" array
	# Move "front" array into first function arg
	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.front(%rdi), %rdi

	# Determines correct index to query as "front" array is stored in reverse order
	mov	FRONT_LENGTH(%rbp), %rsi
	sub	INDEX(%rbp), %rsi
	dec	%rsi
	jmp	2f

# Index indicates the "back" array
1:
	# Move "back" array into first function arg
	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.back(%rdi), %rdi

	# Determines correct index to query as "front" array is stored in reverse order
	mov	INDEX(%rbp), %rsi
	sub	FRONT_LENGTH(%rbp), %rsi

# Make get function call
2:
	# Return value in %rax
	call	ArrayStack_get

	# Restore %rdi pointer
	mov	THIS(%rbp), %rdi

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	DualArrayDeque_set
# @description	Set the specified index to the specified value
# @param	%rdi	Pointer to the DualArrayDeque
# @param	%rsi	Index of the element to set
# @param	%rdx	Pointer to the value to set
# @param	%rax	Returns the previous value
.equ	THIS, -8
.equ	INDEX, -16
.equ	VALUE, -24
.equ	FRONT_LENGTH, -32
DualArrayDeque_set:
	push	%rbp
	mov	%rsp, %rbp

	# Store variables
	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, INDEX(%rbp)
	mov	%rdx, VALUE(%rbp)
	mov	DualArrayDeque.front(%rdi), %rdi
	call	ArrayStack_length
	mov	%rax, FRONT_LENGTH(%rbp)

	# Check if the requested element is in the "front" or "back"
	mov	INDEX(%rbp), %rsi
	cmp	FRONT_LENGTH(%rbp), %rsi
	jge	1f

# Index indicates the "front" array
	# Move "front" array into first function arg
	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.front(%rdi), %rdi

	# Determines correct index to query as "front" array is stored in reverse order
	mov	FRONT_LENGTH(%rbp), %rsi
	sub	INDEX(%rbp), %rsi
	dec	%rsi
	jmp	2f

# Index indicates the "back" array
1:
	# Move "back" array into first function arg
	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.back(%rdi), %rdi

	# Determines correct index to query as "front" array is stored in reverse order
	mov	INDEX(%rbp), %rsi
	sub	FRONT_LENGTH(%rbp), %rsi

# Make get function call
2:
	# Move value into %rdx
	mov	VALUE(%rbp), %rdx

	# Make "set" call and put return value in %rax
	call	ArrayStack_set

	# Restore %rdi pointer
	mov	THIS(%rbp), %rdi

	mov	%rbp, %rsp
	pop	%rbp
	ret
	
# @function	DualArrayDeque_add
# @description	Adds an element to the DualArrayDeque at the specified index
# @param	%rdi	Pointer to the DualArrayDeque instance
# @param	%rsi	The index to add at
# @param	%rdx	Pointer to the element to add
# @return	%rax	Pointer to the added element or NULL on failure
.equ	THIS, -8
.equ	INDEX, -16
.equ	VALUE, -24
.equ	FRONT_LENGTH, -32
DualArrayDeque_add:
	push	%rbp
	mov	%rsp, %rbp

	# Variables on stack
	sub	$32, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, INDEX(%rbp)
	mov	%rdx, VALUE(%rbp)

	# Check if we need to manipulate the back or front
	mov	DualArrayDeque.front(%rdi), %rdi
	call	ArrayStack_length
	mov	%rax, FRONT_LENGTH(%rbp)
	cmp	%rax, INDEX(%rbp)
	jge	1f

# Index is less than the front length so we add it to the "front"
	# "Front" ArrayStack pointer in %rdi
	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.front(%rdi), %rdi	# Pointer to "front" ArrayStack

	# Insertion index in %rsi, the front array is stored in backwards order to improve
	# asymptotic performance (operations at END of ArrayStack MOST efficient)
	mov	FRONT_LENGTH(%rbp), %rsi
	sub	INDEX(%rbp), %rsi		# Subtract the index from the "front" length
	jmp	2f

# Index is greater than or equal to front length so we need to add it to the "back"
1:
	# "Back" ArrayStack pointer in %rdi
	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.back(%rdi), %rdi	# Pointer to "back" ArrayStack

	# Insertion index in %rsi
	mov	INDEX(%rbp), %rsi		# "Actual" index of element to add is obtained ...
	sub	FRONT_LENGTH(%rbp), %rsi		# ... by subtracting the "front" length

# Insert the element and return
2:
	# Insertion element in %rdx
	mov	VALUE(%rbp), %rdx

	# Make the add function call, return value in %rax
	call	ArrayStack_add

	# Restore instance pointer to %rdi
	mov	THIS(%rbp), %rdi

	# Balance the "front" and "back
	call	balance

	# Assign return value
	mov	VALUE(%rbp), %rax

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	DualArrayDeque_remove
# @description	Remove the element at the specified index
# @param	%rdi	Pointer to the DualArrauDeque
# @param	%rsi	Index of the element to remove
# @return	%rax	Pointer to the removed element or NULL if an error occurred
.equ	THIS, -8
.equ	INDEX, -16
.equ	FRONT_LENGTH, -24
DualArrayDeque_remove:
	push	%rbp
	mov	%rsp, %rbp

	# Store variables
	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	mov	%rsi, INDEX(%rbp)
	mov	DualArrayDeque.front(%rdi), %rdi
	call	ArrayStack_length
	mov	%rax, FRONT_LENGTH(%rbp)

	# Check if the requested element is in the "front" or "back"
	mov	INDEX(%rbp), %rsi
	cmp	FRONT_LENGTH(%rbp), %rsi
	jge	1f

# Index indicates the "front" array
	# Move "front" array into first function arg
	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.front(%rdi), %rdi

	# Determines correct index to query as "front" array is stored in reverse order
	mov	FRONT_LENGTH(%rbp), %rsi
	sub	INDEX(%rbp), %rsi
	dec	%rsi
	jmp	2f

# Index indicates the "back" array
1:
	# Move "back" array into first function arg
	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.back(%rdi), %rdi

	# Determines correct index to query as "front" array is stored in reverse order
	mov	INDEX(%rbp), %rsi
	sub	FRONT_LENGTH(%rbp), %rsi

# Make get function call
2:
	# Return value in %rax
	call	ArrayStack_remove

	# Restore %rdi pointer
	mov	THIS(%rbp), %rdi

	# Balance the "front" and "back
	call	balance

	mov	%rbp, %rsp
	pop	%rbp
	ret

# @function	balance
# @description	File private function to balance the "front" and "back" (ie make sure both 
#		maintain a length proportionate to one another)
# @param	%rdi	Pointer to the DualArrayDeque
# @return	void
.equ	THIS, -8
.equ	FRONT_LENGTH, -16
.equ	BACK_LENGTH, -24
.equ	LENGTH, -32
.equ	MID, -40
.equ	NEW_FRONT, -48
.equ	NEW_BACK, -56
.equ	CTR, -64
balance:
	push	%rbp
	mov	%rsp, %rbp

	# Stack variables
	sub	$64, %rsp
	mov	%rdi, THIS(%rbp)			# "This" pointer

	mov	DualArrayDeque.front(%rdi), %rdi	
	call	ArrayStack_length
	mov	%rax, FRONT_LENGTH(%rbp)			# Size of "front"

	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.back(%rdi), %rdi
	call	ArrayStack_length
	mov	%rax, BACK_LENGTH(%rbp)			# Size of "back"

	mov	THIS(%rbp), %rdi
	call	DualArrayDeque_length
	mov	%rax, LENGTH(%rbp)			# Total length

	xor	%rdx, %rdx
	mov	$2, %rcx
	div	%rcx
	mov	%rax, MID(%rbp)				# Midpoint

	# Check if 3x the "front" length is less than the "back" length
	mov	FRONT_LENGTH(%rbp), %rax
	imul	$3, %rax
	cmp	BACK_LENGTH(%rbp), %rax
	jl	1f

	# Check if 3x the "back" length is less than the "front" length
	mov	BACK_LENGTH(%rbp), %rax
	imul	$3, %rax
	cmp	FRONT_LENGTH(%rbp), %rax
	jl	1f

6:
	mov	THIS(%rbp), %rdi			# Preserve "this" pointer in %rdi
	mov	%rbp, %rsp
	pop	%rbp
	ret

# Balancing is in order
1:
	
	# Balancing on "front"

	# Make a new "front" ArrayStack
	call	ArrayStack_ctor
	mov	%rax, NEW_FRONT(%rbp)

	movq	$0, CTR(%rbp)				# Loop counter

# Balancing loop for "front"
2:
	mov	MID(%rbp), %rax
	cmp	%rax, CTR(%rbp)				# Loop up until midpoint is reached
	jge	3f

	# Get the element to "add"
	mov	THIS(%rbp), %rdi
	mov	MID(%rbp), %rsi
	sub	CTR(%rbp), %rsi
	dec	%rsi
	call	DualArrayDeque_get			# Element in %rax

	mov	NEW_FRONT(%rbp), %rdi
	mov	CTR(%rbp), %rsi
	mov	%rax, %rdx
	call	ArrayStack_add

	incq	CTR(%rbp)
	jmp	2b

# Balancing on "back"
3:
	call	ArrayStack_ctor
	mov	%rax, NEW_BACK(%rbp)

	movq	$0, CTR(%rbp)				# Loop counter

# Balancing loop for "back"
4:
	mov	LENGTH(%rbp), %rax
	sub	MID(%rbp), %rax
	cmp	%rax, CTR(%rbp)
	jge	5f

	# Get the element to "add"
	mov	THIS(%rbp), %rdi
	mov	MID(%rbp), %rsi
	add	CTR(%rbp), %rsi
	call	DualArrayDeque_get			# Element in %rax

	mov	NEW_BACK(%rbp), %rdi
	mov	CTR(%rbp), %rsi
	mov	%rax, %rdx
	call	ArrayStack_add

	incq	CTR(%rbp)
	jmp	4b

5:
	# Assign the new ArrayStacks and free the old ones
	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.front(%rdi), %rdi
	call	free

	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.back(%rdi), %rdi
	call	free

	mov	THIS(%rbp), %rdi
	mov	NEW_FRONT(%rbp), %rax
	mov	%rax, DualArrayDeque.front(%rdi)
	mov	NEW_BACK(%rbp), %rax
	mov	%rax, DualArrayDeque.back(%rdi)
	jmp	6b	

# @function	DualArrayDeque_log
# @description	Log the innards of a DualArrayDeque
# @param	%rdi	Pointer to the DualArrayDeque
# @return	void
.equ	THIS, -8
.equ	LENGTH, -16
.equ	CTR, -24
DualArrayDeque_log:
	push	%rbp
	mov	%rsp, %rbp

	sub	$24, %rsp
	mov	%rdi, THIS(%rbp)
	call	DualArrayDeque_length
	mov	%rax, LENGTH(%rbp)
	movq	$0, CTR(%rbp)

	mov	$start_delim, %rdi
	call	log

	cmpq	$0, LENGTH(%rbp)
	je	2f

# Print loop
1:
	mov	THIS(%rbp), %rdi
	mov	CTR(%rbp), %rsi
	call	DualArrayDeque_get

	mov	%rax, %rdi
	call	log

	incq	CTR(%rbp)
	mov	CTR(%rbp), %rsi
	cmp	LENGTH(%rbp), %rsi
	jge	2f

	mov	$mid_delim, %rdi
	call	log
	jmp	1b

# Done printing values, still need to print the end delimiter
2:
	mov	$end_delim, %rdi
	call	log

	mov	$front_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.front(%rdi), %rdi
	call	ArrayStack_log

	mov	$back_label, %rdi
	call	log

	mov	THIS(%rbp), %rdi
	mov	DualArrayDeque.back(%rdi), %rdi
	call	ArrayStack_log

	mov	THIS(%rbp), %rdi

	mov	%rbp, %rsp
	pop	%rbp
	ret
