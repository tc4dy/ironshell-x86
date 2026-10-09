BITS 16
ORG 0x7C00

jmp start
nop
times 59 db 0

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov si, msg
    call print

    mov     ax, 0x0000
    mov     es, ax
    mov     bx, 0x7E00
    mov     ah, 0x02
    mov     al, 4
    mov     ch, 0
    mov     cl, 2
    mov     dh, 0
    mov     dl, 0x80
    int     0x13
    jc      error

    jmp 0x0000:0x7E00

error:
    mov si, msg_error
    call print
    cli
    hlt

print:
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

msg db "Loading...", 0x0D, 0x0A, 0
msg_error db "Disk error!", 0

times 510 - ($ - $$) db 0
dw 0xAA55
