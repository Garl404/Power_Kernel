# 架构总览

这一页概述 Power Kernel 的整体结构：启动流程、地址空间布局、中断、调度器。

## 地址空间布局

内核是 **higher-half**（高半区）设计，用户地址在低半区，内核在高半区。

| 常量 | 值 | 含义 |
|------|-----|------|
| `KERNEL_VMA` | `0xFFFFFFFF80000000` | 内核虚拟基址（-2 GiB） |
| `KERNEL_PMA` | `0x200000` | 内核物理加载地址（2 MiB） |
| `DIRECT_MAP_BASE` | `0xFFFF800000000000` | 物理内存直接映射基址 |

PML4 的三个关键项：

| PML4 项 | 指向 | 用途 |
|---------|------|------|
| `PML4[0]` | 恒等映射 + 用户页表 | 低 512 GiB（含 [0,16MiB) 恒等映射，供 GDT/TSS 用） |
| `PML4[256]` | 直接映射 | 把 [0,1GiB) 物理内存映射到 `DIRECT_MAP_BASE` |
| `PML4[511]` | 高半区内核 | 把内核映射到 `KERNEL_VMA` |

## 启动流程

1. **Multiboot1** 头（`a.out` kludge）声明加载地址 0x100000，`_start` 是 32 位入口
2. 校验 Multiboot magic、CPUID、长模式支持
3. 手工搭建 4 级页表（PML4/PDPT/PD），清空 7168 字节页表区
4. 设置 CR0/CR4/EFER，启用分页和长模式
5. 远跳转到高半区的 `long_mode_entry`
6. `kernel_main`：初始化 VGA → IDT → PIC → PIT → PMM → buddy → 各子系统自检 →
   调度器 → 进入 init 任务

## 中断与异常

- PIC 重映射到 `0x20`–`0x2F`
- IDT 256 项，`isr_stub_%i` 统一压入向量号/错误码后走 `isr_common`
- IRQ0 = 定时器（PIT ~100 Hz），IRQ1 = 键盘
- `int 0x80` = 系统调用，用户态用 DPL 3 门

中断上下文切换的栈帧（从高到低）：

```
iretq 帧（RIP/CS/RFLAGS/RSP/SS）  ← ring3→ring0 时才有 SS/RSP
错误码
向量号
15 个通用寄存器（r15 … rax）
```

## 调度器

- 固定 TCB 数组，`MAX_TASKS = 64`，每任务独立内核栈（4 KiB）
- 任务状态：`FREE` `READY` `RUNNING` `RECV` `SLEEP` `DEAD` `WAIT`
- 定时器驱动抢占；`schedule()` 用轮转法找下一个 `READY` 任务
- `switch_to` 保存/恢复 `rbx rbp r12 r13 r14 r15`（callee-saved）
- 每次切换同时更新 TSS 的 RSP0（每任务内核栈）和 CR3（每任务地址空间）

## 目录结构

```
src/kernel.asm          # 整个内核（单文件）
  ├─ .boot              # 低地址：Multiboot 头、32 位入口、GDT、TSS
  └─ .text              # 高地址：全部内核代码/数据
```

`.boot` 段在物理低地址（1 MiB），`.text` 段用 `vstart=KERNEL_VMA` 声明在虚拟高
半区，`org` + 段属性让同一个文件里混合了物理低地址和虚拟高地址代码。
