#include "kernel.h"
#include "print.h"

void kmain(VBE *vbe) {
  fs_init();
  kb_init();
  init_screen(vbe);
  clear_screen();
  println("Welcome back to laskar");
  char comm_buff[80];
  u8 comm_buff_cnt = 0;
  print("$> ");
  while (1) {
    u8 in = kb_read();
    u8 c = translate(in);
    if (c > 0) {
      if (c == '\n') {
        printc(c);
        comm_buff[comm_buff_cnt] = '\0';

        cmd_parse(comm_buff, &comm_buff_cnt);

        for (u8 i = 79; i > 0; i++) {
          comm_buff[i] = 0;
        }

        comm_buff_cnt = 0;
        print("$> ");
        continue;
      }
      if (c == '\b') {
        if (comm_buff_cnt > 0) {
          comm_buff[comm_buff_cnt--] = 0;
          printc(c);
        }
        continue;
      }
      if (comm_buff_cnt < 80) {
        comm_buff[comm_buff_cnt++] = c;
        printc(c);
      }
    }
  }
}
