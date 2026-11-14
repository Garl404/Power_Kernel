# 系统调用

Power Kernel 通过 `int 0x80` 提供系统调用，共 12 个。

## 约定

- `rax` = 系统调用号
- `rdi` = 参数 1，`rsi` = 参数 2，`rdx` = 参数 3
- 返回值在 `rax`（负数表示失败）

## 完整表

| # | 名称 | 参数 | 返回值 |
|---|------|------|--------|
| 0 | `exit` | `rdi` = 状态码 | — |
| 1 | `write` | `rdi` = 缓冲区, `rsi` = 长度 | 0 |
| 2 | `send` | `rdi` = 目标 pid, `rsi` = 消息 | 0 / -1 |
| 3 | `recv` | `rdi` = 来源 pid（-1 任意）, `rsi` = 缓冲区 | 发送者 pid |
| 4 | `reply` | `rdi` = 目标 pid, `rsi` = 消息 | 0 / -1 |
| 5 | `getpid` | — | 当前 pid |
| 6 | `sleep` | `rdi` = tick 数 | 0 |
| 7 | `yield` | — | 0 |
| 8 | `fork` | — | 子进程 pid（父）/ 0（子） |
| 9 | `wait` | `rdi` = pid（-1 任意）, `rsi` = 状态指针 | 子进程 pid |
| 10 | `exec` | — | 0 / -1 |
| 11 | `clone` | `rdi` = 入口, `rsi` = 栈 | 线程 pid |

## 说明

### 进程相关（8–11）

- **`fork`** 复制地址空间、创建子进程；父进程返回子进程 pid，子进程返回 0
- **`wait`** 阻塞到匹配 pid 的子进程退出，回收僵尸，并把退出状态写到 `rsi` 指向的地址
- **`exec`** 加载内嵌的 ELF64 程序、替换当前进程镜像（尚未支持 argv/envp）
- **`clone`** 创建共享地址空间的线程，从 `entry` 开始跑，用 `stack` 作用户栈

### 消息相关（2–4）

- **`send`** 非阻塞，目标邮箱满时丢弃并返回 -1
- **`recv`** 阻塞，直到有消息；`rdi = -1` 表示任意来源
- **`reply`** 是 `send` 的别名（用于 IPC 应答语义）

### 其它

- **`write`** 直接把 `len` 字节写到 VGA + 串口（内核态调试/演示用）
- **`sleep`** 睡眠 `rdi` 个 tick（PIT 100 Hz，1 tick ≈ 10 ms）
- **`yield`** 主动让出 CPU

## 调用示例（ring 3）

```asm
; 打印 "hi\n" 然后退出
mov rax, 1          ; SYS_WRITE
mov rdi, msg        ; 缓冲区
mov rsi, 3          ; 长度
int 0x80

mov rax, 0          ; SYS_EXIT
mov rdi, 0          ; 状态码
int 0x80
```

## 实现位置

`syscall_handler`（`src/kernel.asm`）里用一串 `cmp rax, SYS_xxx` 分发到 `.xxx`
标签；参数从 syscall 栈帧里取（`r10 = [rbp+72]` = rdi，`r11 = [rbp+80]` = rsi，
`r12 = [rbp+88]` = rdx），返回值写回 `[rbp+112]`（rax 槽）。
