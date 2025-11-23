# === Tools ===
NASM       = nasm
GCC        = gcc
LD         = ld
AR         = ar
OBJCOPY    = objcopy
DD         = dd
VBX        = VBoxManage
MKFS       = mkfs.fat
MCOPY      = mcopy

# === Directories ===
BOOT_DIR        = bootloader
KERNEL_SRC_DIR  = kernel/src
KERNEL_INC_DIR  = kernel/include
LIBK_SRC_DIR    = libk/src
LIBK_INC_DIR    = libk/include
DRIVERS_SRC_DIR = drivers/src
DRIVERS_INC_DIR = drivers/include

# === Source files ===
STAGE1 = $(BOOT_DIR)/stage1.asm
STAGE2 = $(BOOT_DIR)/stage2.asm
PARSER_SRC = $(BOOT_DIR)/parser.c

KERNEL_SRC  = $(shell find $(KERNEL_SRC_DIR) -name '*.c')
LIBK_SRC    = $(wildcard $(LIBK_SRC_DIR)/*.c)
DRIVERS_SRC = $(wildcard $(DRIVERS_SRC_DIR)/*.c)

KERNEL_OBJ  = $(KERNEL_SRC:.c=.o)
LIBK_OBJ    = $(LIBK_SRC:.c=.o)
DRIVERS_OBJ = $(DRIVERS_SRC:.c=.o)

LIBK        = libk.a

STAGE1_BIN  = $(BOOT_DIR)/stage1.bin
STAGE2_BIN  = $(BOOT_DIR)/stage2.bin
PARSER_ELF  = $(BOOT_DIR)/parser.elf
PARSER_BIN  = $(BOOT_DIR)/parser.bin
KERNEL_ELF  = kernel.elf
KERNEL_BIN  = kernel.bin
IMG         = os.img

# === Build Flags ===
SECTOR_SIZE = 512
BOOT_START_SECTOR = 7

COMMON_FLAGS = -ffreestanding -m64 -mno-red-zone \
               -fno-stack-protector -fno-builtin -fno-pie -fno-pic \
               -fno-omit-frame-pointer -O2 -c

CFLAGS = $(COMMON_FLAGS) -I$(KERNEL_INC_DIR) -I$(LIBK_INC_DIR) -I$(DRIVERS_INC_DIR)
PARSER_CFLAGS = $(COMMON_FLAGS) -I$(LIBK_INC_DIR) -I$(DRIVERS_INC_DIR)

# === Rules ===
all: $(IMG)

# --- Bootloader ---
$(STAGE1_BIN): $(STAGE1)
	$(NASM) -f bin $< -o $@

$(STAGE2_BIN): $(STAGE2)
	$(NASM) -f bin $< -o $@

# --- Libraries ---
%.o: %.c
	$(GCC) $(CFLAGS) $< -o $@

$(LIBK): $(LIBK_OBJ) $(DRIVERS_OBJ)
	$(AR) rcs $@ $^

# --- Parser ---
$(BOOT_DIR)/parser.o: $(PARSER_SRC) $(LIBK)
	$(GCC) $(PARSER_CFLAGS) $< -o $@

$(PARSER_ELF): $(BOOT_DIR)/parser.o $(LIBK)
	$(LD) -m elf_x86_64 -T $(BOOT_DIR)/parser.ld -o $@ $(BOOT_DIR)/parser.o $(LIBK)

$(PARSER_BIN): $(PARSER_ELF)
	$(OBJCOPY) -O binary $< $@

# --- Kernel ---
$(KERNEL_ELF): $(KERNEL_OBJ) $(LIBK)
	$(LD) -T kernel.ld -o $@ $(KERNEL_OBJ) $(LIBK)

$(KERNEL_BIN): $(KERNEL_ELF)
	$(OBJCOPY) -O binary $< $@

# --- Disk image ---
STAGE2_SIZE     = $(shell stat -c%s $(STAGE2_BIN) 2>/dev/null || echo 0)
STAGE2_SECTORS  = $(shell expr $$(( ( $(STAGE2_SIZE) + $(SECTOR_SIZE) - 1 ) / $(SECTOR_SIZE) )) )
PARSER_SIZE     = $(shell stat -c%s $(PARSER_BIN) 2>/dev/null || echo 0)
PARSER_SECTORS  = $(shell expr $$(( ( $(PARSER_SIZE) + $(SECTOR_SIZE) - 1 ) / $(SECTOR_SIZE) )) )
RESERVED_SECTORS = $(shell expr $$(( $(BOOT_START_SECTOR) + $(STAGE2_SECTORS) + $(PARSER_SECTORS) )) )

$(IMG): $(STAGE1_BIN) $(STAGE2_BIN) $(PARSER_BIN) $(KERNEL_BIN)
	$(DD) if=/dev/zero of=$(IMG) bs=1M count=256
	$(MKFS) -F 32 -R $(RESERVED_SECTORS) $(IMG)
	$(DD) if=$(IMG) of=$(BOOT_DIR)/bpb.bin bs=1 skip=11 count=79 conv=notrunc
	cp $(STAGE1_BIN) $(BOOT_DIR)/stage1_patched.bin
	$(DD) if=$(BOOT_DIR)/bpb.bin of=$(BOOT_DIR)/stage1_patched.bin bs=1 seek=11 count=79 conv=notrunc
	$(DD) if=$(BOOT_DIR)/stage1_patched.bin of=$(IMG) bs=$(SECTOR_SIZE) count=1 conv=notrunc
	$(DD) if=$(STAGE2_BIN) of=$(IMG) bs=$(SECTOR_SIZE) seek=$(BOOT_START_SECTOR) conv=notrunc
	$(DD) if=$(PARSER_BIN) of=$(IMG) bs=$(SECTOR_SIZE) seek=$$(( $(BOOT_START_SECTOR) + $(STAGE2_SECTORS) )) conv=notrunc
	$(DD) if=$(IMG) bs=$(SECTOR_SIZE) count=1 of=$(IMG) seek=6 conv=notrunc
	$(MCOPY) -i $(IMG) $(KERNEL_BIN) ::kernel.bin

start: ${IMG}
	qemu-system-x86_64 -m 2G -drive file=${IMG},format=raw -vga std

# --- Utility ---
sectors: $(STAGE1_BIN) $(STAGE2_BIN) $(PARSER_BIN) $(KERNEL_BIN)
	@for f in $(STAGE1_BIN) $(STAGE2_BIN) $(PARSER_BIN) $(KERNEL_BIN); do \
		if [ -f "$$f" ]; then \
			SIZE=$$(stat -c%s "$$f"); \
			SECTORS=$$(( ($$SIZE + $(SECTOR_SIZE) - 1) / $(SECTOR_SIZE) )); \
			echo "$$f: $$SIZE bytes, $$SECTORS sectors"; \
		else \
			echo "$$f: file not found"; \
		fi \
	done
	@echo "Reserved sectors: $(RESERVED_SECTORS)"

clean:
	rm -f *.bin *.elf $(IMG) $(LIBK) \
	$(LIBK_SRC_DIR)/*.o $(KERNEL_SRC_DIR)/**/*.o $(KERNEL_SRC_DIR)/*.o \
	$(DRIVERS_SRC_DIR)/*.o $(BOOT_DIR)/*.bin $(BOOT_DIR)/*.elf $(BOOT_DIR)/*.o $(BOOT_DIR)/bpb.bin $(BOOT_DIR)/stage1_patched.bin

compile_commands:
	command -v bear >/dev/null && (echo ">>> Generating compile_commands.json with bear"; bear -- make -B all) \
	|| (echo ">>> Bear not found, skipping"; exit 1)

