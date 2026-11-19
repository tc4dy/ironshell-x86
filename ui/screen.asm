%include "config/memory.asm"

%ifndef UI_SCREEN_ASM
%define UI_SCREEN_ASM

screen_clear:
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

screen_putc_at:
    push    ax
    push    bx
    push    es
    push    di

    mov     bx, ax
    mov     ax, VGA_SEG
    mov     es, ax

    mov     ax, bx
    mov     di, dx
    shl     di, 1
    mov     [es:di], ax

    pop     di
    pop     es
    pop     bx
    pop     ax
    ret

screen_puts_at:
    pusha
    push    es
    push    di

    mov     ax, VGA_SEG
    mov     es, ax

    mov     di, bx

.loop:
    lodsb
    test    al, al
    jz      .done
    mov     [es:di], ax
    add     di, 2
    jmp     .loop

.done:
    pop     di
    pop     es
    popa
    ret

screen_puts_row_col:
    push    ax
    push    bx
    push    dx

    mov     ax, dx
    mov     bx, SCREEN_COLS
    mul     bx
    add     ax, cx
    shl     ax, 1
    mov     bx, ax

    pop     dx
    pop     bx
    pop     ax

    call    screen_puts_at
    ret

screen_fill_row:
    pusha
    push    es

    mov     ax, VGA_SEG
    mov     es, ax

    mov     ax, bx
    mov     bx, SCREEN_COLS
    mul     bx
    shl     ax, 1
    mov     di, ax

    mov     cx, SCREEN_COLS
    mov     al, dl
    mov     ah, dh
    rep     stosw

    pop     es
    popa
    ret

screen_set_cursor:
    pusha
    mov     ah, 0x02
    xor     bh, bh
    int     0x10
    popa
    ret

screen_get_cursor:
    pusha
    mov     ah, 0x03
    xor     bh, bh
    int     0x10
    popa
    ret

screen_hide_cursor:
    pusha
    mov     ah, 0x01
    mov     cx, 0x2607
    int     0x10
    popa
    ret

screen_show_cursor:
    pusha
    mov     ah, 0x01
    mov     cx, 0x0607
    int     0x10
    popa
    ret

%endif
