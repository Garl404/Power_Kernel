# Contributing to Power Kernel

Thanks for your interest in contributing.

## Getting started

1. Fork the repository and clone it locally.
2. Install the prerequisites (NASM and QEMU — see the README).
3. Build and run:

```
make run-nographic
```

## Guidelines

- Write everything in NASM assembly; keep the codebase dependency-free.
- Follow the existing style: lowercase mnemonics, 4-space indentation, no
  trailing whitespace, labels prefixed with a leading dot for local labels.
- Do not add comments to the kernel source (this project intentionally ships
  comment-free assembly); document behaviour in the README instead.
- Keep changes small and focused. One logical change per pull request.
- Test your change in QEMU (`make run-nographic`) before submitting.

## Submitting changes

1. Create a topic branch.
2. Commit with a clear message in the imperative mood.
3. Open a pull request and describe what changed and why.

## Code of Conduct

All participants are expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
