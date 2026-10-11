# MYOS — x86 Assembly Kernel Prototype

**MYOS** is a small educational operating-system prototype written in NASM assembly for **32-bit x86, BIOS boot, and QEMU**.

> Status: early prototype / learning project. It is not a production operating system, and it has not yet been validated on physical hardware.

## Features intended by this prototype

- BIOS boot sector and protected-mode transition
- GDT and IDT setup
- 8259A PIC and PIT timer interrupt
- PS/2 keyboard interrupt handling
- VGA text-mode console
- Tiny kernel-resident command interpreter

The project is currently a **monolithic kernel prototype with microkernel learning goals**. The console and interrupt handlers still execute in kernel mode; IPC, user mode, scheduling, and isolated user-space services are future work.

## Build environment

Recommended: Linux (including WSL2) with:

- NASM
- GNU Make
- QEMU for x86 system emulation

On Debian/Ubuntu:

```bash
sudo apt update
sudo apt install nasm make qemu-system-x86
```

## Build and run

```bash
make
make run
```

The build creates files under `build/`:

- `build/boot.bin`
- `build/kernel.bin`
- `build/os.img`

To remove generated files:

```bash
make clean
```

Run only in an emulator while developing. The image is a virtual disk image; do not write it to a physical disk.

## Repository layout

```text
.
├── .github/
│   └── workflows/
│       └── build.yml
├── .gitignore
├── LICENSE
├── Makefile
├── README.md
├── boot.asm
└── kernel.asm
```

## GitHub Actions

Every push and pull request runs a build job that installs NASM and Make and attempts to build the disk image. This checks assembly/build integration, but does not prove the kernel works correctly at runtime.

## Roadmap

- [ ] Make boot and interrupt handling robust
- [ ] Fix and test keyboard input and command-buffer handling
- [ ] Add a basic exception-reporting path
- [ ] Add a simple physical memory allocator
- [ ] Add paging
- [ ] Add ring 3 and a system-call ABI
- [ ] Add scheduler and context switching
- [ ] Implement IPC/message passing
- [ ] Move console and device services into isolated user-space processes
- [ ] Add a minimal init process and user shell

## Contributing

Issues and pull requests are welcome. Please include the host OS, NASM version, QEMU version, exact command, and complete error output when reporting a build or boot issue.

## License

MIT. See [LICENSE](LICENSE).
