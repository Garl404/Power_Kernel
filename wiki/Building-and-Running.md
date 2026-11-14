# 构建与运行

Power Kernel 的构建和运行只需要两个工具：**NASM**（汇编器）和 **QEMU**
（虚拟机）。

## 环境要求

| 工具 | 用途 | 说明 |
|------|------|------|
| NASM | 汇编器 | 任意较新版本（推荐 2.16+） |
| QEMU | 运行/测试 | `qemu-system-x86_64` |
| GNU Make | 可选 | 已提供 `build.sh` / `build.bat` |

### 安装

**Windows**
```
choco install nasm qemu
```

**macOS**
```
brew install nasm qemu
```

**Linux（Debian/Ubuntu）**
```
sudo apt install nasm qemu-system-x86
```

## 构建

```
make
# 或
./build.sh
# 或
build.bat
```

产物是 `build/kernel.bin` —— 一个**扁平的 Multiboot1 二进制**（`nasm -f bin`
直接生成，不需要链接器）。

构建命令等价于：

```
nasm -f bin -w-zeroing -w-implicit-abs-deprecated -o build/kernel.bin src/kernel.asm
```

## 运行

### 带图形窗口

```
make run
# 或
qemu-system-x86_64 -kernel build/kernel.bin
```

### 无图形（仅串口，干净输出）

```
make run-nographic
# 或
qemu-system-x86_64 -kernel build/kernel.bin -nographic
```

> 提示：在 Windows 上 QEMU 的 GTK 图形层偶尔会报 Pango 字体警告
> （`couldn't load font ... expect ugly output`），这只是 QEMU 缺字体的外观问题，
> 与内核无关。用 `-nographic` 或 `-display sdl` 可避开。

## 构建可启动 ISO（可选）

需要 `grub-mkrescue` 和 `xorriso`：

```
make iso
```

生成 `build/power-kernel.iso`，可写入 U 盘或用虚拟机直接挂载启动。

## 启动画面

```
Power Kernel 0.3.0
x86_64 microkernel

[mem] physical memory manager ready
[mm] buddy allocator test passed
[mm] slab allocator test passed
[vmm] address space test passed
[vmm] demand paging test passed
[vmm] copy-on-write test passed
[vmm] mmap/mprotect test passed
[sched] scheduler started

[init] system ready

PowerKernel>
```

开机那几行 `[mem]` / `[mm]` / `[vmm]` 是内核的**自检信息**（阶段 0/2 的正确性
自测），每次启动都会跑一遍。启动完成后在 `PowerKernel>` 提示符下输入 `help`
查看命令。

## 无图形模式下的交互

如果用了 `-nographic`，shell 的键盘输入和屏幕输出都走串口（COM1），终端里
直接打字即可。带图形窗口时，输入走 QEMU 窗口（PS/2 键盘），输出同时显示在
VGA 屏幕和串口上。
