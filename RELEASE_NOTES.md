# Power Kernel 发行说明

## v0.3.0 — 2026-10-18

Power Kernel 是一个从零开始、用**纯 NASM 汇编**写成的 x86-64 微内核：没有 C、
没有运行时、没有链接器，整个内核就是单个 `src/kernel.asm` 文件。

本次发行标志着**阶段 3「用户态与进程」的完成**。内核从此具备了真正的用户态、
进程、线程和 ELF64 程序加载能力——一个在 QEMU 里跑起来的、能用 shell 交互、
能在 ring 3 里 fork 出子进程的完整微内核。

---

## 里程碑回顾

本作品自启动以来，已走完三个大阶段：

| 阶段 | 主题 | 状态 |
|---|---|---|
| 阶段 0 | 基础内核 | ✅ |
| 阶段 2 | 虚拟内存 | ✅ |
| 阶段 3 | 用户态与进程 | ✅ 本次 |

**阶段 0 · 基础内核**——Multiboot1 启动、32→64 位长模式、GDT/IDT/PIC/PIT、
物理内存管理、抢占式调度器、消息传递 IPC、`int 0x80` 系统调用、VGA/串口、
PS/2 键盘、交互式 shell。

**阶段 2 · 虚拟内存**——内核高半区、4 级页表（2 MiB 大页）、物理内存直接映射、
按需分页、写时复制（COW）、buddy 物理页分配器、slab 内核堆、mmap/munmap/mprotect。

**阶段 3 · 用户态与进程**——ring 3 用户态、64 位 TSS 特权级切换、进程模型、
每进程地址空间、ELF64 加载器、线程、父子生命周期。

---

## 本次新增（v0.3.0）

### 进程模型（fork / exec / exit / wait）

- `fork` 创建子进程，**复制用户页、共享内核映射**（每进程独立 PML4，CR3 随调度切换）
- `exec` 替换进程镜像（新地址空间 + 新用户栈 + 跳转入口）
- `exit` 携带退出状态，子进程成为僵尸
- `wait` 阻塞等待子进程、回收僵尸、读取退出状态

### ELF64 加载器

- 解析 ELF 头（校验魔数、`e_entry`/`e_phoff`/`e_phnum`）
- 加载 `PT_LOAD` 段（按页分配、复制文件字节、`filesz < memsz` 自动补零）
- 跳转到 `e_entry` 进入用户程序

### 线程（clone）

- 共享地址空间的独立执行流
- 全新 ring-3 入口 + 用户栈

### 生命周期与父子关系

- 进程树（每任务记录父进程 pid）
- 孤儿收养：父进程先退出时，子进程自动挂到 init（pid 0）名下
- 退出时回收用户页

### 其它

- 新 shell 命令：`uptime` / `cpu` / `cls` / `reboot` / `demo`
- `demo` 命令：按需启动一个 fork 子进程的 ring-3 进程演示

---

## 系统调用一览（共 12 个）

`exit` · `write` · `send` · `recv` · `reply` · `getpid` · `sleep` · `yield` ·
`fork` · `wait` · `exec` · `clone`

约定：`rax` = 系统调用号，`rdi`/`rsi`/`rdx` = 参数，返回值在 `rax`。

完整参数表见 [README.zh-CN.md](README.zh-CN.md)。

---

## 如何运行

需要 NASM 和 QEMU：

```powershell
# Windows
.\build.bat run

# macOS / Linux
make run
```

启动后：

```
Power Kernel 0.3.0
x86_64 microkernel

[mem] physical memory manager ready
...
[init] system ready

PowerKernel>            ← 输入 help 查看命令，输入 demo 跑进程演示
```

---

## 已知问题

- ELF64 程序目前**内嵌在内核镜像**里（还没有文件系统/磁盘驱动）；加载器本身是通用的
- `exec` 尚未设置 argv/envp 用户栈布局
- `fork` 是整页复制（尚未对 fork 做写时复制）
- 退出时回收了用户页，但**页表页（PML4/PDPT/PD/PT）仍会泄漏**
- 仅支持 PS/2 键盘（无 USB HID）
- 邮箱满时 `send` 会丢弃消息

---

## 下一步

按 [ROADMAP.md](ROADMAP.md)，接下来是：

- **阶段 1 · 中断与异常体系**：完整异常处理、LAPIC/IOAPIC、`SYSCALL`/`SYSRET`
- **阶段 4 · 调度器**：多级反馈队列、优先级、时间片
- 或先补齐遗留优化：fork 的 COW、页表回收、argv/envp

---

## 许可证

[MIT](LICENSE)
