%include "config/memory.asm"

%ifndef UI_INPUT_ASM
%define UI_INPUT_ASM

INPUT_BUF_SIZE          equ 128
HIST_DEPTH              equ 16
HIST_ENTRY_SIZE         equ 64

input_init:
    pusha
    mov     word [input_len], 0
    mov     word [hist_head], 0
    mov     word [hist_count], 0
    mov     word [hist_cursor], 0

    mov     di, input_buf
    mov     cx, INPUT_BUF_SIZE
    xor     al, al
    rep     stosb

    mov     di, hist_buf
    mov     cx, HIST_DEPTH * HIST_ENTRY_SIZE
    xor     al, al
    rep     stosb

    popa
    ret

input_clear:
    pusha
    mov     di, input_buf
    mov     cx, INPUT_BUF_SIZE
    xor     al, al
    rep     stosb
    mov     word [input_len], 0
    popa
    ret

input_echo_char:
    pusha
    mov     ah, 0x0E
    mov     bh, 0
    mov     bl, 0x07
    int     0x10
    popa
    ret

input_echo_backspace:
    pusha
    mov     ah, 0x0E
    mov     al, 0x08
    int     0x10
    mov     al, 0x20
    int     0x10
    mov     al, 0x08
    int     0x10
    popa
    ret

input_echo_newline:
    pusha
    mov     ah, 0x0E
    mov     al, 0x0D
    int     0x10
    mov     al, 0x0A
    int     0x10
    popa
    ret

hist_push:
    pusha

    mov     ax, [input_len]
    test    ax, ax
    jz      .done

    mov     ax, [hist_head]
    mov     bx, HIST_ENTRY_SIZE
    mul     bx
    mov     di, hist_buf
    add     di, ax

    mov     si, input_buf
    mov     cx, HIST_ENTRY_SIZE - 1
    rep     movsb
    mov     byte [di], 0

    inc     word [hist_head]
    cmp     word [hist_head], HIST_DEPTH
    jl      .ok
    mov     word [hist_head], 0

.ok:
    cmp     word [hist_count], HIST_DEPTH
    jge     .max
    inc     word [hist_count]

.max:
    mov     ax, [hist_head]
    mov     [hist_cursor], ax

.done:
    popa
    ret

hist_prev:
    pusha

    cmp     word [hist_count], 0
    je      .done

    mov     ax, [hist_cursor]
    test    ax, ax
    jz      .wrap
    dec     ax
    jmp     .load

.wrap:
    mov     ax, HIST_DEPTH - 1

.load:
    mov     [hist_cursor], ax

    mov     bx, HIST_ENTRY_SIZE
    mul     bx
    mov     si, hist_buf
    add     si, ax

    mov     di, input_buf
    mov     cx, HIST_ENTRY_SIZE
    rep     movsb

    mov     di, input_buf
    mov     cx, INPUT_BUF_SIZE
    xor     al, al
    repne   scasb
    jne     .max_len

    mov     ax, di
    sub     ax, input_buf
    dec     ax
    cmp     ax, INPUT_BUF_SIZE - 1
    jbe     .set_len

.max_len:
    mov     ax, INPUT_BUF_SIZE - 1

.set_len:
    mov     [input_len], ax

.done:
    popa
    ret

hist_next:
    pusha

    cmp     word [hist_count], 0
    je      .done

    mov     ax, [hist_cursor]
    inc     ax
    cmp     ax, HIST_DEPTH
    jl      .load
    xor     ax, ax

.load:
    mov     [hist_cursor], ax

    mov     bx, HIST_ENTRY_SIZE
    mul     bx
    mov     si, hist_buf
    add     si, ax

    mov     di, input_buf
    mov     cx, HIST_ENTRY_SIZE
    rep     movsb

    mov     di, input_buf
    mov     cx, INPUT_BUF_SIZE
    xor     al, al
    repne   scasb
    jne     .max_len

    mov     ax, di
    sub     ax, input_buf
    dec     ax
    cmp     ax, INPUT_BUF_SIZE - 1
    jbe     .set_len

.max_len:
    mov     ax, INPUT_BUF_SIZE - 1

.set_len:
    mov     [input_len], ax

.done:
    popa
    ret

input_readline:
    pusha

    call    input_clear

    xor     cx, cx
    mov     di, input_buf

.key:
    xor     ah, ah
    int     0x16

    cmp     al, 0x0D
    je      .enter
    cmp     al, 0x08
    je      .backspace
    cmp     al, 0x00
    je      .special

    cmp     cx, INPUT_BUF_SIZE - 1
    jge     .key

    stosb
    inc     cx
    call    input_echo_char
    jmp     .key

.special:
    cmp     ah, 0x48
    je      .hist_up
    cmp     ah, 0x50
    je      .hist_down
    cmp     ah, 0x49
    je      .pgup
    cmp     ah, 0x51
    je      .pgdn
    jmp     .key

.hist_up:
    call    hist_prev
    jmp     .key

.hist_down:
    call    hist_next
    jmp     .key

.pgup:
    call    log_scroll_up
    jmp     .key

.pgdn:
    call    log_scroll_down
    jmp     .key

.backspace:
    test    cx, cx
    jz      .key
    dec     di
    dec     cx
    call    input_echo_backspace
    jmp     .key

.enter:
    mov     byte [di], 0
    mov     [input_len], cx
    call    input_echo_newline
    test    cx, cx
    jz      .done
    call    hist_push

.done:
    popa
    ret

input_len       dw 0
hist_head       dw 0
hist_count      dw 0
hist_cursor     dw 0
input_buf       times INPUT_BUF_SIZE db 0
hist_buf        times HIST_DEPTH * HIST_ENTRY_SIZE db 0

%endif
