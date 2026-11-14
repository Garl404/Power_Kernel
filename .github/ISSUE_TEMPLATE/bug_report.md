---
name: Bug report
about: Report a bug in Power Kernel
title: "[Bug] "
labels: bug
assignees: ""
---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behaviour:

1. Build with `make`
2. Run with `qemu-system-x86_64 -kernel build/kernel.bin -nographic -no-reboot`
3. Enter the following in the shell: ...
4. See the error

**Expected behaviour**
What you expected to happen.

**Environment**

- Host OS: (e.g. Windows 11 / macOS 15 / Ubuntu 24.04)
- NASM version: (`nasm -v`)
- QEMU version: (`qemu-system-x86_64 --version`)

**Additional context**
Add any other context, screenshots, or serial output here.
