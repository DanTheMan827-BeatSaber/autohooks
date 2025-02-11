#include "../shared/hooks.hpp"

MAKE_DLOPEN_HOOK(Test, 0, void) {
    // This will absolutely crash. It's just a test to make sure the compiler sees the logger
}
