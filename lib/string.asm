%ifndef LIB_STRING_ASM
%define LIB_STRING_ASM

to_upper:
    cmp     al, 'a'
    jb      .done
    cmp     al, 'z'
    ja      .done
    sub     al, 0x20
.done:
    ret

strcmp_ci:
    push    si
    push    di
.loop:
    mov     al, [si]
    mov     bl, [di]
    call    to_upper
    push    ax
    mov     al, bl
    call    to_upper
    mov     bl, al
    pop     ax
    cmp     al, bl
    jne     .ne
    test    al, al
    jz      .eq
    inc     si
    inc     di
    jmp     .loop
.eq:
    pop     di
    pop     si
    xor     ax, ax
    ret
.ne:
    pop     di
    pop     si
    or      ax, 1
    ret

strcmp_pfx:
    push    si
    push    di
.loop:
    mov     bl, [di]
    test    bl, bl
    jz      .match
    mov     al, [si]
    call    to_upper
    push    ax
    mov     al, bl
    call    to_upper
    mov     bl, al
    pop     ax
    cmp     al, bl
    jne     .ne
    inc     si
    inc     di
    jmp     .loop
.match:
    pop     di
    pop     si
    xor     ax, ax
    ret
.ne:
    pop     di
    pop     si
    or      ax, 1
    ret

strcpy_bounded:
    push    cx
.loop:
    test    cx, cx
    jz      .term
    lodsb
    stosb
    test    al, al
    jz      .done
    dec     cx
    jmp     .loop
.term:
    mov     byte [di], 0
    inc     di
.done:
    pop     cx
    ret

str_len:
    push    si
    xor     cx, cx
.loop:
    cmp     byte [si], 0
    je      .done
    inc     si
    inc     cx
    jmp     .loop
.done:
    pop     si
    ret

skip_spaces_si:
    cmp     byte [si], 0x20
    jne     .done
    inc     si
    jmp     skip_spaces_si
.done:
    ret

skip_cmd_token_si:
    mov     al, [si]
    test    al, al
    jz      .done
    cmp     al, 0x20
    je      .done
    inc     si
    jmp     skip_cmd_token_si
.done:
    ret

skip_decimal_si:
    mov     al, [si]
    cmp     al, '0'
    jb      .done
    cmp     al, '9'
    ja      .done
    inc     si
    jmp     skip_decimal_si
.done:
    ret

parse_decimal_si:
    push    si
    xor     ax, ax
    xor     cx, cx
.loop:
    mov     bl, [si]
    cmp     bl, '0'
    jb      .done
    cmp     bl, '9'
    ja      .done
    sub     bl, '0'
    push    bx
    mov     bx, 10
    mul     bx
    pop     bx
    xor     bh, bh
    add     ax, bx
    inc     si
    inc     cx
    jmp     .loop
.done:
    test    cx, cx
    jz      .fail
    pop     si
    clc
    ret
.fail:
    pop     si
    stc
    ret

parse_hex_word_si:
    push    si
    xor     ax, ax
    xor     cx, cx
.loop:
    mov     bl, [si]
    call    hex_nibble
    jc      .done
    shl     ax, 4
    or      al, bl
    inc     si
    inc     cx
    jmp     .loop
.done:
    test    cx, cx
    jz      .fail
    pop     si
    clc
    ret
.fail:
    pop     si
    stc
    ret

hex_nibble:
    cmp     bl, '0'
    jb      .bad
    cmp     bl, '9'
    ja      .alpha
    sub     bl, '0'
    clc
    ret
.alpha:
    or      bl, 0x20
    cmp     bl, 'a'
    jb      .bad
    cmp     bl, 'f'
    ja      .bad
    sub     bl, 0x57
    clc
    ret
.bad:
    stc
    ret

%endif
