# changelog

all notable changes to ironshell-x86 are documented in this file.

---

## [2.1.7] - current

this release was mostly about fixing structural issues and hardening the sandbox environment. the old code was getting too big in single files and memory blocks were overlapping. we split everything up to enforce strict boundaries between subsystems.

### added

- refactored the source code into dedicated directories: boot/, config/, core/, lib/, and ui/. this replaces the old flat layout and makes isolated testing much easier.
- created config/memory.asm, config/errors.asm, and config/policies.asm to centralize memory addresses and error codes. this eliminates scattered hardcoded values across the codebase.
- implemented a serial debug module in lib/serial.asm. it allows printf-style debugging via com1 using qemu's -serial stdio flag, which is helpful for tracing execution without attaching gdb.
- added lba extended read support for disk operations inside lib/disk.asm.
- rewrote the stage1.asm boot sector to use lba (ah=42h) instead of the legacy chs method. it now includes a 3-attempt retry loop and resets the disk controller on failure.

### changed

- relocated stage2.asm from 0x8000 to 0x10000 (segment 0x1000). the previous address was overlapping directly with the sandbox (0x9000), theme (0xb000), and filter (0xc000) modules, causing data corruption.
- hardened the sandbox significantly. the ivt snapshot and restore routines now wrap write operations in cli and sti. this prevents a hardware interrupt from crashing the system mid-rewrite.
- increased the opcode scan depth from 128 to 512 bytes. strict hard-blocks were also added for hlt, wrmsr, rdmsr, and lgdt regardless of the active policy.
- the register integrity check now verifies es and sp post-execution, in addition to ds and ss.
- theme.asm, filter.asm, and sandbox.asm now expose their functions through stable jmp near api tables. cross-segment calls use call far and retf, which is cleaner than hardcoding specific offsets.
- updated the makefile to validate binary sizes. for instance, stage1.bin must be exactly 512 bytes, or the build will abort. it also prints the sector counts for every generated module.
- cleaned up autosetup.sh to locate the root makefile directly, removing the recursive find scans.

### removed

- removed the monolithic stage2.asm file. the tui logic now resides in ui/, and the payload logic is in core/.
- removed hardcoded offset calls such as theme_base + 42. all module communication now goes through the api jump tables.
- cleaned up dead code, orphaned color blocks, and obsolete shadow variables left over from previous iterations.

### fixed

- fixed a critical race condition in the ivt auto-restore routine. previously, a hardware interrupt firing during the table rewrite could lock up the system.
- fixed stack corruption in payload_memwalk caused by an unbalanced bx increment.
- fixed the command history bug in ui/input.asm. the di pointer was miscalculated after a scasb operation, corrupting strings when scrolling up or down.
- fixed stage1.asm drive number handling by saving dl to a dedicated memory location before any bios call could clobber it.

### notes

- the payload body still executes outside the sandbox envelope. the sandbox pre-scans and post-audits, but it does not provide hardware-level isolation (such as vt-x or strict segment limits). this remains out of scope for the mvp.
- stage2 is padded to 32768 bytes. any additions to core/stage2.asm must be monitored via the makefile size output to prevent overlapping into the sandbox segment at 0x9000.

---

## [2.1.6] - previous

this cycle focused on module integration, jump tables, disk layout correctness and cleanup across all subsystems. the goal was to make the previously disconnected modules actually talk to each other through a stable interface, and to remove dead code that had accumulated from earlier prototypes.

### added

- api jump tables at the top of filter.asm, theme.asm, and sandbox.asm. each entry is a fixed-size near jmp, so stage 2 can call any exported function by a stable offset without recalculating positions every time a module grows.
- theme_copy_colors api in theme.asm, copies all 10 color slots in one call.
- filter_api_match binding so stage 2's log filter queries the filter module's own active_filter state instead of keeping a shadow copy.
- theme_api_set binding so cmd_set_theme applies themes through the theme module and immediately redraws the full screen with the new palette.
- sandbox_api_entry and sandbox_api_post_exec bindings so sandbox_pre and sandbox_post route through the sandbox jump table.
- sender-side push ds and pop es fix in payload_memmap so e820 queries write into the stage 2 buffer instead of the ivt neighborhood.
- changelog.md (this file) so the readme stays focused on the current version.

### changed

- all exported module functions in filter.asm, theme.asm, and sandbox.asm now return with retf because stage 2 calls them via call far [ptr]. internal helpers remain near ret.
- sandbox_post now resolves sandbox_post_exec at sandbox_entry + 3 instead of the fragile hardcoded 0x902e.
- stage1.asm reads 4 sectors (2048 bytes) for the loader instead of 2, giving the loader room to grow without a silent partial load.
- cmd_set_filter writes into the filter module directly, so the filter engine and the shell share one source of truth for the active filter.
- payload_msgbox shellcode bytes were reordered to produce a valid mov ax, imm; ret stub at 0xa000 instead of an accidental memory write.
- readme rewritten to match actual code behavior across every subsystem, including corrected sector counts, load addresses, and sandbox wording.

### removed

- dead theme_apply_color inline color blocks (.color, .mono, .hacker, .retro, .stealth, .done) that were orphaned after the theme engine moved to a standalone module at 0xb000.
- the hardcoded sandbox_post equ 0x902e constant, replaced by an offset from sandbox_entry through the sandbox jump table.
- stage 2's shadow active_filter and active_theme_id variables. both subsystems now keep their own state inside their own module segment.
- the runtime shellcode disk load in loader.asm. payloads write their own stub into 0xa000 at execution time, so there was nothing to load.
- redundant clc and jc guard in cmd_run_payload, replaced with a real call sandbox_pre, which is now reachable and functional.

### fixed

- theme_apply_color now saves and restores ds and es around the far calls into the theme module, so it can be called safely from any context.
- cmd_set_filter no longer diverges from the filter module's state.
- sandbox_post no longer risks jumping to the wrong offset when the sandbox module's internal layout shifts.
- sandbox_entry now returns with retf 4, matching the far call from sandbox_pre and correctly cleaning up its two stack arguments.
- filter_match and filter_get_name now preserve bx across calls.
- filter_get_name clears dx before mul for cleanliness.
- loader lba values in makefile for theme and filter now match what loader.asm actually reads (87 and 89, not 83 and 85).
- makefile disasm target now uses the correct stage 2 origin (0x8000) and includes theme and filter binaries.
- makefile help memory layout text now reflects the real module placement.

### notes

- the sandbox pre-scans and post-audits every payload, but the payload body itself still executes outside the sandbox envelope. tightening that boundary is scheduled for a later cycle.
- the loader and stage 2 memory window is tight. if the loader grows past 2048 bytes, both the stage 1 read count and loader_max_bytes need to change together, and the stage 2 origin may need to move.

---

## [1.0] - initial release

- two-stage bootloader.
- seven payloads.
- basic sandbox with four policy levels.
