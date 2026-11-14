@echo off
setlocal

set NASM=nasm
set QEMU=qemu-system-x86_64

if not exist build mkdir build
%NASM% -f bin -w-zeroing -w-implicit-abs-deprecated -o build\kernel.bin src\kernel.asm
if errorlevel 1 exit /b 1
echo Built build\kernel.bin

if "%1"=="run" %QEMU% -kernel build\kernel.bin -serial stdio
if "%1"=="run-nographic" %QEMU% -kernel build\kernel.bin -nographic -no-reboot
