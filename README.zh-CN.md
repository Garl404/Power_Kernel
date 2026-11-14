# Power Kernel

一个从零开始、用**纯 NASM 汇编**编写的 x86-64 微内核——没有 C、没有运行时、
没有外部库、没有链接器。整个内核就是单个 `src/kernel.asm` 文件，汇编成一个
扁平的 Multiboot1 二进制。

它面向 **x86-64 裸机**，在 QEMU 中开发与测试。源码只需安装 NASM 和 QEMU，
即可在 **Windows、macOS、Linux** 上编译运行。

---

## 特性

### 核心（阶段 0）

- Multiboot1 启动，完整的 32 位 → 64 位长模式切换
- 64 位 GDT、256 项 IDT、PIC 重映射、约 100 Hz 的 PIT 定时器
- VGA 文本控制台 + 串口控制台（COM1）
- PS/2 键盘驱动和交互式 shell
- 抢占式轮转调度器（寄存器上下文切换）
- 消息传递 IPC——基于每任务邮箱的 `send` / `recv` / `reply`
- `int 0x80` 系统调用接口

### 虚拟内存（阶段 2）

- 内核高半区（重定位到地址空间顶部 2 GiB）
- 4 级页表（PML4/PDPT/PD/PT），2 MiB 大页
- 物理内存直接映射
- 每地址空间独立页表 + CR3 切换
- 按需分页（页错误处理程序里的惰性分配）
- 写时复制（`CR0.WP` + 页面复制 + TLB 失效）
- buddy 物理页分配器和 slab 内核堆
- `mmap` / `munmap` / `mprotect`

### 用户态与进程（阶段 3）

- ring 3 用户态，64 位 TSS 和特权级切换
- `fork` / `exec` / `exit` / `wait` 进程模型
- 每进程独立地址空间（fork 复制用户页、共享内核映射）
- ELF64 加载器（解析 ELF 头、加载 `PT_LOAD` 段）
- `clone` 线程（共享地址空间）
- 父子生命周期：僵尸回收、孤儿收养（reparent）、退出时回收用户页

启动后你会看到横幅、自检信息，然后是 `PowerKernel>` 提示符。输入 `help`
查看命令列表；输入 `demo` 会启动一个 fork 子进程的 ring-3 进程。

---

## 环境要求

- **NASM**——任意较新版本（推荐 2.16+）
- **QEMU**——用于运行/测试（`qemu-system-x86_64`）
- **GNU Make**——可选；已提供 `build.sh` / `build.bat`

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

---

## 构建

```
make
# 或
./build.sh
# 或
build.bat
```

生成 `build/kernel.bin`——扁平的 Multiboot1 二进制（无需链接器）。

## 运行

```
make run                 # QEMU 带图形窗口
make run-nographic       # 无图形，仅串口控制台
```

或直接：

```
qemu-system-x86_64 -kernel build/kernel.bin
```

## 构建可启动 ISO（可选）

需要 `grub-mkrescue` 和 `xorriso`。

```
make iso
```

---

## Shell 命令

| 命令 | 说明 |
|------|------|
| `help` | 列出命令 |
| `about` / `version` | 版本和项目信息 |
| `clear` / `cls` | 清屏 |
| `mem` | 显示空闲物理页数 |
| `tasks` | 列出任务（pid、状态、父进程、名称） |
| `uptime` | 开机以来的 tick 数 |
| `cpu` | CPU 厂商字符串 |
| `echo <文本>` | 通过 echo 服务器走 IPC 回显一条消息 |
| `demo` | 启动一个 fork 子进程的 ring-3 进程（进程演示） |
| `reboot` | 重启系统 |
| `halt` | 停机 |

---

## 系统调用（`int 0x80`）

约定：`rax` = 系统调用号，`rdi` = 参数 1，`rsi` = 参数 2，`rdx` = 参数 3。
返回值在 `rax`。

| # | 名称 | 参数 | 返回值 |
|---|------|------|--------|
| 0 | `exit`   | rdi = 状态码 | — |
| 1 | `write`  | rdi = 缓冲区, rsi = 长度 | 0 |
| 2 | `send`   | rdi = 目标, rsi = 消息 | 0 / -1 |
| 3 | `recv`   | rdi = 来源（-1 任意）, rsi = 缓冲区 | 发送者 pid |
| 4 | `reply`  | rdi = 目标, rsi = 消息 | 0 / -1 |
| 5 | `getpid` | — | pid |
| 6 | `sleep`  | rdi = tick 数 | 0 |
| 7 | `yield`  | — | 0 |
| 8 | `fork`   | — | 子进程 pid（父）/ 0（子） |
| 9 | `wait`   | rdi = pid（-1 任意）, rsi = 状态指针 | 子进程 pid |
| 10 | `exec`  | — | 0 / -1 |
| 11 | `clone` | rdi = 入口, rsi = 栈 | 线程 pid |

---

## 架构

- **启动**——Multiboot1（`a.out` kludge）扁平二进制，加载到 `0x100000`，
  内核重定位到高半区（`0xFFFFFFFF80000000`）
- **分页**——4 级页表 + 2 MiB 大页；物理内存直接映射在 `0xFFFF800000000000`
- **中断**——PIC 重映射到 `0x20`–`0x2F`；IRQ0 = 定时器，IRQ1 = 键盘，
  `int 0x80` = 系统调用（用户态用 DPL 3 门）
- **调度器**——固定 TCB 数组、每任务内核栈、定时器驱动抢占；切换时加载
  每任务的 CR3（地址空间）
- **IPC**——每任务一个 8 槽、64 字节消息的邮箱；`recv` 阻塞，`send` 非阻塞
  （满时丢弃）
- **进程**——每个进程有独立 PML4；`fork` 复制用户页并共享内核的恒等/直接/
  高半区映射；`exec` 加载 ELF64 镜像；`clone` 共享地址空间

## 项目结构

```
Power Kernel/
├── src/kernel.asm          # 整个微内核（单个 NASM 源文件）
├── Makefile                # build / run / iso 目标
├── build.sh                # macOS/Linux 构建脚本
├── build.bat               # Windows 构建脚本
├── iso/boot/grub/grub.cfg  # 可启动 ISO 的 GRUB 菜单
├── LICENSE                 # MIT
├── README.md
└── README.zh-CN.md
```

## 已知局限

- ELF64 程序目前内嵌在内核镜像里（还没有文件系统/磁盘驱动）；加载器本身是通用的
- `exec` 尚未在用户栈上设置 argv/envp
- `fork` 是整页复制（尚未对 fork 做写时复制）
- 退出时回收了用户页，但页表页（PML4/PDPT/PD/PT）仍会泄漏
- 仅支持 PS/2 键盘（无 USB HID）
- 邮箱满时 `send` 会丢弃消息

完整路线（直到移植到 C）见 [ROADMAP.md](ROADMAP.md)。

---

## 许可证

[MIT](LICENSE)
