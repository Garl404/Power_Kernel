# Power Kernel

An x86-64 microkernel written from scratch in **pure NASM assembly** — no C, no
runtime, no external libraries, no linker. The whole kernel is a single
`src/kernel.asm` assembled into a flat Multiboot1 binary.

It targets **x86-64 bare metal** and is developed and tested inside QEMU. The
source builds and runs from **Windows, macOS, and Linux** with only NASM and
QEMU installed.

---

## Features

### Core (Phase 0)

- Multiboot1 boot entry with a full 32-bit → 64-bit long-mode switch
- 64-bit GDT, 256-entry IDT, PIC remap, PIT timer at ~100 Hz
- VGA text console + serial console (COM1)
- PS/2 keyboard driver and an interactive shell
- Preemptive round-robin scheduler with register context switching
- Message-passing IPC — `send` / `recv` / `reply` over per-task mailboxes
- System call interface via `int 0x80`

### Virtual memory (Phase 2)

- Higher-half kernel (relocated to the top 2 GiB of the address space)
- 4-level paging (PML4/PDPT/PD/PT) with 2 MiB huge pages
- Direct map of physical memory
- Per-address-space page tables and CR3 switching
- Demand paging (lazy allocation via the page-fault handler)
- Copy-on-write (`CR0.WP` + page copy + TLB invalidation)
- Buddy physical page allocator and slab kernel heap
- `mmap` / `munmap` / `mprotect`

### User mode & processes (Phase 3)

- Ring 3 user mode with a 64-bit TSS and privilege switching
- `fork` / `exec` / `exit` / `wait` process model
- Per-process address space (fork copies user pages, shares kernel mappings)
- ELF64 loader (parses the ELF header and loads `PT_LOAD` segments)
- Threads via `clone` (shared address space)
- Parent/child lifecycle: zombie reaping, orphan adoption (reparent), and
  user-page reclamation on exit

On boot you see the banner, self-test messages, and a `PowerKernel>` prompt.
Type `help` for the command list; `demo` spawns a ring-3 process that forks a
child.

---

## Requirements

- **NASM** — any recent version (2.16+ recommended)
- **QEMU** — `qemu-system-x86_64` for running/testing
- **GNU Make** — optional; `build.sh` / `build.bat` are provided

### Install

**Windows**
```
choco install nasm qemu
```

**macOS**
```
brew install nasm qemu
```

**Linux (Debian/Ubuntu)**
```
sudo apt install nasm qemu-system-x86
```

---

## Build

```
make
# or
./build.sh
# or
build.bat
```

Produces `build/kernel.bin` — a flat Multiboot1 binary (no linker required).

## Run

```
make run                 # QEMU with a graphics window
make run-nographic       # headless, serial console only
```

Or directly:

```
qemu-system-x86_64 -kernel build/kernel.bin
```

## Build a bootable ISO (optional)

Requires `grub-mkrescue` and `xorriso`.

```
make iso
```

---

## Shell commands

| command | description |
|---------|-------------|
| `help` | list commands |
| `about` / `version` | version and project info |
| `clear` / `cls` | clear the screen |
| `mem` | show free physical pages |
| `tasks` | list tasks (pid, state, parent, name) |
| `uptime` | ticks since boot |
| `cpu` | CPU vendor string |
| `echo <text>` | round-trip a message through the echo server over IPC |
| `demo` | spawn a ring-3 process that forks a child (process demo) |
| `reboot` | reboot the system |
| `halt` | halt the system |

---

## System calls (`int 0x80`)

Convention: `rax` = syscall number, `rdi` = arg1, `rsi` = arg2, `rdx` = arg3.
Return value in `rax`.

| # | name | args | returns |
|---|------|------|---------|
| 0 | `exit`   | rdi = status | — |
| 1 | `write`  | rdi = buf, rsi = len | 0 |
| 2 | `send`   | rdi = dest, rsi = msg | 0 / -1 |
| 3 | `recv`   | rdi = from (-1 any), rsi = buf | sender pid |
| 4 | `reply`  | rdi = dest, rsi = msg | 0 / -1 |
| 5 | `getpid` | — | pid |
| 6 | `sleep`  | rdi = ticks | 0 |
| 7 | `yield`  | — | 0 |
| 8 | `fork`   | — | child pid (parent) / 0 (child) |
| 9 | `wait`   | rdi = pid (-1 any), rsi = status ptr | child pid |
| 10 | `exec`  | — | 0 / -1 |
| 11 | `clone` | rdi = entry, rsi = stack | thread pid |

---

## Architecture

- **Boot** — Multiboot1 (`a.out` kludge) flat binary loaded at `0x100000`,
  kernel relocated to the higher half (`0xFFFFFFFF80000000`)
- **Paging** — 4-level tables with 2 MiB huge pages; direct map of physical
  memory at `0xFFFF800000000000`
- **Interrupts** — PIC remapped to `0x20`–`0x2F`; IRQ0 = timer, IRQ1 = keyboard,
  `int 0x80` = system calls (DPL 3 gate for user mode)
- **Scheduler** — fixed TCB array, per-task kernel stacks, timer-driven
  preemption; per-task CR3 (address space) loaded on switch
- **IPC** — each task has an 8-slot mailbox of 64-byte messages; `recv` blocks,
  `send` is non-blocking (drops when full)
- **Processes** — each process has its own PML4; `fork` copies user pages while
  sharing the kernel's identity/direct/high mappings; `exec` loads an ELF64
  image; `clone` shares the address space

## Project layout

```
Power Kernel/
├── src/kernel.asm          # the entire microkernel (single NASM source)
├── Makefile                # build / run / iso targets
├── build.sh                # macOS/Linux build script
├── build.bat               # Windows build script
├── iso/boot/grub/grub.cfg  # GRUB menu for the bootable ISO
├── LICENSE                 # MIT
├── README.md
└── README.zh-CN.md
```

## Limitations

- ELF64 programs are embedded in the kernel image (no filesystem / disk driver
  yet); the loader itself is generic
- `exec` does not yet set up argv/envp on the user stack
- `fork` copies pages eagerly (no copy-on-write for fork yet)
- On exit, user pages are reclaimed but page-table pages (PML4/PDPT/PD/PT) are
  still leaked
- PS/2 keyboard only (no USB HID)
- `send` drops messages when a mailbox is full

See [ROADMAP.md](ROADMAP.md) for the full plan from here to a C port.

---

## License

[MIT](LICENSE)
