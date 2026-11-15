# Changelog

All notable changes to Power Kernel are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2026-11-15

### Changed

- Boot self-tests now print a single summary line instead of six separate lines

### Removed

- Local wiki pages (`wiki/`) and the wiki preview server (`wiki_server.py`)

## [0.3.0] - 2026-10-18

### Added

- User-mode (ring 3) task support: 64-bit TSS with RSP0, user code/data GDT descriptors
- Ring 3 → ring 0 → ring 3 transition via a DPL-3 `int 0x80` gate
- Process model: `fork` / `exit` / `wait` with parent-child tracking, exit status, and zombie reaping
- Per-process address space: each process gets its own PML4 and CR3; `fork` copies user pages while sharing the kernel's identity/direct/high mappings
- `exec`: replaces a process image with a new program (fresh address space, new user stack, jump to entry)
- ELF64 loader: parses the ELF header and loads PT_LOAD segments into a fresh address space
- `clone`: spawns a thread that shares the caller's address space and runs a ring-3 entry point on a fresh user stack
- Reparent on exit: orphaned children are adopted by init; exiting processes free their user pages
- New shell commands: `uptime`, `cpu`, `reboot`, `cls`

### Fixed

- `kprint_hex` always printed zero for non-zero values (rotating register `rdx` was clobbered by `kputc`)
- User page-table walk was supervisor-only, blocking ring-3 access (now sets the user bit on intermediate tables)
- Per-task kernel stack (RSP0) so a forked child's syscall no longer corrupts its parent's saved context

## [0.2.0] - 2026-10-18

### Added

- Higher-half kernel (relocated to -2 GiB virtual, loaded at 2 MiB physical)
- 4-level page tables (PML4/PDPT/PD/PT) with 2 MiB huge pages
- Direct map of physical memory (1 GiB → 0xFFFF800000000000)
- Virtual memory manager: map / unmap / new address space / CR3 switch
- Demand paging (lazy allocation via page-fault handler)
- Copy-on-write (CR0.WP + page copy + remap, with TLB invalidation)
- Buddy physical page allocator (order 0-12, split/coalesce)
- Slab kernel heap (kmalloc/kfree over 8 object-size caches)
- mmap / munmap / mprotect

### Changed

- Banner simplified to `Power Kernel <version>` + `x86_64 microkernel`
- Version numbering is now `0.x` (beta) until the API stabilises
- `help` is a formatted, per-command list with descriptions
- `tasks` shows human-readable state names
- VGA hardware cursor now follows the software cursor

### Fixed

- `pmm_free_pages` returned a garbage free-page count
- Missing CR0.WP, missing invlpg, and register-clobber bugs in the VMM path
- VGA colour byte was never initialised (black-on-black text)
- `vga_set_cursor` clobbered `al`, which corrupted keyboard input
- Removed the auto-pinging client task (no more boot-time console spam)

## [0.1.0] - 2026-10-18

### Added

- Multiboot1 boot entry with 32-bit to 64-bit long-mode switch
- 64-bit GDT, 256-entry IDT, PIC remap, PIT timer (100 Hz)
- Identity-mapped 1 GiB address space (2 MiB pages)
- Physical memory manager (bitmap) from the Multiboot memory map
- Kernel heap (bump allocator)
- Preemptive round-robin scheduler
- Message-passing IPC (send / recv / reply) with per-task mailboxes
- System call interface (`int 0x80`)
- VGA and serial (COM1) consoles
- PS/2 keyboard driver and interactive shell
- Build system: Makefile, build.sh, build.bat, GRUB ISO support

[0.1.0]: https://github.com/Garl404/Power_Kernel/releases/tag/v0.1.0
[0.2.0]: https://github.com/Garl404/Power_Kernel/releases/tag/v0.2.0
[0.3.0]: https://github.com/Garl404/Power_Kernel/releases/tag/v0.3.0
[0.3.1]: https://github.com/Garl404/Power_Kernel/releases/tag/v0.3.1
