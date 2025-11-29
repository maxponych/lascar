#include "shell.h"

u32 current_dir = 0;

Command commands[] = {{"ls", cmd_ls},
                      {"cd", cmd_cd},
                      {"cat", cmd_cat},
                      {"echo", cmd_echo},
                      {"loadkeys", cmd_loadkeys},
                      {"mkdir", cmd_mkdir},
                      {"rm", cmd_rm},
                      {"clear", cmd_clear},
                      {NULL, NULL}};

void cmd_parse(char *cmd_buff, u8 *buff_cnt) {
  char *cmd = cmd_buff;
  char *args = 0;
  u8 is_args = 0;

  for (char *p = cmd_buff; *p; p++) {
    if (*p == ' ') {
      *p = '\0';
      args = p + 1;
      break;
    }
  }

  for (u32 i = 0; commands[i].name != NULL; i++) {
    if (str_cmp(commands[i].name, cmd) == 0) {
      commands[i].func(args);
      return;
    }
  }

  print("Unknown command: ");
  println(cmd);
}
