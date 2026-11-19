%include "config/memory.asm"
%include "lib/disk.asm"

BITS 16
ORG LOADER_ORG

COL_DEFAULT     equ 0x07
COL_HEADER      equ 0x0F
COL_OK          equ 0x0A
COL_WARN        equ 0x0E
COL_ERROR       equ 0x0C
COL_DIM         equ 0x08
COL_BANNER      equ 0x4F
COL_ACCENT      equ 0x0B

loader_start:
    cli
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0x7BFC
    sti

    mov     [BOOT_DRIVE_ADDR], dl

    mov     ax, 0x0003
    int     0x10

    mov     ah, 0x01
    mov     cx, 0x2607
    int     0x10

    call    vga_clear
    call    vga_draw_banner

    mov     si, msg_load_stage2
    mov     bl, COL_OK
    call    status_writeln
    mov     ax, STAGE2_SEG
    mov     bx, STAGE2_OFF
    mov     cx, STAGE2_SECTORS
    mov     dx, STAGE2_LBA
    call    disk_load
    jc      fatal_disk

    mov     si, msg_load_sandbox
    mov     bl, COL_OK
    call    status_writeln
    mov     ax, SANDBOX_SEG
    mov     bx, SANDBOX_OFF
    mov     cx, SANDBOX_SECTORS
    mov     dx, SANDBOX_LBA
    call    disk_load
    jc      fatal_disk

    mov     si, msg_load_theme
    mov     bl, COL_OK
    call    status_writeln
    mov     ax, THEME_SEG
    mov     bx, THEME_OFF
    mov     cx, THEME_SECTORS
    mov     dx, THEME_LBA
    call    disk_load
    jc      fatal_disk

    mov     si, msg_load_filter
    mov     bl, COL_OK
    call    status_writeln
    mov     ax, FILTER_SEG
    mov     bx, FILTER_OFF
    mov     cx, FILTER_SECTORS
    mov     dx, FILTER_LBA
    call    disk_load
    jc      fatal_disk

    mov     si, msg_launch
    mov     bl, COL_HEADER
    call    status_writeln

    call    progress_bar

    mov     dl, [BOOT_DRIVE_ADDR]
    xor     ax, ax
    mov     es, ax
    jmp     STAGE2_SEG:STAGE2_OFF

vga_clear:
    pusha
    push    es
    mov     ax, VGA_SEG
    mov     es, ax
    xor     di, di
    mov     cx, SCREEN_COLS * SCREEN_ROWS
    mov     ax, (COL_DEFAULT << 8) | 0x20
    rep     stosw
    pop     es
    popa
    ret

vga_draw_banner:
    pusha
    push    es
    mov     ax, VGA_SEG
    mov     es, ax

    xor     di, di
    mov     cx, SCREEN_COLS
    mov     ax, (0x40 << 8) | 0x20
    rep     stosw

    mov     di, 4
    mov     si, str_banner
    mov     ah, COL_BANNER
    call    vga_puts

    mov     di, (2 * SCREEN_COLS * 2)
    mov     ax, (COL_DIM << 8) | 0xC9
    stosw
    mov     cx, SCREEN_COLS - 2
    mov     ax, (COL_DIM << 8) | 0xCD
    rep     stosw
    mov     ax, (COL_DIM << 8) | 0xBB
    stosw

    mov     di, (3 * SCREEN_COLS * 2)
    mov     cx, SCREEN_COLS
    mov     ax, (COL_DIM << 8) | 0x20
    rep     stosw

    mov     di, (3 * SCREEN_COLS + 2) * 2
    mov     si, str_banner_sub
    mov     ah, COL_ACCENT
    call    vga_puts

    mov     di, (4 * SCREEN_COLS * 2)
    mov     cx, SCREEN_COLS
    mov     ax, (COL_DIM << 8) | 0xC4
    rep     stosw

    pop     es
    popa
    ret

vga_puts:
    push    si
    push    di
.lp:
    lodsb
    test    al, al
    jz      .done
    mov     [es:di], ax
    add     di, 2
    jmp     .lp
.done:
    pop     di
    pop     si
    ret

status_writeln:
    pusha
    push    es

    xor     ax, ax
    mov     al, [status_row]
    mov     cx, SCREEN_COLS
    mul     cx
    add     ax, 42
    shl     ax, 1
    mov     di, ax

    mov     ax, VGA_SEG
    mov     es, ax

    mov     ah, bl

.lp:
    lodsb
    test    al, al
    jz      .done
    mov     [es:di], ax
    add     di, 2
    jmp     .lp
.done:
    inc     byte [status_row]
    pop     es
    popa
    ret

progress_bar:
    pusha
    push    es
    mov     ax, VGA_SEG
    mov     es, ax

    mov     si, str_progress
    mov     di, (22 * SCREEN_COLS + 2) * 2
    mov     ah, COL_DIM
    call    vga_puts

    mov     cx, 50
    mov     di, (22 * SCREEN_COLS + 18) * 2

.lp:
    push    cx
    mov     ax, (COL_OK << 8) | 0xDB
    mov     [es:di], ax
    add     di, 2

    mov     cx, 0x3FFF
.delay:
    loop    .delay

    pop     cx
    loop    .lp

    pop     es
    popa
    ret

fatal_disk:
    push    es
    mov     ax, VGA_SEG
    mov     es, ax
    mov     si, msg_disk_err
    mov     di, (23 * SCREEN_COLS + 2) * 2
    mov     ah, COL_ERROR
    call    vga_puts
    mov     si, msg_halt
    mov     di, (24 * SCREEN_COLS + 2) * 2
    mov     ah, COL_WARN
    call    vga_puts
    pop     es
.freeze:
    cli
    hlt
    jmp     .freeze

status_row      db 5

str_banner      db "  SX-SANDBOX  |  SHELLCODE EXECUTION ENVIRONMENT  |  v2.1.7  |  x86 BARE-METAL", 0
str_banner_sub  db "Loader v2.1.7  >>  Initializing subsystems...", 0
str_progress    db "LOADING  [", 0

msg_load_stage2   db "[*] Loading execution engine (stage2)...", 0
msg_load_sandbox  db "[*] Loading sandbox protection layer...", 0
msg_load_theme    db "[*] Loading theme engine...", 0
msg_load_filter   db "[*] Loading log filter module...", 0
msg_launch        db "[+] All modules verified. Transferring control...", 0
msg_disk_err      db "[!] FATAL: Disk read failure. Sector unreadable.", 0
msg_halt          db "    System halted. Press RESET to restart.", 0
