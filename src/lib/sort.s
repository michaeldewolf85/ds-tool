# lib/sort.s - Sort algorithms

.globl	mergesort

.section .text

# @function	mergesort
# @description	Performs a mergesort
# @param	%rdi	Number of items
# @param	%rsi	Pointer to the first item
# @return	%rax	Pointer to the first item of the sorted set
.type	mergesort, @function
mergesort:
	ret
