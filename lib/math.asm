%ifndef LIB_MATH_ASM
%define LIB_MATH_ASM

uint_to_str:
    push    ax
    push    bx
    push    cx
    push    dx
    push    si

    mov     si, di
    add     si, 5
    mov     byte [si], 0

    mov     bx, 10
.div:
    xor     dx, dx
    div     bx
    add     dl, '0'
    dec     si
    mov     [si], dl
    test    ax, ax
    jnz     .div

.copy:
    lodsb
    stosb
    test    al, al
    jnz     .copy

    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

hex_nibble_to_ascii:
    and     al, 0x0F
    cmp     al, 9
    jbe     .digit
    add     al, 7
.digit:
    add     al, '0'
    ret

hex_byte_to_str:
    push    ax
    mov     ah, al
    shr     al, 4
    call    hex_nibble_to_ascii
    stosb
    mov     al, ah
    and     al, 0x0F
    call    hex_nibble_to_ascii
    stosb
    pop     ax
    ret

hex_word_to_str:
    push    ax
    mov     al, ah
    call    hex_byte_to_str
    pop     ax
    call    hex_byte_to_str
    ret

%endif
