# === Tools ===
NASM       := nasm
GCC        := gcc
LD         := ld
AR         := ar
OBJCOPY    := objcopy
DD         := dd
MKFS       := mkfs.fat         # from dosfstools
MCOPY      := mcopy            # from mtools
CARGO      := cargo
MKDIR      := mkdir -p
RM         := rm -f

# If you want to use release build for the bootloader set BUILD=release
BUILD      ?= release

# Path to OVMF (change if different on your distro)
OVMF_CODE = /nix/store/p0aqkqk7ivc6z0anf3bxqg01zzbapv5g-qemu-9.2.4/share/qemu/edk2-x86_64-code.fd

# === Directories ===
BOOT_DIR        := bootloader
KERNEL_SRC_DIR  := kernel/src
KERNEL_INC_DIR  := kernel/include
LIBK_SRC_DIR    := libk/src
LIBK_INC_DIR    := libk/include
DRIVERS_SRC_DIR := drivers/src
DRIVERS_INC_DIR := drivers/include
OUT_DIR         := out

# === Source files ===
KERNEL_SRC  := $(shell find $(KERNEL_SRC_DIR) -name '*.c')
LIBK_SRC    := $(wildcard $(LIBK_SRC_DIR)/*.c)
DRIVERS_SRC := $(wildcard $(DRIVERS_SRC_DIR)/*.c)

KERNEL_OBJ  := $(patsubst %.c,%.o,$(KERNEL_SRC))
LIBK_OBJ    := $(patsubst %.c,%.o,$(LIBK_SRC))
DRIVERS_OBJ := $(patsubst %.c,%.o,$(DRIVERS_SRC))

LIBK        := libk.a

# Kernel artifacts
KERNEL_ELF  := kernel.elf
KERNEL_BIN  := kernel.bin

# Bootloader EFI (produced by cargo)
BOOT_EFI    := $(BOOT_DIR)/target/x86_64-unknown-uefi/$(BUILD)/bootloader.efi

# Image
IMG         := os-uefi.img
IMG_SIZE_MB := 64
SECTOR_SIZE := 512

# === Build Flags ===
COMMON_FLAGS := -ffreestanding -m64 -mno-red-zone \
                -fno-stack-protector -fno-builtin -fno-pie -fno-pic \
                -fno-omit-frame-pointer -O2 -c

CFLAGS := $(COMMON_FLAGS) -I$(KERNEL_INC_DIR) -I$(LIBK_INC_DIR) -I$(DRIVERS_INC_DIR)

# === Rules ===
.PHONY: all clean start rebuild build-bootloader image mount-info

all: $(IMG)

# --- Build bootloader (Rust, target x86_64-unknown-uefi) ---
# This will build the cargo crate in bootloader/.
build-bootloader:
	@echo ">>> Building bootloader (cargo target: x86_64-unknown-uefi, profile: $(BUILD))"
	$(CARGO) build --manifest-path $(BOOT_DIR)/Cargo.toml --target x86_64-unknown-uefi --profile $(BUILD)

# --- C compilation rules ---
%.o: %.c
	$(GCC) $(CFLAGS) $< -o $@

$(LIBK): $(LIBK_OBJ) $(DRIVERS_OBJ)
	$(AR) rcs $@ $^

# --- Kernel link ---
$(KERNEL_ELF): $(KERNEL_OBJ) $(LIBK)
	$(LD) -T kernel.ld -o $@ $(KERNEL_OBJ) $(LIBK)

$(KERNEL_BIN): $(KERNEL_ELF)
	$(OBJCOPY) -O binary $< $@

# --- Image creation ---
# Creates a FAT image and writes the UEFI bootloader to EFI/BOOT/BOOTX64.EFI
$(IMG): build-bootloader $(KERNEL_BIN)
	@echo ">>> Creating $(IMG) (size $(IMG_SIZE_MB)MB)"
	$(RM) $(IMG)
	$(DD) if=/dev/zero of=$(IMG) bs=1M count=$(IMG_SIZE_MB) status=none
	$(MKFS) -F 32 $(IMG)
	# create the EFI dir tree and copy files using mtools (no mount needed)
	# ensure mtools config uses "mtools_skip_check=1" or run as user with perms if needed.
	# create directories
	mmd -i $(IMG) ::/EFI
	mmd -i $(IMG) ::/EFI/BOOT
	# copy the bootloader .efi into place
	$(MCOPY) -i $(IMG) $(BOOT_EFI) ::/EFI/BOOT/BOOTX64.EFI
	# put kernel image at root (kernel.bin)
	$(MCOPY) -i $(IMG) $(KERNEL_BIN) ::

	@echo ">>> Image $(IMG) ready. EFI/BOOT/BOOTX64.EFI = $(BOOT_EFI)"

# --- Run in QEMU (OVMF required) ---
start: $(IMG)
ifneq ($(wildcard $(OVMF_CODE)),)
	@echo ">>> Starting QEMU with OVMF at $(OVMF_CODE)"
	qemu-system-x86_64 -m 2G -drive if=pflash,format=raw,readonly=on,file=$(OVMF_CODE) -drive file=$(IMG),format=raw -net none
else
	@echo "OVMF firmware not found at $(OVMF_CODE). Please set OVMF_CODE to your OVMF_CODE.fd path."
	@echo "You can still try: qemu-system-x86_64 -bios /usr/share/ovmf/OVMF_CODE.fd -drive file=$(IMG),format=raw"
endif

# --- Utilities ---
rebuild: clean all

mount-info:
	@echo "Image: $(IMG)"
	@echo "EFI file expected at: EFI/BOOT/BOOTX64.EFI (from $(BOOT_EFI))"
	@echo "To mount manually (as root):"
	@echo "  sudo losetup --show -f $(IMG)    # get loop device"
	@echo "  sudo partprobe /dev/loopX"
	@echo "  sudo mount -o loop $(IMG) /mnt"

clean:
	$(RM) $(IMG) $(KERNEL_BIN) $(KERNEL_ELF) $(LIBK) $(LIBK_OBJ) $(KERNEL_OBJ) $(DRIVERS_OBJ)
	# Don't wipe cargo artifacts; if you want, run 'cargo clean' in bootloader/
	@echo "cleaned C artifacts and image. To remove Rust artifacts run: (cd $(BOOT_DIR) && cargo clean)"

# convenience: build C parts and libk then bootloader
c-only: $(KERNEL_BIN)

# ensure libk is built when C files changed
$(KERNEL_BIN): $(LIBK)

