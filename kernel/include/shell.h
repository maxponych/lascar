#include "fs.h"
#include "keyboard.h"
#include "layout.h"
#include "pit.h"
#include "print.h"
#include "string.h"
#include "types.h"

typedef void (*cmd_func)(char *args);

typedef struct {
  char *name;
  cmd_func func;
} Command;

extern u32 current_dir;

void cmd_parse(char *cmd_buff, u8 *buff_cnt);
void cmd_loadkeys(char *args);
void cmd_echo(char *args);
void cmd_cat(char *args);
void cmd_cd(char *args);
void cmd_ls(char *args);
void cmd_mkdir(char *args);
void cmd_rm(char *args);
void cmd_snake(char *args);
void cmd_clear(char *args);
