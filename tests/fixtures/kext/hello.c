/* spec: tests/kext-load-test.sh -- a kext with no library: its kmod_info and _start/_stop are here, as
 *       libkmod.a would supply them, so the 10.9 VM links hello.o with no SDK. */
#include <mach/mach_types.h>
#include <libkern/libkern.h>
kern_return_t hello_start(kmod_info_t *ki, void *d);
kern_return_t hello_stop(kmod_info_t *ki, void *d);
static int loads;
kern_return_t hello_start(kmod_info_t *ki, void *d) { (void)ki; (void)d; loads++; printf("mavergreen cctools hello kext loaded %d\n", loads); return KERN_SUCCESS; }
kern_return_t hello_stop(kmod_info_t *ki, void *d) { (void)ki; (void)d; printf("mavergreen cctools hello kext unloaded\n"); return KERN_SUCCESS; }
__private_extern__ kern_return_t _start(kmod_info_t *ki, void *d);
__private_extern__ kern_return_t _stop(kmod_info_t *ki, void *d);
KMOD_EXPLICIT_DECL(dev.mavergreen.cctools.hello, "1.0.0", _start, _stop)
__private_extern__ kern_return_t _start(kmod_info_t *ki, void *d) { return hello_start(ki, d); }
__private_extern__ kern_return_t _stop(kmod_info_t *ki, void *d) { return hello_stop(ki, d); }
