ASM ?= nasm
QEMU ?= qemu-system-i386
BUILD_DIR ?= build
IMAGE_SIZE_SECTORS ?= 2880
KERNEL_LOAD_SECTORS ?= 64

BOOT_BIN := $(BUILD_DIR)/boot.bin
KERNEL_BIN := $(BUILD_DIR)/kernel.bin
OS_IMG := $(BUILD_DIR)/os.img

.PHONY: all run clean help

all: $(OS_IMG)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BOOT_BIN): boot.asm | $(BUILD_DIR)
	$(ASM) -f bin $< -o $@

$(KERNEL_BIN): kernel.asm | $(BUILD_DIR)
	$(ASM) -f bin $< -o $@
	@size=$$(wc -c < $@); max=$$(( $(KERNEL_LOAD_SECTORS) * 512 )); \\
	if [ "$$size" -gt "$$max" ]; then \\
		echo "ERROR: kernel.bin is $$size bytes; bootloader loads only $$max bytes."; \\
		exit 1; \\
	fi

$(OS_IMG): $(BOOT_BIN) $(KERNEL_BIN)
	dd if=/dev/zero of=$@ bs=512 count=$(IMAGE_SIZE_SECTORS) status=none
	dd if=$(BOOT_BIN) of=$@ conv=notrunc status=none
	dd if=$(KERNEL_BIN) of=$@ bs=512 seek=1 conv=notrunc status=none
	@echo "Built $@"

run: $(OS_IMG)
	$(QEMU) -drive format=raw,file=$(OS_IMG)

clean:
	rm -rf $(BUILD_DIR)

help:
	@echo "make       - assemble bootloader and kernel, create disk image"
	@echo "make run   - run image in QEMU"
	@echo "make clean - remove generated build files"
