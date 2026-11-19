%ifndef LIB_SERIAL_ASM
%define LIB_SERIAL_ASM

COM1_BASE               equ 0x3F8
COM1_DATA               equ COM1_BASE + 0
COM1_IER                equ COM1_BASE + 1
COM1_FCR                equ COM1_BASE + 2
COM1_LCR                equ COM1_BASE + 3
COM1_MCR                equ COM1_BASE + 4
COM1_LSR                equ COM1_BASE + 5

serial_init:
    pusha
    push    dx

    mov     dx, COM1_IER
    xor     al, al
    out     dx, al

    mov     dx, COM1_LCR
    mov     al, 0x80
    out     dx, al

    mov     dx, COM1_DATA
    mov     al, 0x03
    out     dx, al

    mov     dx, COM1_IER
    xor     al, al
    out     dx, al

    mov     dx, COM1_LCR
    mov     al, 0x03
    out     dx, al

    mov     dx, COM1_FCR
    mov     al, 0xC7
    out     dx, al

    mov     dx, COM1_MCR
    mov     al, 0x0B
    out     dx, al

    pop     dx
    popa
    ret

serial_putc:
    pusha
    push    dx

    mov     bl, al

    mov     dx, COM1_LSR

.wait_tx:
    in      al, dx
    test    al, 0x20
    jz      .wait_tx

    mov     dx, COM1_DATA
    mov     al, bl
    out     dx, al

    pop     dx
    popa
    ret

serial_puts:
    pusha
    push    si

.loop:
    lodsb
    test    al, al
    jz      .done
    call    serial_putc
    jmp     .loop

.done:
    pop     si
    popa
    ret

serial_puts_hex_byte:
    pusha
    push    ax

    mov     bl, al
    shr     al, 4
    call    serial_hex_nibble
    mov     al, bl
    and     al, 0x0F
    call    serial_hex_nibble

    pop     ax
    popa
    ret

serial_hex_nibble:
    cmp     al, 9
    jbe     .digit
    add     al, 7
.digit:
    add     al, '0'
    call    serial_putc
    ret

serial_puts_hex_word:
    pusha
    push    ax

    mov     al, ah
    call    serial_puts_hex_byte
    pop     ax
    call    serial_puts_hex_byte

    popa
    ret

serial_newline:
    pusha
    mov     al, 0x0D
    call    serial_putc
    mov     al, 0x0A
    call    serial_putc
    popa
    ret

serial_puts_nl:
    call    serial_puts
    call    serial_newline
    ret

%endif
