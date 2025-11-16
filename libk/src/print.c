#include "print.h"

u16 cursor = 0;

void update_hw_cursor() {
  outb(0x3D4, 0x0F);
  outb(0x3D5, (u8)(cursor & 0xFF));
  outb(0x3D4, 0x0E);
  outb(0x3D5, (u8)((cursor >> 8) & 0xFF));
}

void scroll_up() {
  volatile u16 *vga = (u16 *)0xB8000;

  for (int y = 1; y < 25; y++) {
    for (int x = 0; x < 80; x++) {
      vga[(y - 1) * 80 + x] = vga[y * 80 + x];
    }
  }

  for (int x = 0; x < 80; x++) {
    vga[(25 - 1) * 80 + x] = ' ' | (0x07 << 8);
  }
}

void clear_screen() {
  cursor = 0;
  volatile u16 *vga = (u16 *)0xB8000;
  u16 blank = (0x0F << 8) | ' ';

  for (int i = 0; i < 80 * 25; i++) {
    vga[i] = blank;
  }
  update_hw_cursor();
}

void printc(const char c) {
  volatile u16 *vga = (u16 *)0xB8000;
  int col = cursor % 80;
  int row = cursor / 80;
  switch (c) {
  case '\n':
    if ((cursor / 80) >= 25) {
      scroll_up();
      cursor -= 80;
    }
    cursor = ((cursor / 80) + 1) * 80;
    break;
  case '\r':
    cursor -= col;
    break;

  case '\t':
    cursor += 8 - (col % 8);
    break;

  case '\b':
    if (cursor > 0)
      cursor--;
    vga[cursor] = (u16)' ' | ((u16)0x07 << 8);
    break;

  default:
    vga[cursor++] = (u16)c | ((u16)0x07 << 8);
    break;
  }

  if ((cursor / 80) >= 25) {
    scroll_up();
    cursor -= 80;
  }

  update_hw_cursor();
}

void print(const char *str) {
  while (*str) {
    printc(*str);
    str++;
  }
}

void println(const char *str) {
  print(str);
  if ((cursor / 80) >= 25) {
    scroll_up();
    cursor -= 80;
  }
  cursor = ((cursor / 80) + 1) * 80;
  update_hw_cursor();
}

void printx(u8 val) {
  const char *hex = "0123456789ABCDEF";
  char str[3] = {hex[(val >> 4) & 0xF], hex[val & 0xF], '\0'};
  print(str);
}

void printxln(u8 val) {
  printx(val);
  if ((cursor / 80) >= 25) {
    scroll_up();
    cursor -= 80;
  }
  cursor = ((cursor / 80) + 1) * 80;
}

void printnum(u8 n) {
  char buf[4];
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
