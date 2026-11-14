# 进程与线程

Power Kernel 的进程/线程模型建立在 ring 3 用户态和每进程地址空间之上。

## 特权级切换

- 64 位 TSS（`RSP0` 指向内核栈），GDT 里有用户代码/数据段（DPL 3）
- 进入 ring 3：`iretq` 到用户 CS/RIP/RFLAGS/RSP/SS
- 返回内核：用户态 `int 0x80`（DPL 3 门），CPU 切到 RSP0 后进入内核
- 每次调度把 TSS 的 RSP0 更新为**当前任务自己的内核栈顶**

## 每进程地址空间

每个任务有独立的 PML4（TCB 里的 `CR3` 字段），调度切换时 `mov cr3`。

- **共享**：恒等映射（[0,16MiB)，供 GDT/TSS）、直接映射、高半区内核
- **独立**：用户页（低半区）

### fork

`fork` 复制用户页、共享内核映射：

1. `vmm_new_space()` 建新 PML4（复制内核映射、独立 pdpt）
2. `fork_copy_space()` 遍历父进程用户页表：
   - 2 MiB 大页（恒等映射）→ 直接共享 PDPT 项
   - 4 KiB 用户页（U/S=1）→ 分配新物理页、复制内容、映射到子进程
3. 复制父进程的 syscall 栈帧，子进程的 `rax` 置 0（fork 返回 0）
4. 子进程通过 `isr_return` 蹦床恢复，从 syscall 返回点继续

### exec

`exec` 用新程序替换进程镜像：

1. 建新地址空间（共享内核映射 + 恒等映射）
2. `elf_load()` 解析 ELF 头、加载 `PT_LOAD` 段
3. 建新用户栈
4. 切换 CR3，改写当前 syscall 帧的 RIP/RSP → iretq 直接进 `e_entry`

### clone

`clone(entry, stack)` 创建**共享地址空间**的线程：

- TCB 的 `CR3` = 当前进程的 CR3（不复制页表）
- 构建全新的 ring-3 iretq 帧（RIP=entry、RSP=stack）
- 与 fork 的区别：fork 复制、clone 共享

## 生命周期

| 阶段 | 机制 |
|------|------|
| 创建 | fork（复制）/ clone（共享）/ exec（替换） |
| 退出 | `exit(status)` 存状态码、标记 DEAD（僵尸） |
| 等待 | `wait(pid, &status)` 阻塞到子进程退出，回收僵尸、读状态 |
| 孤儿收养 | 父进程先退出时，子进程的 `parent` 改为 0（init） |
| 回收 | 退出时释放用户页（`free_user_pages`） |

## TCB 关键字段

| 字段 | 含义 |
|------|------|
| `STATE` | FREE / READY / RUNNING / RECV / SLEEP / DEAD / WAIT |
| `PID` / `PARENT` | 进程号 / 父进程号 |
| `RSP` | 内核栈指针（上下文切换） |
| `CR3` | 地址空间（PML4 物理地址） |
| `EXIT_STATUS` | 退出状态码（wait 读取） |

## 演示

shell 里的 `demo` 命令会启动一个 ring-3 进程：父进程 fork 出子进程后立即退出，
子进程被孤儿收养到 init 名下。用 `tasks` 可看到子进程的 `parent` 列变成 0。
