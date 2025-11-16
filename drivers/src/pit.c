#include "pit.h"

u16 poll_pit() {
  outb(0x43, 0x00);

  u8 lo = inb(0x40);
  u8 hi = inb(0x40);

  return (hi << 8) | lo;
}

u32 pit_diff(u16 old, u16 now) {
  if (now <= old)
    return (old - now);
  else
    return (old + (65536 - now));
}

static u32 pit_accum = 0;
static u16 last_counter = 0;
static u64 ticks = 0;

u64 tick_update() {
  u16 now = poll_pit();
  u32 diff = pit_diff(last_counter, now);
  last_counter = now;

  pit_accum += diff;

  while (pit_accum >= 65536) {
    pit_accum -= 65536;
    ticks++;
  }

  return ticks;
}
