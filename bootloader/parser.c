#include "fs.h"
#include "print.h"
#include "types.h"

void fs_parser() {
  fs_init();
  DirEntry *kernel = fs_find_file("KERNEL  BIN", 0);
  if (kernel) {
    fs_read_file(kernel, (u8 *)0x20000);

    void (*kmain)() = (void (*)())0x20000;
    kmain();
  }

  print("Fail");
  for (;;)
    asm("hlt");
}
