%include "config/memory.asm"
%include "config/errors.asm"

%ifndef CORE_PAYLOADS_ASM
%define CORE_PAYLOADS_ASM

payload_dispatch:
    cmp     ax, 0
    je      payload_msgbox
    cmp     ax, 1
    je      payload_memwalk
    cmp     ax, 2
    je      payload_portprobe
    cmp     ax, 3
    je      payload_stacksmash
    cmp     ax, 4
    je      payload_nxprobe
    cmp     ax, 5
    je      payload_cpuinfo
    cmp     ax, 6
    je      payload_ivtdump
    cmp     ax, 7
    je      payload_memmap
    stc
    ret

payload_msgbox:
    pusha
    push    es

    xor     ax, ax
    mov     es, ax

    mov     si, str_msgbox_hdr
    mov     bl, [th_success]
    call    log_colored

    mov     word [es:SHELLCODE_BASE + 0], 0xC0B8
    mov     word [es:SHELLCODE_BASE + 2], 0xC307

    mov     si, str_injected
    mov     bl, [th_accent]
    call    log_colored

    call    SHELLCODE_BASE

    mov     si, str_returned
    mov     bl, [th_success]
    call    log_colored

    pop     es
    popa
    clc
    ret

payload_memwalk:
    pusha
    push    es

    xor     ax, ax
    mov     es, ax

    mov     si, str_memwalk_hdr
    mov     bl, [th_success]
    call    log_colored

    mov     cx, 16
    mov     bx, 0x0400

.row:
    push    cx
    push    bx

    mov     si, str_pfx_addr
    call    log_partial
    mov     ax, bx
    call    emit_hex_word

    mov     si, str_colon_sp
    call    log_partial

    mov     ax, [es:bx]
    call    emit_hex_word_nl

    pop     bx
    add     bx, 2
    pop     cx
    loop    .row

    pop     es
    popa
    clc
    ret

payload_portprobe:
    pusha

    mov     si, str_port_hdr
    mov     bl, [th_success]
    call    log_colored

    mov     ax, [selected_idx]
    mov     bx, PAYLOAD_ARG_LEN
    mul     bx
    mov     si, payload_args
    add     si, ax
    cmp     byte [si], 0
    je      .default_port

    call    skip_spaces_si
    call    parse_hex_word_si
    jc      .default_port
    mov     [port_base], ax
    jmp     .probe

.default_port:
    mov     word [port_base], 0x03F8

.probe:
    mov     cx, 8
    mov     dx, [port_base]

.row:
    push    cx
    push    dx

    in      al, dx
    mov     bl, al

    mov     si, str_pfx_port
    call    log_partial
    pop     dx
    push    dx
    mov     ax, dx
    call    emit_hex_word
    mov     si, str_arrow
    call    log_partial
    mov     al, bl
    call    emit_hex_byte_nl

    pop     dx
    add     dx, 8
    pop     cx
    loop    .row

    popa
    clc
    ret

payload_stacksmash:
    pusha

    mov     si, str_stack_hdr
    mov     bl, [th_warn]
    call    log_colored

    mov     ax, ss
    push    ax
    mov     si, str_pfx_ss
    call    log_partial
    pop     ax
    call    emit_hex_word_nl

    mov     ax, sp
    push    ax
    mov     si, str_pfx_sp
    call    log_partial
    pop     ax
    call    emit_hex_word_nl

    mov     ax, [selected_idx]
    mov     bx, PAYLOAD_ARG_LEN
    mul     bx
    mov     si, payload_args
    add     si, ax
    cmp     byte [si], 0
    je      .default_depth

    call    skip_spaces_si
    call    parse_decimal_si
    jc      .default_depth
    cmp     ax, 0
    je      .default_depth
    cmp     ax, 16
    ja      .default_depth
    mov     [canary_depth], ax
    jmp     .do_canary

.default_depth:
    mov     word [canary_depth], 4

.do_canary:
    mov     si, str_canary_write
    mov     bl, [th_warn]
    call    log_colored

    mov     cx, [canary_depth]
    test    cx, cx
    jz      .corrupt

.push_canary:
    push    word 0xDEAD
    loop    .push_canary

    mov     cx, [canary_depth]
.check_canary:
    pop     ax
    cmp     ax, 0xDEAD
    jne     .corrupt
    loop    .check_canary

    mov     si, str_stack_ok
    mov     bl, [th_success]
    call    log_colored
    popa
    clc
    ret

.corrupt:
    mov     word [last_error], ERR_SANDBOX_BLOCK
    mov     si, str_stack_corrupt
    call    log_error_msg
    popa
    stc
    ret

payload_nxprobe:
    pusha

    mov     si, str_nx_hdr
    mov     bl, [th_success]
    call    log_colored

    cmp     byte [nx_active], 1
    je      .nx_present

    push    es
    xor     ax, ax
    mov     es, ax
    mov     byte [es:SHELLCODE_BASE], 0xC3
    pop     es

    mov     si, str_nx_exec
    mov     bl, [th_success]
    call    log_colored

    call    SHELLCODE_BASE

    mov     si, str_nx_done
    mov     bl, [th_success]
    call    log_colored
    popa
    clc
    ret

.nx_present:
    mov     si, str_nx_blocked
    mov     bl, [th_warn]
    call    log_colored
    popa
    clc
    ret

payload_cpuinfo:
    pusha

    mov     si, str_cpu_hdr
    mov     bl, [th_success]
    call    log_colored

    call    sysinfo_check_cpuid
    jc      .no_cpuid

    mov     eax, 0x80000000
    cpuid
    cmp     eax, 0x80000004
    jb      .no_brand

    mov     eax, 0x80000002
    cpuid
    mov     [cpu_brand],      eax
    mov     [cpu_brand + 4],  ebx
    mov     [cpu_brand + 8],  ecx
    mov     [cpu_brand + 12], edx

    mov     eax, 0x80000003
    cpuid
    mov     [cpu_brand + 16], eax
    mov     [cpu_brand + 20], ebx
    mov     [cpu_brand + 24], ecx
    mov     [cpu_brand + 28], edx

    mov     eax, 0x80000004
    cpuid
    mov     [cpu_brand + 32], eax
    mov     [cpu_brand + 36], ebx
    mov     [cpu_brand + 40], ecx
    mov     [cpu_brand + 44], edx
    mov     byte [cpu_brand + 48], 0

    mov     si, str_pfx_brand
    call    log_partial
    mov     si, cpu_brand
    mov     bl, [th_bright]
    call    log_colored
    jmp     .features

.no_brand:
    mov     si, str_no_brand
    mov     bl, [th_dim]
    call    log_colored
    jmp     .done

.no_cpuid:
    mov     si, str_cpuid_none
    mov     bl, [th_warn]
    call    log_colored
    jmp     .done

.features:
    mov     eax, 1
    cpuid

    mov     si, str_pfx_step
    call    log_partial
    push    eax
    and     ax, 0x0F
    call    log_decimal
    call    emit_newline
    pop     eax

    test    edx, (1 << 25)
    jz      .no_sse
    mov     si, str_feat_sse
    mov     bl, [th_success]
    call    log_colored
.no_sse:
    test    edx, (1 << 26)
    jz      .no_sse2
    mov     si, str_feat_sse2
    mov     bl, [th_success]
    call    log_colored
.no_sse2:
    test    ecx, (1 << 28)
    jz      .done
    mov     si, str_feat_avx
    mov     bl, [th_success]
    call    log_colored

.done:
    popa
    clc
    ret

payload_ivtdump:
    pusha
    push    es

    xor     ax, ax
    mov     es, ax

    mov     si, str_ivt_hdr
    mov     bl, [th_success]
    call    log_colored

    mov     ax, [selected_idx]
    mov     bx, PAYLOAD_ARG_LEN
    mul     bx
    mov     si, payload_args
    add     si, ax
    cmp     byte [si], 0
    je      .default_count

    call    skip_spaces_si
    call    parse_decimal_si
    jc      .default_count
    cmp     ax, 0
    je      .default_count
    cmp     ax, 256
    ja      .default_count
    mov     [ivt_dump_count], ax
    jmp     .do_dump

.default_count:
    mov     word [ivt_dump_count], 16

.do_dump:
    xor     bx, bx
    mov     cx, [ivt_dump_count]

.row:
    push    cx
    push    bx

    mov     si, str_pfx_vec
    call    log_partial
    mov     ax, bx
    call    emit_hex_byte_inline

    mov     si, str_colon_sp
    call    log_partial

    mov     ax, [es:bx]
    call    emit_hex_word
    mov     si, str_colon_sp
    call    log_partial
    mov     ax, [es:bx+2]
    call    emit_hex_word_nl

    pop     bx
    add     bx, 4
    pop     cx
    loop    .row

    pop     es
    popa
    clc
    ret

payload_memmap:
    pusha

    mov     si, str_memmap_hdr
    mov     bl, [th_success]
    call    log_colored

    call    sysinfo_e820
    jc      .e820_fail

    mov     cx, [E820_COUNT_ADDR]
    test    cx, cx
    jz      .e820_fail

    mov     si, str_e820_entries
    call    log_partial
    mov     ax, [E820_COUNT_ADDR]
    call    log_decimal
    call    emit_newline

    mov     bx, 0
    mov     di, E820_BUF_ADDR

.print_loop:
    cmp     bx, [E820_COUNT_ADDR]
    jge     .print_done

    push    bx
    push    di

    mov     si, str_e820_base
    call    log_partial
    mov     ax, [di + 2]
    call    emit_hex_word
    mov     ax, [di + 0]
    call    emit_hex_word

    mov     si, str_e820_len
    call    log_partial
    mov     ax, [di + 6]
    call    emit_hex_word
    mov     ax, [di + 4]
    call    emit_hex_word

    mov     si, str_e820_type
    call    log_partial

    mov     ax, [di + 16]
    cmp     ax, 1
    je      .type_usable
    cmp     ax, 2
    je      .type_reserved
    cmp     ax, 3
    je      .type_acpi
    cmp     ax, 4
    je      .type_acpi_nvs
    cmp     ax, 5
    je      .type_bad
    mov     si, str_e820_type_unk
    jmp     .type_done

.type_usable:
    mov     si, str_e820_type_use
    jmp     .type_done
.type_reserved:
    mov     si, str_e820_type_res
    jmp     .type_done
.type_acpi:
    mov     si, str_e820_type_acpi
    jmp     .type_done
.type_acpi_nvs:
    mov     si, str_e820_type_nvs
    jmp     .type_done
.type_bad:
    mov     si, str_e820_type_bad

.type_done:
    call    log_partial
    call    emit_newline

    pop     di
    pop     bx
    add     di, E820_ENTRY_SIZE
    inc     bx
    jmp     .print_loop

.print_done:
    popa
    clc
    ret

.e820_fail:
    mov     word [last_error], ERR_E820_FAIL
    mov     si, str_e820_fail
    call    log_error_msg

    call    sysinfo_conv_mem
    jc      .ram_fail

    mov     si, str_e820_fallback
    mov     bl, [th_warn]
    call    log_colored

    mov     si, str_ram_pfx
    call    log_partial
    mov     ax, [CONV_MEM_KB_ADDR]
    call    log_decimal
    mov     si, str_kb
    mov     bl, [th_dim]
    call    log_colored

    popa
    clc
    ret

.ram_fail:
    mov     si, str_e820_no_mem
    call    log_error_msg
    popa
    stc
    ret

%endif
