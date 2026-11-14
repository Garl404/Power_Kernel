# Power Kernel Wiki

欢迎来到 **Power Kernel** 的 wiki。Power Kernel 是一个从零开始、用**纯 NASM 汇编**
写成的 x86-64 微内核：没有 C、没有运行时、没有链接器，整个内核就是单个
`src/kernel.asm` 文件。

## 这是什么

一个面向 x86-64 裸机、在 QEMU 里运行的微内核。它拥有：

- 抢占式多任务 + 消息传递 IPC
- 完整的虚拟内存（高半区、4 级分页、按需分页、写时复制、buddy/slab、mmap）
- 真正的用户态（ring 3）+ 进程/线程模型（fork/exec/exit/wait/clone）
- ELF64 程序加载器

## 目录

| 页面 | 内容 |
|------|------|
| [[Building-and-Running]] | 安装、编译、QEMU 启动 |
| [[Architecture]] | 启动、分页、中断、调度器 |
| [[Memory-Management]] | 物理内存、虚拟内存、分配器 |
| [[Processes-and-Threads]] | fork/exec/exit/wait/clone、地址空间、生命周期 |
| [[System-Calls]] | 12 个系统调用的完整参考 |
| [[IPC-and-Shell]] | 消息传递、shell 命令 |
| [[Roadmap]] | 12 个阶段的完整路线 |

## 快速开始

```powershell
# Windows
.\build.bat run

# macOS / Linux
make run
```

启动后看到 `PowerKernel>` 提示符，输入 `help` 查看命令，输入 `demo` 跑进程演示。

## 当前状态

| 阶段 | 主题 | 状态 |
|---|---|---|
| 阶段 0 | 基础内核 | ✅ |
| 阶段 2 | 虚拟内存 | ✅ |
| 阶段 3 | 用户态与进程 | ✅ |
| 阶段 1 | 中断与异常体系 | ⬜ |
| 阶段 4 | 调度器 | ⬜ |

## 更多

- 项目介绍：仓库根目录 `README.zh-CN.md`
- 发行说明：仓库根目录 `RELEASE_NOTES.md`
- 变更日志：仓库根目录 `CHANGELOG.md`
