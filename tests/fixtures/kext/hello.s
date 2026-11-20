# spec: tests/kext-test.sh -- hello.c, compiled by clang22 22.1.8-mavericks.22 with -S -O2 -mkernel
#       -fno-builtin -fno-ident against the 10.9 SDK's Kernel.framework headers; tests/kext-test.sh rebuilds it
#       where clang22 is at hand and fails if it differs.
	.macosx_version_min 10, 9
	.section	__TEXT,__text,regular,pure_instructions
	.globl	_hello_start                    ## -- Begin function hello_start
	.p2align	4
_hello_start:                           ## @hello_start
## %bb.0:
	pushq	%rbp
	movq	%rsp, %rbp
	movl	_loads(%rip), %esi
	incl	%esi
	movl	%esi, _loads(%rip)
	leaq	L_.str(%rip), %rdi
	xorl	%eax, %eax
	callq	_printf
	xorl	%eax, %eax
	popq	%rbp
	retq
                                        ## -- End function
	.globl	_hello_stop                     ## -- Begin function hello_stop
	.p2align	4
_hello_stop:                            ## @hello_stop
## %bb.0:
	pushq	%rbp
	movq	%rsp, %rbp
	leaq	L_.str.1(%rip), %rdi
	xorl	%eax, %eax
	callq	_printf
	xorl	%eax, %eax
	popq	%rbp
	retq
                                        ## -- End function
	.private_extern	__start                 ## -- Begin function _start
	.globl	__start
	.p2align	4
__start:                                ## @_start
## %bb.0:
	pushq	%rbp
	movq	%rsp, %rbp
	movl	_loads(%rip), %esi
	incl	%esi
	movl	%esi, _loads(%rip)
	leaq	L_.str(%rip), %rdi
	xorl	%eax, %eax
	callq	_printf
	xorl	%eax, %eax
	popq	%rbp
	retq
                                        ## -- End function
	.private_extern	__stop                  ## -- Begin function _stop
	.globl	__stop
	.p2align	4
__stop:                                 ## @_stop
## %bb.0:
	pushq	%rbp
	movq	%rsp, %rbp
	leaq	L_.str.1(%rip), %rdi
	xorl	%eax, %eax
	callq	_printf
	xorl	%eax, %eax
	popq	%rbp
	retq
                                        ## -- End function
.zerofill __DATA,__bss,_loads,4,2       ## @loads
	.section	__TEXT,__cstring,cstring_literals
L_.str:                                 ## @.str
	.asciz	"mavergreen cctools hello kext loaded %d\n"

L_.str.1:                               ## @.str.1
	.asciz	"mavergreen cctools hello kext unloaded\n"

	.section	__DATA,__data
	.globl	_kmod_info                      ## @kmod_info
	.p2align	2, 0x0
_kmod_info:
	.quad	0
	.long	1                               ## 0x1
	.long	4294967295                      ## 0xffffffff
	.asciz	"dev.mavergreen.cctools.hello\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000"
	.asciz	"1.0.0\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000"
	.long	4294967295                      ## 0xffffffff
	.quad	0
	.quad	0                               ## 0x0
	.quad	0                               ## 0x0
	.quad	0                               ## 0x0
	.quad	__start
	.quad	__stop

.subsections_via_symbols
