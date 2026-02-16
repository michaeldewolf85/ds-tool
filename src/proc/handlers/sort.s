# proc/handlers/sort.s - Handler for the "sort" command

.globl	sort, sort_handler

.section .rodata

.type	sort, @object
sort:
	.ascii	"sort\0"

# TODO REMOVE!!
item1:
	.ascii	"Parrot\0"
item2:
	.ascii	"Chicken\0"
item3:
	.ascii	"Budgerigar\0"
item4:
	.ascii	"Owl\0"
item5:
	.ascii	"Columbidae\0"
item6:
	.ascii	"Penguin\0"
item7:
	.ascii	"Blue Jay\0"
item8:
	.ascii	"Hummingbird\0"
item9:
	.ascii	"Falcon\0"
item10:
	.ascii	"Bird-of-paradise\0"
item11:
	.ascii	"Crow\0"
item12:
	.ascii	"Atlantic Canary\0"

argc:
	.quad	12
argv:
	.quad	item1, item2, item3, item4, item5, item6, item7, item8, item9, item10, item11, item12

.section .text

# @function	sort_handler
# @description	Handler for the "sort" comand
# @param	%rdi	Pointer to user input data struct
# @return	void
.type	sort_handler, @function
sort_handler:
	push	%rbp
	mov	%rsp, %rbp

	mov	%rbp, %rsp
	pop	%rbp
	ret
