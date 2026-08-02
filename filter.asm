BITS 16
ORG 0xC000

FILTER_ALL      equ 0x00
FILTER_INFO     equ 0x01
FILTER_WARN     equ 0x02
FILTER_ERROR    equ 0x03
FILTER_SUCCESS  equ 0x04
FILTER_ACCENT   equ 0x05

COL_SUCCESS     equ 0x0A
COL_ERROR       equ 0x0C
COL_WARN        equ 0x0E
COL_ACCENT      equ 0x0B
COL_DIM         equ 0x08

filter_set:
    cmp     al, FILTER_ACCENT
    ja      .reject
    mov     [active_filter], al
    clc
    ret
.reject:
    stc
    ret

filter_get:
    mov     al, [active_filter]
    ret

filter_match:
    push    bx
    mov     bl, [active_filter]
    cmp     bl, FILTER_ALL
    je      .pass

    cmp     bl, FILTER_INFO
    jne     .chk_warn
    cmp     al, COL_DIM
    je      .pass
    cmp     al, COL_ACCENT
    je      .pass
    jmp     .fail

.chk_warn:
    cmp     bl, FILTER_WARN
    jne     .chk_error
    cmp     al, COL_WARN
    je      .pass
    jmp     .fail

.chk_error:
    cmp     bl, FILTER_ERROR
    jne     .chk_success
    cmp     al, COL_ERROR
    je      .pass
    jmp     .fail

.chk_success:
    cmp     bl, FILTER_SUCCESS
    jne     .chk_accent
    cmp     al, COL_SUCCESS
    je      .pass
    jmp     .fail

.chk_accent:
    cmp     bl, FILTER_ACCENT
    jne     .fail
    cmp     al, COL_ACCENT
    je      .pass
    jmp     .fail

.pass:
    clc
    pop     bx
    ret

.fail:
    stc
    pop     bx
    ret

filter_get_name:
    push    ax
    push    cx
    push    dx
    xor     ah, ah
    mov     cl, [active_filter]
    xor     ch, ch
    mov     ax, cx
    mov     cx, 11
    mul     cx
    mov     si, filter_names
    add     si, ax
    pop     dx
    pop     cx
    pop     ax
    ret

filter_list_entry:
    push    ax
    push    cx
    push    dx
    cmp     al, FILTER_ACCENT
    ja      .bad
    xor     ah, ah
    mov     cx, 11
    mul     cx
    mov     si, filter_names
    add     si, ax
    clc
    pop     dx
    pop     cx
    pop     ax
    ret
.bad:
    stc
    pop     dx
    pop     cx
    pop     ax
    ret

active_filter   db FILTER_ALL

filter_names:
    db "ALL       ", 0
    db "INFO      ", 0
    db "WARN      ", 0
    db "ERROR     ", 0
    db "SUCCESS   ", 0
    db "ACCENT    ", 0

times 1024 - ($ - $$) db 0
