# Changelog

All notable changes to **ironshell-x86** are documented in this file.

---

## [2.1.7] - Current

This cycle focused on a complete architectural refactor to resolve structural memory overlaps, harden the sandbox execution envelope, and stabilize the boot sequence. The monolithic source files were split into a layered, modular directory structure to enforce separation of concerns and improve maintainability.

### Added

- **Modular directory structure**: Source files are now organized into `boot/`, `config/`, `core/`, `lib/`, and `ui/`. This replaces the previous flat layout where all logic was contained within a few massive files.
- **Centralized configuration**: Added `config/memory.asm`, `config/errors.asm`, and `config/policies.asm`. All memory addresses, load offsets, and error codes are now defined in one location, eliminating hardcoded magic numbers across the codebase.
- **Serial debugging (`lib/serial.asm`)**: Implemented COM1 serial output routines. This allows printf-style debugging via QEMU's `-serial stdio` flag without requiring a GDB stub.
- `lib/disk.asm` now handles disk operations with an explicit LBA Extended Read (`AH=42h`) Disk Address Packet (DAP) structure.
- **LBA Extended Read**: Replaced the legacy CHS (`AH=02h`) boot sector read in `stage1.asm` with LBA. The new routine includes a 3-attempt retry loop and disk reset on failure.

### Changed

- **Memory Layout Relocation**: `stage2.asm` has been moved from `0x8000` to `0x10000` (Segment `0x1000`). This completely resolves the previous overlap where stage2's data buffers were colliding with `sandbox` (`0x9000`), `theme` (`0xB000`), and `filter` (`0xC000`).
- **Sandbox Hardening**: 
  - IVT snapshot and restore routines now wrap the write operations with `CLI` and `STI` to prevent race conditions from interrupts firing during table modification.
  - Opcode scanning depth increased from 128 bytes to `SCAN_DEPTH_MAX` (512 bytes) to accommodate larger payloads.
  - Privileged opcodes (`HLT`, `WRMSR`, `RDMSR`, `LGDT`) are now hard-blocked regardless of the active policy level.
  - Register integrity checks now snapshot and verify `ES` and `SP` in addition to `DS` and `SS`.
- **API Interfaces**: `theme.asm`, `filter.asm`, and `sandbox.asm` now expose their functions via stable `jmp near` API tables. Cross-segment calls use `call far` and `retf` to enforce strict boundary execution.
- **Build System (`Makefile`)**: Rewritten to include strict byte-size validations for every module (e.g., `stage1.bin` must be exactly 512 bytes). Output now explicitly reports file sizes and sector counts, and aborts compilation if limits are exceeded.
- **Bootstrap (`autosetup.sh`)**: Cleaned up the logic to directly locate the root `Makefile` and the `ironshell.img` output without relying on recursive `find` scans.

### Removed

- Removed the monolithic `stage2.asm` structure; TUI, payloads, and command routing logic are now split into `ui/` and `core/`.
- Removed all hardcoded offset calls (e.g., `THEME_BASE + 42`, `FILTER_BASE + 6`). Modules are now accessed through their respective API jump tables.
- Removed redundant dead code, orphaned inline color blocks, and obsolete shadow variables in the shell loop.

### Fixed

- Fixed a critical race condition in IVT auto-restore that could crash the system if a hardware interrupt occurred during the table rewrite.
- Fixed stack corruption in `payload_memwalk` caused by an unbalanced `BX` increment.
- Fixed history navigation bug in `ui/input.asm` where the pointer (`DI`) was miscalculated after a `scasb` operation, causing string corruption.
- Fixed `stage1.asm` drive number handling by storing `DL` in a dedicated memory location (`BOOT_DRIVE_ADDR`) before any BIOS calls could clobber it.

### Notes

- The payload body still executes outside the sandbox envelope (the sandbox pre-scans and post-audits, but does not hardware-isolate the execution ring). Hardware-level execution bounding (e.g., VT-x or strict segment limits) remains out of scope for the MVP.
- `stage2` has been padded to 32768 bytes. Any further additions to `core/stage2.asm` must be monitored via the Makefile size validation to prevent overlapping into the `sandbox` segment at `0x9000`.

---

## [2.1.6] - Previous

This cycle focused on module integration, jump tables, disk layout correctness
and cleanup across all subsystems. The goal was to make the previously
disconnected modules actually talk to each other through a stable interface,
and to remove dead code that had accumulated from earlier prototypes.

### Added

- **API jump tables** at the top of `filter.asm`, `theme.asm` and `sandbox.asm`.
  Each entry is a fixed-size near JMP, so stage2 can call any exported function
  by a stable offset without recomputing positions every time a module grows.
- `theme_copy_colors` API in `theme.asm` — copies all 10 color slots in one call.
- `filter_api_match` binding so `stage2`'s log filter actually queries the
  filter module's own `active_filter` state instead of keeping a shadow copy.
- `theme_api_set` binding so `cmd_set_theme` now applies themes through the
  theme module and immediately redraws the full screen with the new palette.
- `sandbox_api_entry` and `sandbox_api_post_exec` bindings so `sandbox_pre`
  and `sandbox_post` route through the sandbox jump table.
- Sender-side `push ds / pop es` fix in `payload_memmap` so E820 queries write
  into the stage2 buffer instead of the IVT neighborhood.
- `CHANGELOG.md` (this file) so README stays focused on the current version.

### Changed

- All exported module functions in `filter.asm`, `theme.asm` and `sandbox.asm`
  now return with `retf` because stage2 calls them via `call far [ptr]`.
  Internal helpers remain near `ret`.
- `sandbox_post` now resolves `sandbox_post_exec` at `SANDBOX_ENTRY + 3`
  instead of the fragile hardcoded `0x902E`.
- `stage1.asm` reads 4 sectors (2048 bytes) for the loader instead of 2,
  giving the loader room to grow without a silent partial load.
- `cmd_set_filter` writes into the filter module directly, so the filter
  engine and the shell share one source of truth for the active filter.
- `payload_msgbox` shellcode bytes were reordered to produce a valid
  `mov ax, imm; ret` stub at 0xA000 instead of an accidental memory write.
- README rewritten to match actual code behavior across every subsystem,
  including corrected sector counts, load addresses and sandbox wording.

### Removed

- Dead `theme_apply_color` inline color blocks (`.color`, `.mono`, `.hacker`,
  `.retro`, `.stealth`, `.done`) that were orphaned after the theme engine
  moved to a standalone module at 0xB000.
- The hardcoded `SANDBOX_POST equ 0x902E` constant — replaced by an offset
  from `SANDBOX_ENTRY` through the sandbox jump table.
- Stage2's shadow `active_filter` and `active_theme_id` variables. Both
  subsystems now keep their own state inside their own module segment.
- The runtime shellcode disk load in `loader.asm`. Payloads write their own
  stub into 0xA000 at execution time, so there was nothing to load.
- Redundant `clc / jc` guard in `cmd_run_payload` — replaced with a real
  `call sandbox_pre`, which is now reachable and functional.

### Fixed

- `theme_apply_color` now saves and restores `DS` and `ES` around the far
  calls into the theme module, so it can be called safely from any context.
- `cmd_set_filter` no longer diverges from the filter module's state.
- `sandbox_post` no longer risks jumping to the wrong offset when the
  sandbox module's internal layout shifts.
- `sandbox_entry` now returns with `retf 4`, matching the far call from
  `sandbox_pre` and correctly cleaning up its two stack arguments.
- `filter_match` and `filter_get_name` now preserve `BX` across calls.
- `filter_get_name` clears `DX` before `mul` for cleanliness.
- Loader LBA values in `Makefile` for theme and filter now match what
  `loader.asm` actually reads (87 and 89, not 83 and 85).
- `Makefile disasm` target now uses the correct stage2 origin (0x8000)
  and includes theme and filter binaries.
- `Makefile help` memory layout text now reflects the real module placement.

### Notes

- The sandbox pre-scans and post-audits every payload, but the payload body
  itself still executes outside the sandbox envelope. Tightening that
  boundary is scheduled for a later cycle.
- The loader/stage2 memory window is tight. If the loader grows past 2048
  bytes, both the stage1 read count and `LOADER_MAX_BYTES` need to change
  together, and the stage2 origin may need to move.

---

## [1.0] - Initial release

- Two-stage bootloader.
- Seven payloads.
- Basic sandbox with four policy levels.
