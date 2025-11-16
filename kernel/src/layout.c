#include "layout.h"

layout a_layout = qwerty;
u8 shift = 0;
u8 caps = 0;

void set_layout(LayoutType layout) {
  switch (layout) {
  case QWERTY:
    a_layout = qwerty;
    break;
  case DVORAK:
    a_layout = dvorak;
    break;
  }
  return;
}

char translate(u8 scancode) {
  if (scancode == 0x2A || scancode == 0x36) {
    shift = 1;
    return 0;
  }
  if (scancode == 0xAA || scancode == 0xB6) {
    shift = 0;
    return 0;
  }
  if (scancode == 0x3A) {
    caps = !caps;
    return 0;
  }

  if (scancode & 0x80) {
    return 0;
  }

  if (shift && caps) {
    return a_layout(scancode, 0);
  } else if (shift || caps) {
    return a_layout(scancode, 1);
  } else {
    return a_layout(scancode, 0);
  }
}

char game_translate(u8 scancode) { return qwerty(scancode, 0); }
