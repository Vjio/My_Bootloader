# My_Bootloader

A two-stage x86 bootloader written in x86 assembly and C, targeting a 1.44MB floppy image.
Built as a learning project to understand the PC boot process from the ground up.

## What it does

**Stage 1** fits inside the 512-byte MBR boot sector.  It reads drive geometry dynamically
from the BIOS, loads stage 2 from disk using
BIOS INT 13h with a 3-attempt retry loop, and jumps to it.

**Stage 2** runs in 16-bit real mode with full BIOS access and does the heavy lifting:
- Traverses the FAT12 filesystem to find and load `kernel.bin`
- Enables the A20 line via the 8042 keyboard controller
- Sets up a flat-model GDT (null, 32-bit code, 32-bit data, 16-bit code, 16-bit data descriptors)
- Switches the CPU from 16-bit real mode to 32-bit protected mode
- Far jumps into 32-bit code, reloads segment registers, zeroes BSS, and calls into C

Stage 2 also implements real mode ↔ protected mode switching to allow BIOS calls from 32-bit
C code — disk reads and drive parameter queries go through this transition.

## Build

Requires an `i686-elf` cross-compiler (binutils + GCC). Build it following the
[OSDev GCC Cross-Compiler guide](https://wiki.osdev.org/GCC_Cross-Compiler), or use a
pre-built toolchain from [xPack](https://xpack.github.io/).

```bash
make
```

Output is a `floppy.img` that can be run directly in QEMU:

```bash
qemu-system-i386 -fda floppy.img
```

Or in Bochs using the provided `bochs_config`.

## Structure

```
src/
  bootloader/
    stage1/   - MBR boot sector (NASM)
    stage2/   - FAT12 loader, A20, GDT, protected mode switch (NASM + C)
  kernel/     - basic kernel used to prove that the bootloader works
```

## What I learned

- Bootloaders and why they are split into 2 stages
- FAT12 filesystem layout and cluster chain traversal
- BIOS disk I/O
- x86 segmentation, GDT descriptor format, and why the fields are laid out the way they are
- How to build a freestanding C environment with a custom linker script and cross-compiler

## References and credits

Built following nanobyte_dev's ["Building an OS"](https://www.youtube.com/@nanobyte-dev) YouTube series.
Several implementation details and code excerpts adapted from
[OSDev Wiki](https://wiki.osdev.org) tutorials. The intel manual for 64 and IA-32 Architectures
was also very useful.

Big thanks to nanobyte and the os dev community!

## Next

This project is complete as a standalone bootloader. I initially wanted to build an entire hobby OS
from the ground up, Bootloader included, but this project has shown me has intricate a bootloader can get.
Thus, the next project will be a separate kernel booted via GRUB, focused on memory management, paging
and scheduling.
