NASM ?= nasm
QEMU ?= qemu-system-x86_64
GRUB_MKRESCUE ?= grub-mkrescue

BUILD_DIR := build
KERNEL := $(BUILD_DIR)/kernel.bin
SRC := src/kernel.asm
ISO := $(BUILD_DIR)/power-kernel.iso

.PHONY: all build run run-nographic iso clean

all: build

NASMFLAGS := -w-zeroing -w-implicit-abs-deprecated

build:
	mkdir -p $(BUILD_DIR)
	$(NASM) -f bin $(NASMFLAGS) -o $(KERNEL) $(SRC)
	@echo "Built $(KERNEL)"

run: build
	$(QEMU) -kernel $(KERNEL) -serial stdio

run-nographic: build
	$(QEMU) -kernel $(KERNEL) -nographic -no-reboot

iso: build
	mkdir -p iso/boot/grub
	cp $(KERNEL) iso/boot/kernel.bin
	$(GRUB_MKRESCUE) -o $(ISO) iso/
	@echo "Built $(ISO)"

clean:
	rm -rf $(BUILD_DIR)
	rm -f iso/boot/kernel.bin
