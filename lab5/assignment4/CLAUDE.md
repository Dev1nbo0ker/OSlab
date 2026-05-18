# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
cd build && make && make run       # build and launch QEMU
cd build && make && make debug     # build and launch QEMU + GDB in gnome-terminal
make clean                         # remove build artifacts
```

The kernel is a 32-bit flat binary loaded at `0x00020000`. Build uses `nasm` for `.asm`, `g++ -m32 -march=i386 -nostdlib -ffreestanding` for `.cpp`, and `ld -melf_i386 -Ttext 0x00020000` for linking.

## Architecture

This is a bare-metal x86 kernel written in C++ (no standard library) with a cooperative/preemptive thread scheduler.

**Boot flow:** MBR (real mode) → bootloader (sets up GDT, enables protected mode) → `entry.asm` → `setup_kernel()` in `setup.cpp`. Setup initializes the interrupt manager, STDIO, program manager, creates the first thread, and switches to it via `asm_switch_thread(0, firstPCB)`.

**Threads/PCB:** Each PCB is a 4096-byte block from a static pool (`PCB_SET[16 * 4096]`). The PCB embeds the thread's kernel stack at its top end. The initial stack layout (set in `executeThread`) is: 4 zeroed slots for callee-saved registers → function pointer → `program_exit` return address → parameter pointer. When `asm_switch_thread` restores ESP from `next->stack`, it pops the 4 dummy registers then `ret`s into the target function.

**Context switching (`asm_switch_thread`):** Pushes ebp/ebx/edi/esi onto current stack, saves ESP to `cur->stack`, loads ESP from `next->stack`, pops the four registers, `sti`, then `ret` into the switched-in thread.

**Interrupt system:** IDT at `0x8880`, 8259A PIC remapped (master IRQ0→`0x20`, slave→`0x28`). Only the timer IRQ (IRQ0) is enabled. Timer ISR flow: `asm_time_interrupt_handler` (pushad → EOI → call C handler → popad → iret).

**Scheduling (two variants):**
- `schedule()` — original round-robin. Current thread goes to back of `readyPrograms`, front thread is picked next.
- `scheduleCFS()` — CFS-like weighted fair scheduler. Each tick increments `vruntime` scaled by weight, picks thread with minimum `vruntime` via linear scan of `readyPrograms`. Time slice = `SCHED_PERIOD * weight / totalWeight`, minimum `MIN_GRANULARITY`.

**PCB key fields:** `stack` (saved ESP), `status` (CREATED/READY/RUNNING/BLOCKED/DEAD), `tagInGeneralList` (link in `readyPrograms`), `tagInAllList` (link in `allPrograms`). CFS adds: `nice`, `weight`, `vruntime`, `realRuntime`, `timeSlice`, `currentSliceTicks`.

**Global singletons** defined in `setup.cpp` and declared `extern` in `os_modules.h`: `STDIO stdio` (VGA text-mode output at `0xB8000`), `InterruptManager interruptManager`, `ProgramManager programManager`.

**Thread exit:** `program_exit()` marks the current thread DEAD, then calls `schedule()`. The scheduler frees DEAD threads' PCBs. The first thread (pid 0) must never exit — it calls `asm_halt()` instead.
