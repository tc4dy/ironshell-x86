%include "config/memory.asm"
%include "config/errors.asm"

BITS 16
ORG STAGE1_ORG

stage1_start:
    cli
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, STAGE1_ORG
    sti

    mov     [BOOT_DRIVE_ADDR], dl

    mov     ax, 0x0003
    int     0x10

    mov     ah, 0x01
    mov     cx, 0x2607
    int     0x10

    mov     si, msg_loading
    call    print_string

    mov     ax, LOADER_SEG
    mov     bx, LOADER_OFF
    mov     cx, LOADER_SECTORS
    mov     dx, LOADER_LBA
    call    disk_load_lba
    jc      disk_error

    mov     si, msg_ok
    call    print_string

    mov     dl, [BOOT_DRIVE_ADDR]
    jmp     LOADER_SEG:LOADER_OFF

disk_load_lba:
    pusha

    mov     [dap_seg], ax
    mov     [dap_off], bx
    mov     [dap_count], cx
    mov     [dap_lba_low], dx
    mov     word [dap_lba_mid], 0
    mov     word [dap_lba_hi], 0
    mov     word [dap_lba_hi + 2], 0

    mov     di, 3

.retry:
    mov     ah, 0x42
    mov     dl, [BOOT_DRIVE_ADDR]
    mov     si, dap
    int     0x13
    jnc     .success

    xor     ah, ah
    mov     dl, [BOOT_DRIVE_ADDR]
    int     0x13

    dec     di
    jnz     .retry

    stc
    jmp     .exit

.success:
    clc

.exit:
    popa
    ret

print_string:
    pusha
    mov     ah, 0x0E
    mov     bx, 0x0007
.loop:
    lodsb
    test    al, al
    jz      .done
    int     0x10
    jmp     .loop
.done:
    popa
    ret

disk_error:
    mov     si, msg_disk_error
    call    print_string
    cli
    hlt
    jmp     disk_error

dap:
    db      0x10
    db      0x00
dap_count:
    dw      0x0000
dap_off:
    dw      0x0000
dap_seg:
    dw      0x0000
dap_lba_low:
    dw      0x0000
dap_lba_mid:
    dw      0x0000
dap_lba_hi:
    dd      0x00000000

msg_loading     db "IronShell: Loading...", 0x0D, 0x0A, 0
msg_ok          db "IronShell: Loader OK", 0x0D, 0x0A, 0
msg_disk_error  db "IronShell: Disk error!", 0x0D, 0x0A, 0

times 510 - ($ - $$) db 0
dw 0xAA55
