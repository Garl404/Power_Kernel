#!/bin/sh
set -e

NASM="${NASM:-nasm}"
QEMU="${QEMU:-qemu-system-x86_64}"

mkdir -p build
"$NASM" -f bin -w-zeroing -w-implicit-abs-deprecated -o build/kernel.bin src/kernel.asm
echo "Built build/kernel.bin"

if [ "$1" = "run" ]; then
    "$QEMU" -kernel build/kernel.bin -serial stdio
elif [ "$1" = "run-nographic" ]; then
    "$QEMU" -kernel build/kernel.bin -nographic -no-reboot
fi
