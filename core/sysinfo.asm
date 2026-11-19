%include "config/memory.asm"

%ifndef CORE_SYSINFO_ASM
%define CORE_SYSINFO_ASM

sysinfo_check_cpuid:
    pushf
    pop     ax
    mov     cx, ax
    xor     ax, 0x0200
    push    ax
    popf
    pushf
    pop     ax
    push    cx
    popf
    cmp     ax, cx
    je      .no_cpuid
    clc
    ret
.no_cpuid:
    stc
    ret

sysinfo_check_a20:
    push    es
    push    di
    push    si
    push    ax

    mov     ax, 0xFFFF
    mov     es, ax
    mov     di, 0x0510
    mov     si, 0x0500

    mov     al, [si]
    push    ax
    mov     al, [es:di]
    push    ax

    mov     byte [si], 0x00
    mov     byte [es:di], 0xFF

    cmp     byte [si], 0xFF

    pop     ax
    mov     [es:di], al
    pop     ax
    mov     [si], al

    pop     ax
    pop     si
    pop     di
    pop     es

    je      .wrap
    clc
    ret
.wrap:
    stc
    ret

sysinfo_e820:
    pusha
    push    es

    xor     ax, ax
    mov     es, ax

    xor     ebx, ebx
    mov     word [E820_COUNT_ADDR], 0
    mov     di, E820_BUF_ADDR

.next_entry:
    mov     eax, 0x0000E820
    mov     ecx, E820_ENTRY_SIZE
    mov     edx, E820_SIGNATURE
    int     0x15

    jc      .fail
    cmp     eax, E820_SIGNATURE
    jne     .fail
    test    cx, cx
    jz      .done

    mov     ax, [E820_COUNT_ADDR]
    cmp     ax, E820_BUF_MAX
    jge     .done

    inc     word [E820_COUNT_ADDR]
    add     di, E820_ENTRY_SIZE

    test    ebx, ebx
    jz      .done
    jmp     .next_entry

.done:
    pop     es
    popa
    clc
    ret

.fail:
    pop     es
    popa
    stc
    ret

sysinfo_conv_mem:
    push    bx
    int     0x12
    jc      .fail
    mov     [CONV_MEM_KB_ADDR], ax
    pop     bx
    clc
    ret
.fail:
    mov     word [CONV_MEM_KB_ADDR], 0
    pop     bx
    stc
    ret

%endif
