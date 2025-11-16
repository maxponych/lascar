#pragma once
#include "types.h"

typedef char (*layout)(u8 scancode, u8 big);

typedef enum {
  QWERTY,
  DVORAK,
} LayoutType;

extern layout a_layout;

void set_layout(LayoutType layout);
char translate(u8 scancode);
char game_translate(u8 scancode);

char dvorak(u8 scancode, u8 big);
char qwerty(u8 scancode, u8 big);
