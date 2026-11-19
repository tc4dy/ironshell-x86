%include "config/memory.asm"

%ifndef CORE_IVT_ASM
%define CORE_IVT_ASM

ivt_api:
ivt_api_snapshot:   jmp near ivt_snapshot
ivt_api_diff:       jmp near ivt_diff_restore
ivt_api_clear:      jmp near ivt_clear_snapshot

ivt_snapshot:
    pusha
    push    ds
    push    es

    xor     ax, ax
    mov     ds, ax
    mov     es, ax

    xor     si, si
    mov     di, ivt_snap_buf
    mov     cx, IVT_ENTRY_COUNT * 2
    rep     movsw

    mov     byte [ivt_snap_valid], 1

    pop     es
    pop     ds
    popa
    retf

ivt_diff_restore:
    pusha
    push    ds
    push    es

    cmp     byte [ivt_snap_valid], 1
    jne     .no_snapshot

    xor     ax, ax
    mov     ds, ax
    mov     es, ax

    xor     si, si
    mov     di, ivt_snap_buf
    mov     cx, IVT_ENTRY_COUNT
    xor     bx, bx
    xor     dx, dx

    cli

.check:
    mov     ax, [si]
    cmp     ax, [di]
    jne     .modified
    mov     ax, [si+2]
    cmp     ax, [di+2]
    je      .next_entry

.modified:
    mov     [ivt_last_vec], bx
    mov     ax, [si]
    mov     [ivt_last_new_off], ax
    mov     ax, [si+2]
    mov     [ivt_last_new_seg], ax
    mov     ax, [di]
    mov     [ivt_last_old_off], ax
    mov     ax, [di+2]
    mov     [ivt_last_old_seg], ax

    mov     ax, [di]
    mov     [si], ax
    mov     ax, [di+2]
    mov     [si+2], ax

    inc     dx

.next_entry:
    add     si, IVT_ENTRY_SIZE
    add     di, IVT_ENTRY_SIZE
    inc     bx
    loop    .check

    sti

    mov     [ivt_last_diff_count], dx
    test    dx, dx
    jz      .clean

    stc
    jmp     .done

.clean:
    clc
    jmp     .done

.no_snapshot:
    stc

.done:
    pop     es
    pop     ds
    popa
    retf

ivt_clear_snapshot:
    pusha
    push    es

    xor     ax, ax
    mov     es, ax

    mov     di, ivt_snap_buf
    mov     cx, IVT_ENTRY_COUNT * IVT_ENTRY_SIZE
    xor     al, al
    rep     stosb

    mov     byte [ivt_snap_valid], 0
    mov     word [ivt_last_diff_count], 0

    pop     es
    popa
    retf

ivt_get_last_vec:
    mov     ax, [ivt_last_vec]
    retf

ivt_get_last_diff_count:
    mov     ax, [ivt_last_diff_count]
    retf

ivt_snap_valid         db 0
ivt_last_vec           dw 0
ivt_last_new_off       dw 0
ivt_last_new_seg       dw 0
ivt_last_old_off       dw 0
ivt_last_old_seg       dw 0
ivt_last_diff_count    dw 0
ivt_snap_buf           times IVT_ENTRY_COUNT * IVT_ENTRY_SIZE db 0

%endif
