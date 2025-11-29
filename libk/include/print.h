#pragma once

#include "io.h"
#include "types.h"

void init_screen(VBE *vbe);
void clear_screen();
void printc(const char c);
void print(const char *str);
void println(const char *str);
void printx(u8 val);
void printxln(u8 val);
void printnum(u64 n);
