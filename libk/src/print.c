#include "print.h"
#include "font.h"

static VBE *vbe = NULL;
static u32 fg = 0x00FFFFFF;
static u32 bg = 0x00000000;
static u64 pos_x = 0;
static u64 pos_y = 0;

void init_screen(VBE *pointer) {
  vbe = pointer;
  pos_x = 0;
  pos_y = 0;
}

void clear_screen() {
  for (u64 i = 0; i < vbe->height * vbe->width; i++) {
    vbe->framebuffer[i] = bg;
  }

  pos_x = 0;
  pos_y = 0;
}

void put_pixel(const VBE *vbe, u64 x, u64 y, u32 color) {
  if (x >= vbe->width || y >= vbe->height)
    return;
  vbe->framebuffer[y * vbe->pitch + x] = color;
}

void print_char(char c) {
  if (c > 127)
    c = '?';

  const u8 *glyph = font8x8[c];
  u64 screen_x = pos_x * 8;
  u64 screen_y = pos_y * 8;

  for (u64 row = 0; row < 8; row++) {
    for (u64 col = 0; col < 8; col++) {
      u32 color = (glyph[row] & (1 << col)) ? fg : bg;
      put_pixel(vbe, screen_x + col, screen_y + row, color);
    }
  }
}

static void scroll_up() {
  u64 lines_to_move = (vbe->height / 8) - 1;

  for (u64 y = 0; y < lines_to_move * 8; y++) {
    for (u64 x = 0; x < vbe->width; x++) {
      u32 pixel = vbe->framebuffer[(y + 8) * vbe->pitch + x];
      vbe->framebuffer[y * vbe->pitch + x] = pixel;
    }
  }

  for (u64 y = lines_to_move * 8; y < vbe->height; y++) {
    for (u64 x = 0; x < vbe->width; x++) {
      vbe->framebuffer[y * vbe->pitch + x] = bg;
    }
  }
}

void printc(char c) {
  u64 max_cols = vbe->width / 8;
  u64 max_rows = vbe->height / 8;

  switch (c) {
  case '\n':
    pos_x = 0;
    pos_y++;
    break;
  case '\r':
    pos_x = 0;
    break;
  case '\t':
    pos_x += 4 - (pos_x % 4);
    break;
  case '\b':
    if (pos_x > 0) {
      pos_x--;
      print_char(' ');
    }
    break;
  default:
    print_char(c);
    pos_x++;
    break;
  }

  if (pos_x >= max_cols) {
    pos_x = 0;
    pos_y++;
  }

  if (pos_y >= max_rows) {
    scroll_up();
    pos_y = max_rows - 1;
  }
}

void print(const char *str) {
  while (*str) {
    printc(*str);
    str++;
  }
}

void println(const char *str) {
  print(str);
  printc('\n');
}

void printx(u8 val) {
  const char *hex = "0123456789ABCDEF";
  printc(hex[(val >> 4) & 0xF]);
  printc(hex[val & 0xF]);
}

void printxln(u8 val) {
  printx(val);
  printc('\n');
}

void printnum(u64 n) {
  char buf[21];
  int i = 0;

  if (n == 0) {
    printc('0');
    return;
  }

  while (n > 0) {
    buf[i++] = '0' + (n % 10);
    n /= 10;
  }

  for (int j = i - 1; j >= 0; j--) {
    printc(buf[j]);
  }
}
