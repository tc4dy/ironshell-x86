NASM     := nasm
QEMU     := qemu-system-i386
DD       := dd
NDISASM  := ndisasm

IMAGE    := ironshell.img
SECTORS  := 2880

STAGE1   := stage1.bin
LOADER   := loader.bin
STAGE2   := stage2.bin
SANDBOX  := sandbox.bin
THEME    := theme.bin
FILTER   := filter.bin

STAGE1_SECTOR   := 0
LOADER_SECTOR   := 1
STAGE2_SECTOR   := 3
SANDBOX_SECTOR  := 67
THEME_SECTOR    := 87
FILTER_SECTOR   := 89

NASMFLAGS := -f bin

all: check $(IMAGE)

check:
	@printf '  [CHECK] Verifying required tools...\n'
	@command -v $(NASM)    >/dev/null 2>&1 || { printf '  [ERR] nasm not found. Install: sudo apt install nasm\n'; exit 1; }
	@command -v $(QEMU)    >/dev/null 2>&1 || { printf '  [ERR] qemu-system-i386 not found. Install: sudo apt install qemu-system-x86\n'; exit 1; }
	@command -v $(DD)      >/dev/null 2>&1 || { printf '  [ERR] dd not found. This should be part of coreutils.\n'; exit 1; }
	@command -v $(NDISASM) >/dev/null 2>&1 || { printf '  [ERR] ndisasm not found. It is bundled with nasm.\n'; exit 1; }
	@printf '  [OK]    All tools present.\n'

$(IMAGE): $(STAGE1) $(LOADER) $(STAGE2) $(SANDBOX) $(THEME) $(FILTER)
	@printf '  [IMG]   Creating blank disk image (%d sectors, %d KB)...\n' $(SECTORS) $$(( $(SECTORS) / 2 ))
	@$(DD) if=/dev/zero of=$(IMAGE) bs=512 count=$(SECTORS) status=none
	@printf '  [IMG]   Writing %-12s -> sector %d\n' "$(STAGE1)" $(STAGE1_SECTOR)
	@$(DD) if=$(STAGE1) of=$(IMAGE) bs=512 seek=$(STAGE1_SECTOR) conv=notrunc status=none
	@printf '  [IMG]   Writing %-12s -> sector %d\n' "$(LOADER)" $(LOADER_SECTOR)
	@$(DD) if=$(LOADER) of=$(IMAGE) bs=512 seek=$(LOADER_SECTOR) conv=notrunc status=none
	@printf '  [IMG]   Writing %-12s -> sector %d\n' "$(STAGE2)" $(STAGE2_SECTOR)
	@$(DD) if=$(STAGE2) of=$(IMAGE) bs=512 seek=$(STAGE2_SECTOR) conv=notrunc status=none
	@printf '  [IMG]   Writing %-12s -> sector %d\n' "$(SANDBOX)" $(SANDBOX_SECTOR)
	@$(DD) if=$(SANDBOX) of=$(IMAGE) bs=512 seek=$(SANDBOX_SECTOR) conv=notrunc status=none
	@printf '  [IMG]   Writing %-12s -> sector %d\n' "$(THEME)" $(THEME_SECTOR)
	@$(DD) if=$(THEME) of=$(IMAGE) bs=512 seek=$(THEME_SECTOR) conv=notrunc status=none
	@printf '  [IMG]   Writing %-12s -> sector %d\n' "$(FILTER)" $(FILTER_SECTOR)
	@$(DD) if=$(FILTER) of=$(IMAGE) bs=512 seek=$(FILTER_SECTOR) conv=notrunc status=none
	@printf '  [OK]    Disk image ready: %s\n' "$(IMAGE)"

$(STAGE1): boot/stage1.asm config/memory.asm config/errors.asm
	@printf '  [ASM]   %s\n' "$<"
	@$(NASM) $(NASMFLAGS) -o $@ $<
	@SIZE=$$(wc -c < $@); \
	if [ $$SIZE -ne 512 ]; then \
		printf '  [ERR]   %s must be exactly 512 bytes (got %d)\n' "$@" $$SIZE; \
		rm -f $@; exit 1; \
	fi
	@printf '  [OK]    %s (%d bytes)\n' "$@" 512

$(LOADER): boot/loader.asm config/memory.asm lib/disk.asm
	@printf '  [ASM]   %s\n' "$<"
	@$(NASM) $(NASMFLAGS) -o $@ $<
	@SIZE=$$(wc -c < $@); \
	if [ $$SIZE -gt 2048 ]; then \
		printf '  [ERR]   %s exceeds 2048 bytes (got %d)\n' "$@" $$SIZE; \
		rm -f $@; exit 1; \
	fi
	@printf '  [OK]    %s (%d bytes, %d sectors)\n' "$@" $$SIZE $$(( ($$SIZE + 511) / 512 ))

$(STAGE2): core/stage2.asm config/memory.asm config/errors.asm config/policies.asm lib/string.asm lib/math.asm ui/screen.asm ui/log.asm ui/input.asm ui/menu.asm core/sysinfo.asm core/payloads.asm
	@printf '  [ASM]   %s\n' "$<"
	@$(NASM) $(NASMFLAGS) -o $@ $<
	@SIZE=$$(wc -c < $@); \
	if [ $$SIZE -gt 32768 ]; then \
		printf '  [ERR]   %s exceeds 32768 bytes (got %d)\n' "$@" $$SIZE; \
		rm -f $@; exit 1; \
	fi
	@printf '  [OK]    %s (%d bytes, %d sectors)\n' "$@" $$SIZE $$(( ($$SIZE + 511) / 512 ))

$(SANDBOX): core/sandbox.asm config/memory.asm config/errors.asm config/policies.asm core/ivt.asm
	@printf '  [ASM]   %s\n' "$<"
	@$(NASM) $(NASMFLAGS) -o $@ $<
	@SIZE=$$(wc -c < $@); \
	if [ $$SIZE -gt 8192 ]; then \
		printf '  [ERR]   %s exceeds 8192 bytes (got %d)\n' "$@" $$SIZE; \
		rm -f $@; exit 1; \
	fi
	@printf '  [OK]    %s (%d bytes, %d sectors)\n' "$@" $$SIZE $$(( ($$SIZE + 511) / 512 ))

$(THEME): lib/theme.asm config/memory.asm
	@printf '  [ASM]   %s\n' "$<"
	@$(NASM) $(NASMFLAGS) -o $@ $<
	@SIZE=$$(wc -c < $@); \
	if [ $$SIZE -gt 1024 ]; then \
		printf '  [ERR]   %s exceeds 1024 bytes (got %d)\n' "$@" $$SIZE; \
		rm -f $@; exit 1; \
	fi
	@printf '  [OK]    %s (%d bytes, %d sector)\n' "$@" $$SIZE $$(( ($$SIZE + 511) / 512 ))

$(FILTER): lib/filter.asm config/memory.asm
	@printf '  [ASM]   %s\n' "$<"
	@$(NASM) $(NASMFLAGS) -o $@ $<
	@SIZE=$$(wc -c < $@); \
	if [ $$SIZE -gt 1024 ]; then \
		printf '  [ERR]   %s exceeds 1024 bytes (got %d)\n' "$@" $$SIZE; \
		rm -f $@; exit 1; \
	fi
	@printf '  [OK]    %s (%d bytes, %d sector)\n' "$@" $$SIZE $$(( ($$SIZE + 511) / 512 ))

run: $(IMAGE)
	@printf '  [RUN]   Booting in QEMU (curses mode)...\n'
	@printf '          Exit with Ctrl+A, X\n'
	@$(QEMU) -drive format=raw,file=$(IMAGE) -m 4M -cpu pentium -no-reboot -display curses

run-sdl: $(IMAGE)
	@printf '  [RUN]   Booting in QEMU (SDL window)...\n'
	@$(QEMU) -drive format=raw,file=$(IMAGE) -m 4M -cpu pentium -no-reboot -display sdl

debug: $(IMAGE)
	@printf '  [DBG]   QEMU GDB stub on :1234\n'
	@printf '          gdb -ex "target remote :1234" -ex "set architecture i8086"\n'
	@$(QEMU) -drive format=raw,file=$(IMAGE) -m 4M -cpu pentium -no-reboot -display curses -s -S

disasm: $(STAGE1) $(LOADER) $(STAGE2) $(SANDBOX) $(THEME) $(FILTER)
	@printf '\n=== STAGE1 (0x7C00) ===\n'
	@$(NDISASM) -b 16 -o 0x7C00 $(STAGE1)
	@printf '\n=== LOADER (0x7E00) ===\n'
	@$(NDISASM) -b 16 -o 0x7E00 $(LOADER)
	@printf '\n=== STAGE2 (0x10000) ===\n'
	@$(NDISASM) -b 16 -o 0x10000 $(STAGE2)
	@printf '\n=== SANDBOX (0x9000) ===\n'
	@$(NDISASM) -b 16 -o 0x9000 $(SANDBOX)
	@printf '\n=== THEME (0xB000) ===\n'
	@$(NDISASM) -b 16 -o 0xB000 $(THEME)
	@printf '\n=== FILTER (0xC000) ===\n'
	@$(NDISASM) -b 16 -o 0xC000 $(FILTER)

clean:
	@rm -f $(STAGE1) $(LOADER) $(STAGE2) $(SANDBOX) $(THEME) $(FILTER) $(IMAGE)
	@printf '  [OK]    Clean complete.\n'

.PHONY: all check run run-sdl debug disasm clean
