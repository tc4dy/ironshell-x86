NASM     := nasm
QEMU     := qemu-system-i386
DD       := dd
NDISASM  := ndisasm

IMAGE    := sx-sandbox.img
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

STAGE1_MAX_BYTES  := 512
LOADER_MAX_BYTES  := 6144
STAGE2_MAX_BYTES  := 32768
SANDBOX_MAX_BYTES := 8192
THEME_MAX_BYTES   := 1024
FILTER_MAX_BYTES  := 1024

QEMU_BASE := -drive format=raw,file=$(IMAGE) \
             -m 4M \
             -cpu pentium \
             -no-reboot \
             -no-shutdown

QEMU_CURSES := $(QEMU_BASE) -display curses
QEMU_SDL    := $(QEMU_BASE) -display sdl
QEMU_DEBUG  := $(QEMU_BASE) -display curses -s -S

.PHONY: all clean run run-sdl debug disasm check help

all: check $(IMAGE)
	@printf '\n  Build complete: %s\n  Run: make run\n\n' "$(IMAGE)"

$(IMAGE): $(STAGE1) $(LOADER) $(STAGE2) $(SANDBOX) $(THEME) $(FILTER)
	@printf '  [IMG] Creating blank disk (%d sectors)...\n' $(SECTORS)
	@$(DD) if=/dev/zero of=$(IMAGE) bs=512 count=$(SECTORS) status=none
	@printf '  [IMG] Writing %-8s -> sector %d\n' "$(STAGE1)" $(STAGE1_SECTOR)
	@$(DD) if=$(STAGE1) of=$(IMAGE) bs=512 seek=$(STAGE1_SECTOR) conv=notrunc status=none
	@printf '  [IMG] Writing %-8s -> sector %d\n' "$(LOADER)" $(LOADER_SECTOR)
	@$(DD) if=$(LOADER) of=$(IMAGE) bs=512 seek=$(LOADER_SECTOR) conv=notrunc status=none
	@printf '  [IMG] Writing %-8s -> sector %d\n' "$(STAGE2)" $(STAGE2_SECTOR)
	@$(DD) if=$(STAGE2) of=$(IMAGE) bs=512 seek=$(STAGE2_SECTOR) conv=notrunc status=none
	@printf '  [IMG] Writing %-8s -> sector %d\n' "$(SANDBOX)" $(SANDBOX_SECTOR)
	@$(DD) if=$(SANDBOX) of=$(IMAGE) bs=512 seek=$(SANDBOX_SECTOR) conv=notrunc status=none
	@printf '  [IMG] Writing %-8s -> sector %d\n' "$(THEME)" $(THEME_SECTOR)
	@$(DD) if=$(THEME) of=$(IMAGE) bs=512 seek=$(THEME_SECTOR) conv=notrunc status=none
	@printf '  [IMG] Writing %-8s -> sector %d\n' "$(FILTER)" $(FILTER_SECTOR)
	@$(DD) if=$(FILTER) of=$(IMAGE) bs=512 seek=$(FILTER_SECTOR) conv=notrunc status=none
	@printf '  [OK]  Disk image ready.\n'

$(STAGE1): stage1.asm
	@printf '  [ASM] %s\n' "$<"
	@$(NASM) -f bin -o $@ $<
	@SIZE=$$(wc -c < $@); \
	  if [ $$SIZE -ne $(STAGE1_MAX_BYTES) ]; then \
	    printf '  [ERR] %s must be exactly %d bytes (got %d)\n' "$@" $(STAGE1_MAX_BYTES) $$SIZE; \
	    rm -f $@; exit 1; \
	  fi
	@printf '  [OK]  %-12s %d bytes (MBR)\n' "$@" $(STAGE1_MAX_BYTES)

$(LOADER): loader.asm
	@printf '  [ASM] %s\n' "$<"
	@$(NASM) -f bin -o $@ $<
	@SIZE=$$(wc -c < $@); \
	  printf '  [OK]  %-12s %d bytes (%d sectors)\n' "$@" $$SIZE $$((SIZE / 512)); \
	  if [ $$SIZE -gt $(LOADER_MAX_BYTES) ]; then \
	    printf '  [ERR] %s exceeds %d byte reservation\n' "$@" $(LOADER_MAX_BYTES); \
	    rm -f $@; exit 1; \
	  fi

$(STAGE2): stage2.asm
	@printf '  [ASM] %s\n' "$<"
	@$(NASM) -f bin -o $@ $<
	@SIZE=$$(wc -c < $@); \
	  printf '  [OK]  %-12s %d bytes (%d sectors)\n' "$@" $$SIZE $$((SIZE / 512)); \
	  if [ $$SIZE -gt $(STAGE2_MAX_BYTES) ]; then \
	    printf '  [ERR] %s exceeds %d byte reservation\n' "$@" $(STAGE2_MAX_BYTES); \
	    rm -f $@; exit 1; \
	  fi

$(SANDBOX): sandbox.asm
	@printf '  [ASM] %s\n' "$<"
	@$(NASM) -f bin -o $@ $<
	@SIZE=$$(wc -c < $@); \
	  printf '  [OK]  %-12s %d bytes (%d sectors)\n' "$@" $$SIZE $$((SIZE / 512)); \
	  if [ $$SIZE -gt $(SANDBOX_MAX_BYTES) ]; then \
	    printf '  [ERR] %s exceeds %d byte reservation\n' "$@" $(SANDBOX_MAX_BYTES); \
	    rm -f $@; exit 1; \
	  fi

$(THEME): theme.asm
	@printf '  [ASM] %s\n' "$<"
	@$(NASM) -f bin -o $@ $<
	@SIZE=$$(wc -c < $@); \
	  printf '  [OK]  %-12s %d bytes (%d sectors)\n' "$@" $$SIZE $$((SIZE / 512)); \
	  if [ $$SIZE -gt $(THEME_MAX_BYTES) ]; then \
	    printf '  [ERR] %s exceeds %d byte reservation\n' "$@" $(THEME_MAX_BYTES); \
	    rm -f $@; exit 1; \
	  fi

$(FILTER): filter.asm
	@printf '  [ASM] %s\n' "$<"
	@$(NASM) -f bin -o $@ $<
	@SIZE=$$(wc -c < $@); \
	  printf '  [OK]  %-12s %d bytes (%d sectors)\n' "$@" $$SIZE $$((SIZE / 512)); \
	  if [ $$SIZE -gt $(FILTER_MAX_BYTES) ]; then \
	    printf '  [ERR] %s exceeds %d byte reservation\n' "$@" $(FILTER_MAX_BYTES); \
	    rm -f $@; exit 1; \
	  fi

run: $(IMAGE)
	$(QEMU) $(QEMU_CURSES)

run-sdl: $(IMAGE)
	$(QEMU) $(QEMU_SDL)

debug: $(IMAGE)
	@printf '  [DBG] GDB stub on :1234\n'
	@printf '        gdb -ex "target remote :1234" -ex "set architecture i8086"\n'
	@printf '        Then: break *0x7c00   continue\n'
	$(QEMU) $(QEMU_DEBUG)

disasm: $(STAGE1) $(LOADER) $(STAGE2) $(SANDBOX) $(THEME) $(FILTER)
	@printf '\n=== STAGE1 (0x7C00) ===\n'
	@$(NDISASM) -b 16 -o 0x7C00 $(STAGE1)
	@printf '\n=== LOADER (0x7E00) ===\n'
	@$(NDISASM) -b 16 -o 0x7E00 $(LOADER)
	@printf '\n=== STAGE2 (0x8000) ===\n'
	@$(NDISASM) -b 16 -o 0x8000 $(STAGE2)
	@printf '\n=== SANDBOX (0x9000) ===\n'
	@$(NDISASM) -b 16 -o 0x9000 $(SANDBOX)
	@printf '\n=== THEME (0xB000) ===\n'
	@$(NDISASM) -b 16 -o 0xB000 $(THEME)
	@printf '\n=== FILTER (0xC000) ===\n'
	@$(NDISASM) -b 16 -o 0xC000 $(FILTER)

check:
	@command -v $(NASM)    >/dev/null 2>&1 || { printf '  [ERR] nasm not found\n';            exit 1; }
	@command -v $(QEMU)    >/dev/null 2>&1 || { printf '  [ERR] qemu-system-i386 not found\n'; exit 1; }
	@command -v $(DD)      >/dev/null 2>&1 || { printf '  [ERR] dd not found\n';              exit 1; }
	@command -v $(NDISASM) >/dev/null 2>&1 || { printf '  [ERR] ndisasm not found\n';         exit 1; }
	@printf '  [OK]  Tools: nasm qemu-system-i386 dd ndisasm\n'

clean:
	@rm -f $(STAGE1) $(LOADER) $(STAGE2) $(SANDBOX) $(THEME) $(FILTER) $(IMAGE)
	@printf '  [OK]  Clean complete.\n'

help:
	@printf '\n  SX-SANDBOX Build System\n'
	@printf '  ────────────────────────────────────────\n'
	@printf '  make           Build all and assemble disk image\n'
	@printf '  make run       Launch in QEMU (curses/terminal)\n'
	@printf '  make run-sdl   Launch in QEMU (SDL window)\n'
	@printf '  make debug     QEMU + GDB stub on :1234\n'
	@printf '  make disasm    Disassemble all binaries (ndisasm)\n'
	@printf '  make clean     Remove build artifacts\n'
	@printf '\n  Memory Layout:\n'
	@printf '  0x7C00  stage1.asm    MBR (1 sector, LBA 0)\n'
	@printf '  0x7E00  loader.asm    Loader (12 sectors, LBA 1)\n'
	@printf '  0x8000  stage2.asm    Shell + engine (64 sectors, LBA 3)\n'
	@printf '  0x9000  sandbox.asm   Protection layer (16 sectors, LBA 67)\n'
	@printf '  0xA000  shellcode     Runtime injection target (LBA 83)\n'
	@printf '  0xB000  theme.asm     Theme engine (2 sectors, LBA 87)\n'
	@printf '  0xC000  filter.asm    Log filter (2 sectors, LBA 89)\n'
	@printf '\n  Shell Commands:\n'
	@printf '  run              Execute selected payload\n'
	@printf '  list             List payload modules\n'
	@printf '  sel <n>          Select payload by index\n'
	@printf '  sandbox          Re-run environment checks\n'
	@printf '  dump <hex>       Hexdump 32 bytes at address\n'
	@printf '  info             System module info\n'
	@printf '  clear            Clear log panel\n'
	@printf '  theme <1-5>      Set color theme\n'
	@printf '  themes           List all themes\n'
	@printf '  filter <0-5>     Set log filter\n'
	@printf '  filters          List all filters\n'
	@printf '  errors           Show last error\n'
	@printf '  help             This message\n\n'
