BITS 16
ORG 0xB000

THEME_COLOR     equ 0x0001
THEME_MONO      equ 0x0002
THEME_HACKER    equ 0x0003
THEME_RETRO     equ 0x0004
THEME_STEALTH   equ 0x0005

THEME_COUNT     equ 5

theme_api:
theme_api_set:          jmp near theme_set
theme_api_get:          jmp near theme_get
theme_api_col_normal:   jmp near theme_get_col_normal
theme_api_col_bright:   jmp near theme_get_col_bright
theme_api_col_success:  jmp near theme_get_col_success
theme_api_col_error:    jmp near theme_get_col_error
theme_api_col_warn:     jmp near theme_get_col_warn
theme_api_col_accent:   jmp near theme_get_col_accent
theme_api_col_dim:      jmp near theme_get_col_dim
theme_api_col_selected: jmp near theme_get_col_selected
theme_api_col_title:    jmp near theme_get_col_title
theme_api_col_status:   jmp near theme_get_col_status
theme_api_name:         jmp near theme_get_name
theme_api_list:         jmp near theme_list_entry
theme_api_copy_colors:  jmp near theme_copy_colors

theme_set:
    push    bx
    push    cx
    push    dx
    cmp     al, THEME_COUNT
    ja      .reject
    test    al, al
    jz      .reject
    mov     [active_theme], al
    dec     al
    xor     ah, ah
    mov     cx, 10
    mul     cx
    mov     bx, theme_table
    add     bx, ax
    call    theme_apply
    clc
    pop     dx
    pop     cx
    pop     bx
    retf
.reject:
    stc
    pop     dx
    pop     cx
    pop     bx
    retf

theme_get:
    mov     al, [active_theme]
    retf

theme_get_col_normal:
    push    bx
    call    theme_ptr
    mov     al, [bx + 0]
    pop     bx
    retf

theme_get_col_bright:
    push    bx
    call    theme_ptr
    mov     al, [bx + 1]
    pop     bx
    retf

theme_get_col_success:
    push    bx
    call    theme_ptr
    mov     al, [bx + 2]
    pop     bx
    retf

theme_get_col_error:
    push    bx
    call    theme_ptr
    mov     al, [bx + 3]
    pop     bx
    retf

theme_get_col_warn:
    push    bx
    call    theme_ptr
    mov     al, [bx + 4]
    pop     bx
    retf

theme_get_col_accent:
    push    bx
    call    theme_ptr
    mov     al, [bx + 5]
    pop     bx
    retf

theme_get_col_dim:
    push    bx
    call    theme_ptr
    mov     al, [bx + 6]
    pop     bx
    retf

theme_get_col_selected:
    push    bx
    call    theme_ptr
    mov     al, [bx + 7]
    pop     bx
    retf

theme_get_col_title:
    push    bx
    call    theme_ptr
    mov     al, [bx + 8]
    pop     bx
    retf

theme_get_col_status:
    push    bx
    call    theme_ptr
    mov     al, [bx + 9]
    pop     bx
    retf

theme_ptr:
    push    ax
    push    cx
    mov     al, [active_theme]
    test    al, al
    jz      .default
    dec     al
    xor     ah, ah
    mov     cx, 10
    mul     cx
    mov     bx, theme_table
    add     bx, ax
    pop     cx
    pop     ax
    ret
.default:
    mov     bx, theme_table
    pop     cx
    pop     ax
    ret

theme_apply:
    push    si
    push    di
    push    cx
    mov     si, bx
    mov     di, active_colors
    mov     cx, 10
    rep     movsb
    pop     cx
    pop     di
    pop     si
    ret

theme_get_name:
    push    ax
    push    bx
    push    cx
    mov     al, [active_theme]
    test    al, al
    jz      .default
    dec     al
    xor     ah, ah
    mov     cx, 13
    mul     cx
    mov     bx, theme_names
    add     bx, ax
    mov     si, bx
    pop     cx
    pop     bx
    pop     ax
    retf
.default:
    mov     si, theme_names
    pop     cx
    pop     bx
    pop     ax
    retf

theme_list_entry:
    push    ax
    push    bx
    push    cx
    cmp     al, THEME_COUNT
    jae     .bad
    xor     ah, ah
    mov     cx, 13
    mul     cx
    mov     bx, theme_names
    add     bx, ax
    mov     si, bx
    clc
    pop     cx
    pop     bx
    pop     ax
    retf
.bad:
    stc
    pop     cx
    pop     bx
    pop     ax
    retf

theme_copy_colors:
    push    si
    push    di
    push    cx
    mov     si, active_colors
    mov     cx, 10
    rep     movsb
    pop     cx
    pop     di
    pop     si
    retf

active_theme    db THEME_COLOR
active_colors   times 10 db 0

theme_table:
    db 0x07, 0x0F, 0x0A, 0x0C, 0x0E, 0x0B, 0x08, 0x2F, 0x4F, 0x30
    db 0x07, 0x0F, 0x07, 0x0F, 0x07, 0x0F, 0x08, 0x70, 0x70, 0x07
    db 0x02, 0x0A, 0x0A, 0x0C, 0x02, 0x0A, 0x08, 0x20, 0x0A, 0x02
    db 0x06, 0x0E, 0x0E, 0x0C, 0x06, 0x0E, 0x08, 0x60, 0x6F, 0x60
    db 0x08, 0x07, 0x07, 0x08, 0x08, 0x07, 0x00, 0x07, 0x07, 0x08

theme_names:
    db "COLOR       ", 0
    db "MONO        ", 0
    db "HACKER      ", 0
    db "RETRO       ", 0
    db "STEALTH     ", 0

times 1024 - ($ - $$) db 0
