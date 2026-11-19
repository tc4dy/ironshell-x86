%include "config/memory.asm"

%ifndef UI_MENU_ASM
%define UI_MENU_ASM

ui_draw_frame:
    pusha
    push    es

    mov     ax, VGA_SEG
    mov     es, ax

    xor     di, di
    mov     cx, SCREEN_COLS * SCREEN_ROWS
    mov     ah, [th_dim]
    mov     al, 0x20
    rep     stosw

    mov     di, TITLE_ROW * VGA_ROW_BYTES
    mov     cx, SCREEN_COLS
    mov     ah, [th_title]
    mov     al, 0x20
    rep     stosw

    mov     di, TITLE_ROW * VGA_ROW_BYTES
    mov     si, str_title
    mov     ah, [th_title]
    call    ui_vga_puts

    mov     di, (TITLE_ROW * SCREEN_COLS + 60) * 2
    mov     si, str_build
    mov     ah, [th_title]
    call    ui_vga_puts

    mov     di, DIVIDER_ROW * VGA_ROW_BYTES
    mov     ah, [th_dim]
    mov     al, 0xC9
    stosw
    mov     cx, SCREEN_COLS - 2
    mov     al, 0xCD
    rep     stosw
    mov     al, 0xBB
    stosw

    mov     di, SUB_ROW * VGA_ROW_BYTES
    mov     cx, SCREEN_COLS
    mov     ah, [th_dim]
    mov     al, 0x20
    rep     stosw

    mov     di, (SUB_ROW * SCREEN_COLS + 1) * 2
    mov     si, str_subtitle
    mov     ah, [th_accent]
    call    ui_vga_puts

    mov     di, DIVIDER2_ROW * VGA_ROW_BYTES
    mov     ah, [th_dim]
    mov     al, 0xC7
    stosw
    mov     cx, SCREEN_COLS - 2
    mov     al, 0xC4
    rep     stosw
    mov     al, 0xB6
    stosw

    mov     bx, PANEL_START_ROW

.borders:
    cmp     bx, PANEL_END_ROW
    jg      .borders_done

    mov     di, bx
    imul    di, di, SCREEN_COLS
    shl     di, 1
    mov     ah, [th_dim]
    mov     al, 0xB3
    stosw

    mov     di, bx
    imul    di, di, SCREEN_COLS
    add     di, LEFT_PANEL_COLS
    shl     di, 1
    stosw

    mov     di, bx
    imul    di, di, SCREEN_COLS
    add     di, LEFT_PANEL_COLS + 1
    shl     di, 1
    mov     al, 0xB3
    stosw

    mov     di, bx
    imul    di, di, SCREEN_COLS
    add     di, 79
    shl     di, 1
    stosw

    inc     bx
    jmp     .borders

.borders_done:
    mov     di, (PANEL_START_ROW * SCREEN_COLS + 1) * 2
    mov     si, str_panel_payloads
    mov     ah, [th_dim]
    call    ui_vga_puts

    mov     di, (PANEL_START_ROW * SCREEN_COLS + RIGHT_PANEL_START + 1) * 2
    mov     si, str_panel_log
    mov     ah, [th_dim]
    call    ui_vga_puts

    mov     di, PANEL_END_ROW * VGA_ROW_BYTES
    mov     ah, [th_dim]
    mov     al, 0xC0
    stosw
    mov     cx, LEFT_PANEL_COLS - 1
    mov     al, 0xC4
    rep     stosw
    mov     al, 0xC1
    stosw
    mov     cx, SCREEN_COLS - LEFT_PANEL_COLS - 3
    mov     al, 0xC4
    rep     stosw
    mov     al, 0xD9
    stosw

    pop     es
    popa
    ret

ui_draw_statusbar:
    pusha
    push    es

    mov     ax, VGA_SEG
    mov     es, ax

    mov     di, STATUS_ROW * VGA_ROW_BYTES
    mov     cx, SCREEN_COLS
    mov     ah, [th_status]
    mov     al, 0x20
    rep     stosw

    mov     di, STATUS_ROW * VGA_ROW_BYTES
    mov     si, str_status
    mov     ah, [th_status]
    call    ui_vga_puts

    pop     es
    popa
    ret

ui_draw_prompt:
    pusha
    push    es

    mov     ax, VGA_SEG
    mov     es, ax

    mov     di, PROMPT_ROW * VGA_ROW_BYTES
    mov     cx, SCREEN_COLS
    mov     ah, [th_dim]
    mov     al, 0x20
    rep     stosw

    mov     di, PROMPT_ROW * VGA_ROW_BYTES
    mov     si, str_prompt
    mov     ah, [th_success]
    call    ui_vga_puts

    mov     ah, 0x02
    mov     bh, 0
    mov     dh, PROMPT_ROW
    mov     dl, 12
    int     0x10

    pop     es
    popa
    ret

ui_redraw_payload_list:
    pusha
    push    es

    mov     ax, VGA_SEG
    mov     es, ax

    mov     bx, PANEL_START_ROW + 1

.clear:
    cmp     bx, PANEL_END_ROW
    jge     .clear_done

    mov     di, bx
    imul    di, di, SCREEN_COLS
    add     di, 1
    shl     di, 1

    mov     cx, LEFT_PANEL_COLS - 1
    mov     ah, [th_dim]
    mov     al, 0x20
    rep     stosw

    inc     bx
    jmp     .clear

.clear_done:
    xor     cx, cx
    mov     bx, PANEL_START_ROW + 1

.entry:
    cmp     cx, [payload_count]
    jge     .done
    cmp     bx, PANEL_END_ROW
    jge     .done

    mov     di, bx
    imul    di, di, SCREEN_COLS
    add     di, 1
    shl     di, 1

    cmp     cx, [selected_idx]
    jne     .normal

    mov     ah, [th_selected]
    mov     al, 0x20
    stosw
    stosw
    mov     ah, [th_selected]
    jmp     .print

.normal:
    add     di, 4
    mov     ah, [th_normal]

    push    bx
    mov     bx, cx
    cmp     byte [payload_flags + bx], 0x02
    pop     bx
    jne     .print
    mov     ah, [th_warn]

.print:
    push    cx
    push    bx

    mov     ax, cx
    mov     bx, PAYLOAD_NAME_LEN
    mul     bx
    mov     si, payload_names
    add     si, ax
    call    ui_vga_puts

    pop     bx
    pop     cx
    inc     cx
    inc     bx
    jmp     .entry

.done:
    pop     es
    popa
    ret

ui_vga_puts:
    push    si
    push    di

.loop:
    lodsb
    test    al, al
    jz      .done
    mov     [es:di], ax
    add     di, 2
    jmp     .loop

.done:
    pop     di
    pop     si
    ret

str_title           db "  SX-SANDBOX  >>  SHELLCODE EXECUTION & ANALYSIS ENVIRONMENT  //  x86 REAL MODE", 0
str_build           db "BUILD 2.1.7", 0
str_subtitle        db "Arch: x86-16  |  Mode: Real  |  BIOS: Legacy INT  |  Target: 0xA000", 0
str_panel_payloads  db "PAYLOADS", 0
str_panel_log       db "EXECUTION LOG", 0
str_status          db "  run  list  sel <n> [arg]  dump  theme <n>  filter <n>  themes  filters  sandbox  help", 0
str_prompt          db "sx-sandbox> ", 0

%endif
