![Logo](/Photos/ironshell_x86_banner.svg)

# ironshell-x86 – Bare-Metal Shellcode Sandbox

**ironshell-x86** is a bare-metal x86 shellcode execution and analysis environment written entirely in 16-bit Assembly. It runs directly from a bootable disk image — no OS, no runtime, no libc. Just raw silicon.

[![Architecture](https://img.shields.io/badge/arch-x86%2016--bit-blue)]()
[![Language](https://img.shields.io/badge/language-NASM%20Assembly-red)]()
[![Mode](https://img.shields.io/badge/mode-Ring%200%20%2F%20Real%20Mode-critical)]()
[![Sandbox](https://img.shields.io/badge/sandbox-4%20policy%20levels-orange)]()
[![Payloads](https://img.shields.io/badge/payloads-8%20injectable%20modules-purple)]()
[![Boot](https://img.shields.io/badge/boot-MBR%20%2B%202--Stage%20Loader-blueviolet)]()
[![Themes](https://img.shields.io/badge/themes-5%20color%20themes-brightgreen)]()
[![Filters](https://img.shields.io/badge/log%20filters-6%20modes-yellow)]()

---

## [>>] Features

- [+] **2-Stage Bootloader** — Stage 1 MBR loads Stage 2 + Sandbox + Shellcode + Theme + Filter modules from disk with retry logic
- [+] **TUI Shell** — Full interactive terminal UI with dual-panel VGA layout, command history (↑↓), page scroll (PgUp/PgDn), and live execution log
- [+] **8 Injectable Payloads** — MSGBOX, MEMWALK, PORTPROBE, STACKSMASH, NXPROBE, CPUINFO, IVTDUMP, MEMMAP
- [+] **Sandbox v2.1** — 4 enforcement policies, pre-execution opcode scanning (STI/HLT/IO/PRIV), IVT snapshot diffing with auto-restore, register integrity checks, CPUID support detection
- [+] **Theme Engine** — 5 color themes (COLOR, MONO, HACKER, RETRO, STEALTH) loaded as a separate module at 0xB000
- [+] **Log Filter System** — 6 filter modes (ALL, INFO, WARN, ERROR, SUCCESS, ACCENT) loaded as a separate module at 0xC000
- [+] **Hardware Analysis** — CPUID vendor/brand/feature detection, A20 gate test, E820 memory map, conventional memory sizing
- [+] **Error Tracking** — Typed error codes with descriptions, per-session error history via `errors` command
- [+] **Clean Build System** — NASM + QEMU Makefile with GDB debug stub, ndisasm disassembly, and hard binary size validation for all 5 modules

---

## Schematic of the Working and Execution Logic 
![Scheme](/Photos/update_scheme.png)

---

## [CD] Installation

### 1. Clone the repository

```bash
git clone https://github.com/tc4dy/ironshell-x86.git
cd ironshell-x86/ironshell-x86
```

### 2. Install dependencies

```bash
sudo apt install nasm qemu-system-x86
```

### 3. Build and run

```bash
make
make run
```

---

## Usage

```bash
make              # Build all binaries and assemble disk image
make run          # Launch in QEMU (terminal/curses mode)
make run-sdl      # Launch in QEMU (SDL window)
make debug        # Launch with GDB stub on port :1234
make disasm       # Disassemble all binaries via ndisasm
make clean        # Remove all build artifacts
make help         # Show full build reference
```

---

## [-<] Shell Commands

Once booted in QEMU, the interactive shell accepts:

| Command | Description |
|---|---|
| `list` | List all available payloads with index and risk flag |
| `sel <n> [arg]` | Select a payload by index; optional runtime argument |
| `run` | Execute the currently selected payload through the sandbox |
| `sandbox` | Re-run all sandbox environment checks |
| `dump <hex>` | Hexdump 32 bytes at a given memory address |
| `info` | Display system memory layout and load addresses |
| `clear` | Clear the execution log panel |
| `theme <1-5>` | Apply a color theme |
| `themes` | List all available color themes |
| `filter <0-5>` | Set log output filter by color category |
| `filters` | List all available filter modes |
| `errors` | Display last error code and description |
| `help` | Show full command reference |

> **Tip:** Use ↑ / ↓ arrow keys to navigate command history. Use PgUp / PgDn to scroll the execution log panel.

---

## [-/] Payload Reference

| # | Name | Description | Risk |
|---|---|---|---|
| 0 | `MSGBOX` | Writes a small MOV/RET stub at 0xA000 and executes it | [+] Safe |
| 1 | `MEMWALK` | Walks and dumps the BIOS Data Area (0x0400+) | [+] Safe |
| 2 | `PORTPROBE` | Samples 8 I/O ports starting at the given hex port (default `0x03F8`) via `IN` | [+] Safe |
| 3 | `STACKSMASH` | Writes canary pattern to stack and verifies integrity | [!] Caution |
| 4 | `NXPROBE` | Tests NX/DEP enforcement by executing a RET stub at 0xA000 | [+] Safe |
| 5 | `CPUINFO` | Full CPUID enumeration — vendor, brand, stepping, SSE/AVX | [+] Safe |
| 6 | `IVTDUMP` | Dumps N Interrupt Vector Table entries; default 16 (INT 0–15) | [+] Safe |
| 7 | `MEMMAP` | Queries E820 system memory map via INT 15h; falls back to INT 12h | [+] Safe |

**Payload arguments** — use `sel <n> <arg>` before `run`:

| Payload | Argument | Example |
|---|---|---|
| `PORTPROBE` | Starting I/O port (hex) | `sel 2 03F8` |
| `STACKSMASH` | Canary depth (decimal, 1–16) | `sel 3 8` |
| `IVTDUMP` | Entry count (decimal, 1–256) | `sel 6 32` |

---

## Theme System

5 built-in color themes, switchable live without reboot:

| # | Name | Description |
|---|---|---|
| 1 | `COLOR` | Full 16-color CGA palette (default) |
| 2 | `MONO` | Monochrome white-on-black |
| 3 | `HACKER` | Green phosphor terminal |
| 4 | `RETRO` | Amber CRT display |
| 5 | `STEALTH` | Near-invisible dark mode |

```
theme 3       # Switch to hacker green
themes        # List all themes
```

The theme engine loads as a standalone module at **0xB000**. All 10 UI color slots (normal, bright, success, error, warn, accent, dim, selected, title, status) are remapped on theme change and the entire screen is redrawn immediately.

---

## [>_] Log Filter System

6 filter modes to control what the log panel shows:

| # | Name | Shows |
|---|---|---|
| 0 | `ALL` | All log entries (default) |
| 1 | `INFO` | Dim and accent entries only |
| 2 | `WARN` | Warning entries only |
| 3 | `ERROR` | Error entries only |
| 4 | `SUCCESS` | Success entries only |
| 5 | `ACCENT` | Accent-colored entries only |

```
filter 3      # Show errors only
filters       # List all filter modes
```

The filter engine loads as a standalone module at **0xC000**. Filtering is applied at render time — all log entries are preserved in the buffer regardless of the active filter.

---

## [#] Sandbox v2.1

The sandbox module (`sandbox.asm`) loads at `0x9000` and enforces one of four active policies:

| Policy | Value | Behavior |
|---|---|---|
| `POLICY_ALLOW_ALL` | `0x00` | All payloads execute without restriction |
| `POLICY_BLOCK_DANGER` | `0x01` | The payload flagged `DANGEROUS` (STACKSMASH) is blocked *(default)* |
| `POLICY_AUDIT_ONLY` | `0x02` | All payloads execute; violations are logged only |
| `POLICY_LOCKDOWN` | `0x03` | No execution permitted under any condition |

Pre-execution analysis (v2.1) includes:

- **CPUID detection** — verifies CPU supports CPUID before any feature query
- **Opcode scanning** — detects `IN`/`OUT`, `CLI`, `STI`, `HLT`, `WBINVD`, `RDMSR`/`WRMSR` across 128 bytes of payload
- **HLT blocking** — payloads containing `HLT (0xF4)` are hard-blocked regardless of policy (system freeze risk)
- **Privileged prefix blocking** — `0x0F 0x01`, `0x0F 0x09`, `0x0F 0x30`, `0x0F 0x32` are blocked (LGDT/WBINVD/WRMSR/RDMSR)
- **IVT snapshot + auto-restore** — all 256 IVT entries are snapshotted before execution; any vector modified by the payload is automatically restored after, and the modification is logged
- **Register integrity** — verifies `SS` and `DS` segment state post-execution; violations increment the policy score penalty
- **Bounds check** — confirms payload dispatch address is within `0xA000–0xAFFF`
- **Policy scoring** — a 0–100 score tracks cumulative violation weight across the session

Every payload is pre-scanned by `sandbox_entry` before dispatch and post-audited by `sandbox_post_exec` after return. Policy enforcement, opcode scanning and IVT diffing happen in the sandbox envelope; the payload body itself executes outside it.

---

## Memory Layout

```
0x0000 – 0x03FF Interrupt Vector Table (IVT)
0x0400 – 0x04FF BIOS Data Area (BDA)
0x7C00 – 0x7DFF stage1.asm MBR bootloader (512 bytes, 1 sector)
0x7E00 – 0x85FF loader.asm Loader module (~2048 bytes, 4 sectors)
0x8000 – 0xFFFF stage2.asm Execution engine + TUI shell (32768 bytes, 64 sectors)
0x9000 – 0xAFFF sandbox.asm Protection & analysis layer (8192 bytes, 16 sectors)
0xA000 – 0xAFFF [EXEC] Shellcode injection target
0xB000 – 0xB3FF theme.asm Theme engine (1024 bytes, 2 sectors)
0xC000 – 0xC3FF filter.asm Log filter module (1024 bytes, 2 sectors)
0xB800 – 0xBFFF VGA Text Memory (80×25, mode 0x03)
```

> **Note:** The theme module at 0xB000 and VGA text buffer at 0xB800 are in the same physical segment space. Module data is accessed as flat 16-bit offsets from DS=0x0000, so `0x0000:0xB000` (theme) and `0xB800:0x0000` (VGA segment) resolve to different physical addresses and do not overlap.

---

## [i] Error Codes

The `errors` command shows the last typed error code and a plain-text description:

| Code | Name | Description |
|---|---|---|
| `0x00` | `ERR_NONE` | No error |
| `0x01` | `ERR_DISK` | Disk read failure during load |
| `0x02` | `ERR_BOUNDS` | Address outside permitted range |
| `0x03` | `ERR_SANDBOX_BLOCK` | Sandbox blocked execution |
| `0x04` | `ERR_BAD_ARG` | Invalid command argument |
| `0x05` | `ERR_OOB` | Index out of range |
| `0x06` | `ERR_NO_PAYLOAD` | No payload selected |
| `0x07` | `ERR_BAD_ADDR` | Invalid hex address for dump |
| `0x08` | `ERR_THEME_INVALID` | Theme index out of range (1–5) |
| `0x09` | `ERR_FILTER_INVALID` | Filter index out of range (0–5) |
| `0x0A` | `ERR_E820_FAIL` | E820 INT 15h memory query failed |

---

## Quick Start (Automated)

The fastest way to boot **ironshell-x86** is the automated setup script. It
handles the full pipeline — cloning the repository, installing missing
dependencies, building the disk image and launching QEMU — in a single command.

```bash
curl -fsSL https://raw.githubusercontent.com/tc4dy/ironshell-x86/main/autosetup.sh -o autosetup.sh
chmod +x autosetup.sh
./autosetup.sh
```

The script performs the following steps:

- Detects the host Linux distribution via `/etc/os-release`
- Selects the correct package manager (`apt`, `pacman`, `dnf`, `zypper`, `xbps`, `apk` or `emerge`)
- Installs missing `git`, `nasm`, `qemu-system-x86` and `make` packages
- Clones the repository into a temporary workspace under `/tmp`
- Enters the `ironshell-x86/` subdirectory and builds the disk image
- Boots the image under `qemu-system-i386` in curses mode

### Script Options

| Flag | Description |
|---|---|
| `-k`, `--keep` | Preserve the temporary workspace on exit (useful for debugging) |
| `-h`, `--help` | Show usage information |

### Requirements

- A Linux host with `sudo` or `doas` (unless already running as root)
- A terminal that supports curses rendering
- Network access to GitHub for the initial clone

### Notes

- The temporary workspace is created with `mktemp -d -t ironshell-XXXXXX`
  and removed automatically on exit unless `-k` is passed.
- If the cloned repository layout changes, the script falls back to locating
  any `Makefile` within three directory levels of the clone root.
- QEMU exits via `Ctrl+A` followed by `X` when running in curses mode.

---

## [dbg] Debug with GDB

```bash
make debug
```

Then in a second terminal:

```bash
gdb
(gdb) target remote :1234
(gdb) set architecture i8086
(gdb) break *0x7c00
(gdb) continue
```

Step through the MBR byte by byte, inspect registers, and trace the full boot sequence. Stage 2 entry is at `0x7E00`; sandbox entry is at `0x9000`.

---

## Requirements

- `nasm` — Netwide Assembler
- `qemu-system-i386` — x86 system emulator
- `ndisasm` — for `make disasm`, included with NASM package

---

## File Structure

```
ironshell-x86/
├── stage1.asm MBR bootloader — loads loader from disk
├── loader.asm Loader module — loads stage2, sandbox, theme, filter
├── stage2.asm Execution engine, TUI shell, 8 payloads
├── sandbox.asm Protection layer — policy engine, opcode scan, IVT diff+restore
├── theme.asm Theme engine — 5 themes, 10-slot color table, live redraw
├── filter.asm Log filter module — 6 filter modes, color-category matching
└── Makefile Build, run, debug, disasm targets with size validation

Photos/
├── ironshell_x86_banner.svg Repository banner
└── scheme.png Execution flow diagram

Root/
├── .gitignore
├── autosetup.sh Automated clone + dependency install + build + boot script
├── CHANGELOG.md Full version history
├── LICENSE
└── README.md
```

---

## Version History

**v2.1.5** — current

**New Features:**

- Added `theme.asm` module (0xB000): 5 color themes, live screen redraw
- Added `filter.asm` module (0xC000): 6 log filter modes, render-time filtering
- Added `MEMMAP` payload (E820 memory map via INT 15h with INT 12h fallback)
- Sandbox: IVT auto-restore, STI/HLT detection, CPUID guard, policy scoring
- New commands: `theme`, `themes`, `filter`, `filters`, `errors`
- Payload arguments: `sel <n> <arg>` passes runtime args to PORTPROBE, STACKSMASH, IVTDUMP
- Error tracking: typed error codes with `errors` command
- Log scroll: PgUp/PgDn navigation in the log panel

**Fixes:**

- Fixed: `exec_payload` now pre-scans all payloads through `sandbox_entry` before dispatch
- Fixed: `payload_memwalk` stack corruption (double BX increment)
- Fixed: `sb_pre_exec` policy logic (`jge` → correct allow/block ordering)
- Fixed: `hist_prev` scasb using wrong DI after movsb
- Fixed: `format_payload_line` invalid NASM multi-operand `mov`
- Fixed: E820 entry stride inconsistency (20 vs 24 bytes)
- Fixed: stage2/sandbox memory overlap (stage2 padded to 32768, sandbox at 0x9000 — gap enforced by layout)
- Fixed: `strcpy_bounded_name` double null write
- Fixed: `vga_draw_banner` box-drawing character sequence
- Fixed: loader sector layout and disk addressing
- Fixed: ES segment corruption in `init_payloads`, `theme_init_defaults`, `ui_full_redraw`, `ui_draw_frame`

**v1.0** — initial release

- 2-stage bootloader, 7 payloads, basic sandbox with 4 policies
- For the full changelog across all versions, see [CHANGELOG.md](CHANGELOG.md).
