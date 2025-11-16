#include "io.h"
#include "types.h"

u16 poll_pit();
u32 pit_diff(u16 old, u16 now);
u64 tick_update();
