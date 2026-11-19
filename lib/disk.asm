%ifndef LIB_DISK_ASM
%define LIB_DISK_ASM

disk_load:
    push    bp
    mov     bp, sp
    sub     sp, 10

    mov     [bp-2], ax
    mov     [bp-4], bx
    mov     [bp-6], cx
    mov     [bp-8], dx

.next_sector:
    mov     word [bp-10], 3

.retry:
    mov     ax, [bp-8]
    mov     [dap_lba_low], ax
    mov     word [dap_lba_mid], 0
    mov     word [dap_lba_hi], 0
    mov     word [dap_lba_hi + 2], 0
    mov     ax, [bp-2]
    mov     [dap_seg], ax
    mov     ax, [bp-4]
    mov     [dap_off], ax

    mov     ah, 0x42
    mov     dl, [BOOT_DRIVE_ADDR]
    mov     si, dap
    int     0x13
    jnc     .sector_ok

    xor     ah, ah
    mov     dl, [BOOT_DRIVE_ADDR]
    int     0x13

    dec     word [bp-10]
    jnz     .retry
    jmp     .fail

.sector_ok:
    mov     ax, [bp-4]
    add     ax, 512
    mov     [bp-4], ax
    jnc     .no_seg_fix
    mov     ax, [bp-2]
    add     ax, 0x1000
    mov     [bp-2], ax
.no_seg_fix:
    inc     word [bp-8]
    dec     word [bp-6]
    jnz     .next_sector

    mov     sp, bp
    pop     bp
    clc
    ret

.fail:
    mov     sp, bp
    pop     bp
    stc
    ret

dap:
    db      0x10
    db      0x00
dap_count:
    dw      0x0001
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

%endif
