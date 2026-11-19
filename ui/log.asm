%include "config/memory.asm"

%ifndef UI_LOG_ASM
%define UI_LOG_ASM

LOG_LINE_LEN            equ 54
LOG_MAX_LINES           equ 200

log_init:
    pusha
    mov     word [log_line_count], 0
    mov     word [log_scroll_offset], 0
    mov     word [log_partial_col], 0

    mov     di, log_buf
    mov     cx, LOG_MAX_LINES * LOG_LINE_LEN
    xor     al, al
    rep     stosb

    mov     di, log_colors
    mov     cx, LOG_MAX_LINES
    xor     al, al
    rep     stosb

    popa
    ret

log_scroll_shift:
    pusha

    mov     si, log_buf + LOG_LINE_LEN
    mov     di, log_buf
    mov     cx, (LOG_MAX_LINES - 1) * LOG_LINE_LEN
    rep     movsb

    mov     si, log_colors + 1
    mov     di, log_colors
    mov     cx, LOG_MAX_LINES - 1
    rep     movsb

    dec     word [log_line_count]
    cmp     word [log_scroll_offset], 0
    je      .done
    dec     word [log_scroll_offset]

.done:
    popa
    ret

log_new_line:
    pusha

    mov     ax, [log_line_count]
    cmp     ax, LOG_MAX_LINES
    jl      .ok
    call    log_scroll_shift
    mov     ax, [log_line_count]

.ok:
    mov     bx, LOG_LINE_LEN
    mul     bx
    mov     di, log_buf
    add     di, ax
    mov     cx, LOG_LINE_LEN
    mov     al, 0x20
    rep     stosb

    mov     byte [log_buf + di - 1], 0

    mov     word [log_partial_col], 0
    inc     word [log_line_count]

    popa
    ret

log_putc:
    pusha

    cmp     word [log_partial_col], LOG_LINE_LEN - 1
    jge     .done

    mov     ax, [log_line_count]
    test    ax, ax
    jz      .done
    dec     ax

    mov     bx, LOG_LINE_LEN
    mul     bx
    mov     di, log_buf
    add     di, ax
    add     di, [log_partial_col]

    mov     [di], al

    inc     word [log_partial_col]

.done:
    popa
    ret

log_puts:
    pusha
.loop:
    lodsb
    test    al, al
    jz      .done
    call    log_putc
    jmp     .loop
.done:
    popa
    ret

log_puts_colored:
    pusha
    push    bx

    mov     ax, [log_line_count]
    test    ax, ax
    jz      .done

    dec     ax
    mov     bx, ax
    mov     [log_colors + bx], bl

    call    log_puts

.done:
    pop     bx
    popa
    ret

log_add_string:
    pusha
    call    log_new_line
    call    log_puts
    popa
    ret

log_add_string_colored:
    pusha
    push    bx
    call    log_new_line
    call    log_puts
    mov     ax, [log_line_count]
    test    ax, ax
    jz      .done
    dec     ax
    mov     bx, ax
    mov     [log_colors + bx], bl
.done:
    pop     bx
    popa
    ret

log_clear:
    pusha
    mov     word [log_line_count], 0
    mov     word [log_scroll_offset], 0
    mov     word [log_partial_col], 0

    mov     di, log_buf
    mov     cx, LOG_MAX_LINES * LOG_LINE_LEN
    xor     al, al
    rep     stosb

    mov     di, log_colors
    mov     cx, LOG_MAX_LINES
    xor     al, al
    rep     stosb

    popa
    ret

log_scroll_up:
    pusha
    mov     ax, [log_scroll_offset]
    test    ax, ax
    jz      .done
    dec     ax
    mov     [log_scroll_offset], ax
.done:
    popa
    ret

log_scroll_down:
    pusha
    mov     ax, [log_line_count]
    mov     cx, PANEL_END_ROW - PANEL_START_ROW - 1
    sub     ax, cx
    jle     .done
    mov     bx, [log_scroll_offset]
    cmp     bx, ax
    jge     .done
    inc     bx
    mov     [log_scroll_offset], bx
.done:
    popa
    ret

log_line_count      dw 0
log_scroll_offset   dw 0
log_partial_col     dw 0
log_buf             times LOG_MAX_LINES * LOG_LINE_LEN db 0
log_colors          times LOG_MAX_LINES db 0

%endif
