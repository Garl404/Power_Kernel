# IPC 与 Shell

这一页讲 Power Kernel 的消息传递 IPC 和交互式 shell。

## 消息传递 IPC

微内核风格：任务之间通过**邮箱 + 消息**通信，而不是共享内存。

### 邮箱

每个任务（TCB）有一个邮箱：

- 8 个槽位，每条消息 64 字节
- `MAIL_FROM` 记录每条消息的发送者 pid
- `MAIL_HEAD` / `MAIL_TAIL` 做环形队列，`MAIL_COUNT` 计数

### 语义

| 原语 | 行为 |
|------|------|
| `send(dest, msg)` | 非阻塞；目标邮箱满时丢弃、返回 -1 |
| `recv(from, buf)` | 阻塞；没有消息时任务进入 `RECV` 状态 |
| `reply(dest, msg)` | 同 `send`，用于服务端应答 |

`recv` 阻塞时，任务状态置 `RECV` 并调用 `schedule()`；`send` 到某个正在 `RECV`
的任务时，会把它唤醒（置 `READY`）。

### 典型用法（echo 服务器）

shell 的 `echo <文本>` 命令演示了完整往返：

1. shell `send(echo_pid, 文本)`
2. echo 服务器 `recv` 拿到消息
3. echo 服务器 `reply(shell_pid, 文本)`
4. shell `recv` 拿到回显并打印

## Shell

shell 是内核里一个 ring-0 任务，从键盘收一行输入、解析命令、执行。

### 命令列表

| 命令 | 说明 |
|------|------|
| `help` | 列出命令 |
| `about` / `version` | 版本和项目信息 |
| `clear` / `cls` | 清屏 |
| `mem` | 显示空闲物理页数 |
| `tasks` | 列出任务（pid、状态、父进程、名称） |
| `uptime` | 开机以来的 tick 数 |
| `cpu` | CPU 厂商字符串（CPUID） |
| `echo <文本>` | 通过 echo 服务器走 IPC 回显 |
| `demo` | 启动一个 fork 子进程的 ring-3 进程演示 |
| `reboot` | 通过键盘控制器复位 |
| `halt` | 停机 |

### 输入处理

- PS/2 键盘 IRQ（IRQ1）把扫描码映射成 ASCII，回显到屏幕
- 支持退格（删除字符）
- 回车后把整行 `send` 给 shell 任务

### 命令解析

`process_command` 用 `strcmp` 精确匹配命令，`echo` 用 `starts_with` 匹配前缀
（`echo `），这样 `echo hello` 会把 `hello` 当作参数。

## 任务清单（开机）

| pid | 名称 | 角色 |
|-----|------|------|
| 0 | init | 创建 shell/echo 服务，然后空转 |
| 1 | shell | 交互式命令行 |
| 2 | echo | IPC 回显服务器 |

`demo` 命令会在 pid 3 临时创建一个 ring-3 进程。
