# Changelog

All notable changes to **ironshell-x86** are documented in this file.

---

## [2.1.6] - Current

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
