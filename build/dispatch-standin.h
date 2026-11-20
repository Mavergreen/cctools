/* spec: INGREDIENTS.md "Deviations" -- the two libdispatch names ld64-957.1 uses that the 10.9 SDK
 *       lacks. Recaulk's <dispatch/dispatch.h> carries both from its next release (c2dd7a1);
 *       tests/dispatch-standin-test.sh fails once the pinned clang22's Recaulk has them, and this file
 *       goes. Force-included, so it includes nothing: names are only defined, and used after the
 *       sources include the real header. */
#if defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__) && __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ < 101200
#ifndef DISPATCH_APPLY_AUTO
#define DISPATCH_APPLY_AUTO dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
#endif
#define dispatch_queue_global_t dispatch_queue_t
#endif
