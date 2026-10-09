BITS 16
ORG 0x8000

SANDBOX_ENTRY equ 0x9000
SHELLCODE_BASE          equ 0xA000
THEME_BASE              equ 0xB000
FILTER_BASE             equ 0xC000

MAX_PAYLOADS            equ 12
PAYLOAD_NAME_LEN        equ 32
PAYLOAD_ARG_LEN         equ 64

INPUT_BUF_SIZE          equ 128

HIST_DEPTH              equ 16
HIST_ENTRY_SIZE         equ 64

LOG_LINE_LEN            equ 54
LOG_MAX_LINES           equ 200

VGA_SEG                 equ 0xB800
SCREEN_ROWS             equ 25
SCREEN_COLS             equ 80
VGA_ROW_BYTES           equ 160

TITLE_ROW               equ 0
DIVIDER_ROW             equ 2
SUB_ROW                 equ 3
DIVIDER2_ROW            equ 4
PANEL_START_ROW         equ 6
PANEL_END_ROW           equ 22
PROMPT_ROW              equ 23
STATUS_ROW              equ 24

LEFT_PANEL_COLS         equ 24
RIGHT_PANEL_START       equ 25

COL_NORMAL              equ 0x07
COL_BRIGHT              equ 0x0F
COL_SUCCESS             equ 0x0A
COL_ERROR               equ 0x0C
COL_WARN                equ 0x0E
COL_ACCENT              equ 0x0B
COL_DIM                 equ 0x08
COL_SELECTED            equ 0x2F
COL_TITLE               equ 0x4F
COL_STATUS              equ 0x30

E820_BUF_MAX            equ 32
E820_ENTRY_SIZE         equ 20

ERR_NONE                equ 0x00
ERR_DISK                equ 0x01
ERR_BOUNDS              equ 0x02
ERR_SANDBOX_BLOCK       equ 0x03
ERR_BAD_ARG             equ 0x04
ERR_OOB                 equ 0x05
ERR_NO_PAYLOAD          equ 0x06
ERR_BAD_ADDR            equ 0x07
ERR_THEME_INVALID       equ 0x08
ERR_FILTER_INVALID      equ 0x09
ERR_E820_FAIL           equ 0x0A

stage2_main:
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax
    mov     sp, 0x7BFC

    mov     [engine_drive], dl
    mov     word [last_error], ERR_NONE

    call    init_payloads
    call    theme_init_defaults
    call    ui_full_redraw
    call    run_env_checks
    call    shell_loop

    cli
    hlt
    jmp     $

theme_init_defaults:
    push    es
    xor     ax, ax
    mov     es, ax
    pusha
    mov     byte [th_normal],   COL_NORMAL
    mov     byte [th_bright],   COL_BRIGHT
    mov     byte [th_success],  COL_SUCCESS
    mov     byte [th_error],    COL_ERROR
    mov     byte [th_warn],     COL_WARN
    mov     byte [th_accent],   COL_ACCENT
    mov     byte [th_dim],      COL_DIM
    mov     byte [th_selected], COL_SELECTED
    mov     byte [th_title],    COL_TITLE
    mov     byte [th_status],   COL_STATUS
    popa
    pop     es
    ret

theme_apply_color:
    pusha
    push    ds
    push    es
    xor     dx, dx
    mov     ds, dx
    mov     es, dx
    call    far [.theme_set_ptr]
    jc      .bad
    mov     di, th_normal
    call    far [.copy_colors_ptr]
    pop     es
    pop     ds
    popa
    clc
    ret
.bad:
    pop     es
    pop     ds
    popa
    stc
    ret
.theme_set_ptr:
    dw  THEME_BASE + 0, 0x0000
.copy_colors_ptr:
    dw  THEME_BASE + 42, 0x0000

init_payloads:
    push    es
    xor     ax, ax
    mov     es, ax
    pusha
    mov     di, payload_names
    mov     cx, MAX_PAYLOADS * PAYLOAD_NAME_LEN
    xor     al, al
    rep     stosb

    mov     di, payload_args
    mov     cx, MAX_PAYLOADS * PAYLOAD_ARG_LEN
    xor     al, al
    rep     stosb

    mov     word [payload_count], 0
    mov     word [selected_idx], 0
    mov     word [log_line_count], 0
    mov     word [log_scroll_offset], 0
    mov     word [hist_head], 0
    mov     word [hist_count], 0
    mov     word [hist_cursor], 0
    mov     word [partial_col], 0
    mov     word [last_error], ERR_NONE

    mov     si, str_pl_msgbox
    mov     di, payload_names + 0 * PAYLOAD_NAME_LEN
    call    strcpy_bounded_name
    mov     byte [payload_flags + 0], 0x01

    mov     si, str_pl_memwalk
    mov     di, payload_names + 1 * PAYLOAD_NAME_LEN
    call    strcpy_bounded_name
    mov     byte [payload_flags + 1], 0x01

    mov     si, str_pl_portprobe
    mov     di, payload_names + 2 * PAYLOAD_NAME_LEN
    call    strcpy_bounded_name
    mov     byte [payload_flags + 2], 0x01

    mov     si, str_pl_stacksmash
    mov     di, payload_names + 3 * PAYLOAD_NAME_LEN
    call    strcpy_bounded_name
    mov     byte [payload_flags + 3], 0x02

    mov     si, str_pl_nxprobe
    mov     di, payload_names + 4 * PAYLOAD_NAME_LEN
    call    strcpy_bounded_name
    mov     byte [payload_flags + 4], 0x01

    mov     si, str_pl_cpuinfo
    mov     di, payload_names + 5 * PAYLOAD_NAME_LEN
    call    strcpy_bounded_name
    mov     byte [payload_flags + 5], 0x01

    mov     si, str_pl_ivtdump
    mov     di, payload_names + 6 * PAYLOAD_NAME_LEN
    call    strcpy_bounded_name
    mov     byte [payload_flags + 6], 0x01

    mov     si, str_pl_memmap
    mov     di, payload_names + 7 * PAYLOAD_NAME_LEN
    call    strcpy_bounded_name
    mov     byte [payload_flags + 7], 0x01

    mov     word [payload_count], 8
    popa
    pop     es
    ret

run_env_checks:
    call    log_separator
    mov     si, str_env_start
    mov     bl, [th_accent]
    call    log_colored
    call    check_cpuid_support
    jc      .no_cpuid
    call    check_nx
    call    check_smep
    call    check_cpuid
.no_cpuid:
    call    check_ram
    call    check_a20
    call    log_separator
    ret

check_cpuid_support:
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
    mov     si, str_cpuid_none
    mov     bl, [th_warn]
    call    log_colored
    stc
    ret

check_nx:
    pusha
    mov     eax, 0x80000000
    cpuid
    cmp     eax, 0x80000001
    jb      .skip
    mov     eax, 0x80000001
    cpuid
    test    edx, (1 << 20)
    jz      .off
    mov     si, str_nx_on
    mov     bl, [th_warn]
    call    log_colored
    mov     byte [nx_active], 1
    popa
    ret
.off:
    mov     si, str_nx_off
    mov     bl, [th_success]
    call    log_colored
    mov     byte [nx_active], 0
    popa
    ret
.skip:
    mov     byte [nx_active], 0
    popa
    ret

check_smep:
    pusha
    mov     eax, 0
    cpuid
    cmp     eax, 7
    jb      .skip
    mov     eax, 7
    xor     ecx, ecx
    cpuid
    test    ebx, (1 << 7)
    jz      .off
    mov     si, str_smep_on
    mov     bl, [th_warn]
    call    log_colored
    mov     byte [smep_active], 1
    popa
    ret
.off:
    mov     si, str_smep_off
    mov     bl, [th_success]
    call    log_colored
    mov     byte [smep_active], 0
    popa
    ret
.skip:
    mov     byte [smep_active], 0
    popa
    ret

check_cpuid:
    pusha
    push    es
    xor     ax, ax
    mov     es, ax

    mov     eax, 0
    cpuid
    mov     [cpu_vendor],     ebx
    mov     [cpu_vendor + 4], edx
    mov     [cpu_vendor + 8], ecx
    mov     byte [cpu_vendor + 12], 0

    mov     eax, 1
    cpuid
    mov     [cpuid_edx], edx
    mov     [cpuid_ecx], ecx

    pop     es

    mov     si, str_cpuid_hdr
    mov     bl, [th_accent]
    call    log_colored

    mov     si, str_vendor_pfx
    call    log_partial
    mov     si, cpu_vendor
    mov     bl, [th_bright]
    call    log_colored
    popa
    ret

check_ram:
    pusha
    int     0x12
    jc      .fail
    mov     [conv_mem_kb], ax
    mov     si, str_ram_pfx
    call    log_partial
    mov     ax, [conv_mem_kb]
    call    log_decimal
    mov     si, str_kb
    mov     bl, [th_dim]
    call    log_colored
    popa
    ret
.fail:
    mov     word [conv_mem_kb], 0
    mov     si, str_ram_fail
    mov     bl, [th_error]
    call    log_colored
    popa
    ret

check_a20:
    pusha
    call    test_a20
    jc      .on
    mov     si, str_a20_off
    mov     bl, [th_error]
    call    log_colored
    popa
    ret
.on:
    mov     si, str_a20_on
    mov     bl, [th_success]
    call    log_colored
    popa
    ret

test_a20:
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

    mov     byte [si],    0x00
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
    stc
    ret
.wrap:
    clc
    ret

shell_loop:
    call    ui_draw_prompt
.main:
    call    readline
    call    dispatch_cmd
    jmp     .main

readline:
    pusha
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
    call    echo_char
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
    call    log_scroll_up_one
    jmp     .key

.pgdn:
    call    log_scroll_down_one
    jmp     .key

.backspace:
    test    cx, cx
    jz      .key
    dec     di
    dec     cx
    call    echo_backspace
    jmp     .key

.enter:
    mov     byte [di], 0
    mov     [input_len], cx
    call    echo_newline
    test    cx, cx
    jz      .done
    call    hist_push
.done:
    popa
    ret

log_scroll_up_one:
    pusha
    mov     ax, [log_scroll_offset]
    test    ax, ax
    jz      .done
    dec     ax
    mov     [log_scroll_offset], ax
    call    ui_redraw_log
.done:
    popa
    ret

log_scroll_down_one:
    pusha
    mov     ax, [log_scroll_offset]
    mov     bx, [log_line_count]
    mov     cx, PANEL_END_ROW - PANEL_START_ROW - 1
    sub     bx, cx
    jle     .done
    cmp     ax, bx
    jge     .done
    inc     ax
    mov     [log_scroll_offset], ax
    call    ui_redraw_log
.done:
    popa
    ret

dispatch_cmd:
    pusha
    mov     si, input_buf
    cmp     byte [si], 0
    je      .done

    mov     word [last_error], ERR_NONE

    mov     di, cmd_run
    call    strcmp_ci
    jz      .run

    mov     di, cmd_list
    call    strcmp_ci
    jz      .list

    mov     di, cmd_info
    call    strcmp_ci
    jz      .info

    mov     di, cmd_clear
    call    strcmp_ci
    jz      .clear

    mov     di, cmd_help
    call    strcmp_ci
    jz      .help

    mov     di, cmd_sel
    call    strcmp_pfx
    jz      .select

    mov     di, cmd_sandbox
    call    strcmp_ci
    jz      .sandbox

    mov     di, cmd_dump
    call    strcmp_pfx
    jz      .dump

    mov     di, cmd_theme
    call    strcmp_pfx
    jz      .theme

    mov     di, cmd_filter
    call    strcmp_pfx
    jz      .filter

    mov     di, cmd_themes
    call    strcmp_ci
    jz      .themes

    mov     di, cmd_filters
    call    strcmp_ci
    jz      .filters

    mov     di, cmd_errors
    call    strcmp_ci
    jz      .errors

    mov     si, str_err_unknown
    mov     word [last_error], ERR_BAD_ARG
    call    log_error_msg
    jmp     .done

.run:       call cmd_run_payload
            jmp .done
.list:      call cmd_list_payloads
            jmp .done
.info:      call cmd_show_info
            jmp .done
.clear:     call cmd_clear_log
            jmp .done
.help:      call cmd_show_help
            jmp .done
.select:    call cmd_select
            jmp .done
.sandbox:   call run_env_checks
            jmp .done
.dump:      call cmd_hexdump
            jmp .done
.theme:     call cmd_set_theme
            jmp .done
.filter:    call cmd_set_filter
            jmp .done
.themes:    call cmd_list_themes
            jmp .done
.filters:   call cmd_list_filters
            jmp .done
.errors:    call cmd_show_errors
            jmp .done

.done:
    call    ui_draw_prompt
    popa
    ret

cmd_run_payload:
    pusha
    mov     ax, [selected_idx]
    cmp     ax, [payload_count]
    jge     .invalid

    call    log_separator

    mov     si, str_exec_dispatch
    mov     bl, [th_accent]
    call    log_colored

    push    ax
    mov     si, str_pfx_target
    call    log_partial
    pop     ax
    push    ax

    mov     bx, PAYLOAD_NAME_LEN
    mul     bx
    mov     si, payload_names
    add     si, ax
    mov     bl, [th_bright]
    call    log_colored

    mov     si, str_sandbox_active
    mov     bl, [th_dim]
    call    log_colored

    pop     ax
    push    ax

    mov     si, str_pfx_args
    call    log_partial
    pop     ax
    push    ax

    mov     bx, PAYLOAD_ARG_LEN
    mul     bx
    mov     si, payload_args
    add     si, ax
    cmp     byte [si], 0
    jne     .show_args
    mov     si, str_no_args
.show_args:
    mov     bl, [th_dim]
    call    log_colored

    pop     ax

    mov     bx, ax
    mov     cl, [payload_flags + bx]
    xor     ch, ch
    push    cx
    push    ax
    call    sandbox_pre
    jc      .exec_blocked

    pop     ax
    pop     cx
    call    exec_payload
    jc      .exec_err

    push    ax
    xor     ax, ax
    push    ax
    call    sandbox_post
    pop     ax
    pop     ax

    call    log_separator
    popa
    ret

.exec_blocked:
    pop     ax
    pop     cx
    mov     word [last_error], ERR_SANDBOX_BLOCK
    mov     si, str_exec_blocked
    call    log_error_msg
    call    log_separator
    popa
    ret

.exec_err:
    push    ax
    xor     ax, ax
    push    ax
    call    sandbox_post
    pop     ax
    pop     ax
    mov     si, str_exec_fail
    call    log_error_msg
    call    log_separator
    popa
    ret

.invalid:
    mov     word [last_error], ERR_NO_PAYLOAD
    mov     si, str_err_no_payload
    call    log_error_msg
    popa
    ret

sandbox_pre:
    push    bp
    mov     bp, sp
    mov     ax, [bp+6]
    push    ax
    mov     ax, [bp+4]
    push    ax
    call    far [.sandbox_ptr]
    pop     bp
    ret
.sandbox_ptr:
    dw  SANDBOX_ENTRY, 0x0000

sandbox_post:
    call    far [.api_ptr]
    ret
.api_ptr:
    dw  SANDBOX_ENTRY + 3, 0x0000

exec_payload:
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
    mov     word [es:SHELLCODE_BASE + 4], 0x9090  
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

    mov     edx, [cpuid_edx]
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
    mov     ecx, [cpuid_ecx]
    test    ecx, (1 << 28)
    jz      .no_avx
    mov     si, str_feat_avx
    mov     bl, [th_success]
    call    log_colored
.no_avx:
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

    push    es
    xor     ax, ax
    mov     es, ax
    mov     ax, [es:bx]
    call    emit_hex_word
    mov     si, str_colon_sp
    call    log_partial
    mov     ax, [es:bx+2]
    call    emit_hex_word_nl
    pop     es

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
    push    es

    mov     si, str_memmap_hdr
    mov     bl, [th_success]
    call    log_colored

    xor     ax, ax
    mov     es, ax

    xor     ebx, ebx
    mov     word [e820_count], 0
    mov     di, e820_buf

.next_entry:
    mov     eax, 0x0000E820
    mov     ecx, 20
    mov     edx, 0x534D4150
    int     0x15

    jc      .e820_fail

    cmp     eax, 0x534D4150
    jne     .e820_fail

    test    cx, cx
    jz      .e820_done

    mov     ax, [e820_count]
    cmp     ax, E820_BUF_MAX
    jge     .e820_done

    inc     word [e820_count]
    add     di, E820_ENTRY_SIZE

    test    ebx, ebx
    jz      .e820_done
    jmp     .next_entry

.e820_fail:
    mov     word [last_error], ERR_E820_FAIL
    mov     si, str_e820_fail
    call    log_error_msg

    int     0x12
    jc      .ram_fail
    mov     [conv_mem_kb], ax
    mov     si, str_e820_fallback
    mov     bl, [th_warn]
    call    log_colored
    mov     si, str_ram_pfx
    call    log_partial
    mov     ax, [conv_mem_kb]
    call    log_decimal
    mov     si, str_kb
    mov     bl, [th_dim]
    call    log_colored
    pop     es
    popa
    clc
    ret

.ram_fail:
    mov     si, str_e820_no_mem
    call    log_error_msg
    pop     es
    popa
    stc
    ret

.e820_done:
    mov     cx, [e820_count]
    test    cx, cx
    jz      .e820_fail

    mov     si, str_e820_entries
    call    log_partial
    mov     ax, [e820_count]
    call    log_decimal
    call    emit_newline

    xor     bx, bx
    mov     di, e820_buf

.print_loop:
    cmp     bx, [e820_count]
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
    call    emit_str_nl

    pop     di
    pop     bx
    add     di, E820_ENTRY_SIZE
    inc     bx
    jmp     .print_loop

.print_done:
    pop     es
    popa
    clc
    ret

emit_str_nl:
    pusha
.lp:
    lodsb
    test    al, al
    jz      .done
    call    nibble_put_char
    jmp     .lp
.done:
    call    emit_newline
    popa
    ret

nibble_put_char:
    push    si
    push    ax
    mov     [nibble_tmp], al
    mov     byte [nibble_tmp + 1], 0
    mov     si, nibble_tmp
    call    log_partial
    pop     ax
    pop     si
    ret

cmd_set_theme:
    pusha
    mov     si, input_buf
    call    skip_cmd_token_si
    call    skip_spaces_si
    call    parse_decimal_si
    jc      .bad
    cmp     ax, 0
    je      .bad
    cmp     ax, 5
    ja      .bad
    call    theme_apply_color
    jc      .bad
    call    ui_full_redraw
    mov     si, str_theme_ok
    mov     bl, [th_accent]
    call    log_colored
    popa
    ret
.bad:
    mov     word [last_error], ERR_THEME_INVALID
    mov     si, str_err_theme
    call    log_error_msg
    popa
    ret

cmd_set_filter:
    pusha
    mov     si, input_buf
    call    skip_cmd_token_si
    call    skip_spaces_si
    call    parse_decimal_si
    jc      .bad
    cmp     ax, 5
    ja      .bad
    call    far [.set_ptr]
    jc      .bad
    call    ui_redraw_log
    mov     si, str_filter_ok
    mov     bl, [th_accent]
    call    log_colored
    popa
    ret
.bad:
    mov     word [last_error], ERR_FILTER_INVALID
    mov     si, str_err_filter
    call    log_error_msg
    popa
    ret
.set_ptr:
    dw  FILTER_BASE + 0, 0x0000

cmd_list_themes:
    pusha
    call    log_separator
    mov     si, str_themes_hdr
    mov     bl, [th_accent]
    call    log_colored
    mov     si, str_theme_1
    mov     bl, [th_normal]
    call    log_colored
    mov     si, str_theme_2
    call    log_colored
    mov     si, str_theme_3
    call    log_colored
    mov     si, str_theme_4
    call    log_colored
    mov     si, str_theme_5
    call    log_colored
    call    log_separator
    popa
    ret

cmd_list_filters:
    pusha
    call    log_separator
    mov     si, str_filters_hdr
    mov     bl, [th_accent]
    call    log_colored
    mov     si, str_filter_0
    mov     bl, [th_normal]
    call    log_colored
    mov     si, str_filter_1
    call    log_colored
    mov     si, str_filter_2
    call    log_colored
    mov     si, str_filter_3
    call    log_colored
    mov     si, str_filter_4
    call    log_colored
    mov     si, str_filter_5
    call    log_colored
    call    log_separator
    popa
    ret

cmd_show_errors:
    pusha
    call    log_separator
    mov     si, str_err_hdr
    mov     bl, [th_accent]
    call    log_colored
    mov     si, str_err_pfx
    call    log_partial
    mov     ax, [last_error]
    call    emit_hex_word_nl
    mov     si, str_err_desc
    call    log_partial
    mov     ax, [last_error]
    call    error_to_str
    mov     bl, [th_normal]
    call    log_colored
    call    log_separator
    popa
    ret

error_to_str:
    cmp     ax, ERR_NONE
    je      .none
    cmp     ax, ERR_DISK
    je      .disk
    cmp     ax, ERR_BOUNDS
    je      .bounds
    cmp     ax, ERR_SANDBOX_BLOCK
    je      .sandbox
    cmp     ax, ERR_BAD_ARG
    je      .bad_arg
    cmp     ax, ERR_OOB
    je      .oob
    cmp     ax, ERR_NO_PAYLOAD
    je      .no_payload
    cmp     ax, ERR_BAD_ADDR
    je      .bad_addr
    cmp     ax, ERR_THEME_INVALID
    je      .theme
    cmp     ax, ERR_FILTER_INVALID
    je      .filter
    cmp     ax, ERR_E820_FAIL
    je      .e820
    mov     si, str_errstr_unknown
    ret
.none:      mov si, str_errstr_none
    ret
.disk:      mov si, str_errstr_disk
    ret
.bounds:    mov si, str_errstr_bounds
    ret
.sandbox:   mov si, str_errstr_sandbox
    ret
.bad_arg:   mov si, str_errstr_bad_arg
    ret
.oob:       mov si, str_errstr_oob
    ret
.no_payload: mov si, str_errstr_no_pl
    ret
.bad_addr:  mov si, str_errstr_bad_addr
    ret
.theme:     mov si, str_errstr_theme
    ret
.filter:    mov si, str_errstr_filter
    ret
.e820:      mov si, str_errstr_e820
    ret

cmd_list_payloads:
    pusha
    call    log_separator
    mov     si, str_list_hdr
    mov     bl, [th_accent]
    call    log_colored

    xor     cx, cx
.loop:
    cmp     cx, [payload_count]
    jge     .done

    push    cx

    mov     ax, cx
    call    format_payload_line

    cmp     cx, [selected_idx]
    jne     .not_sel
    mov     bl, [th_selected]
    jmp     .do_log
.not_sel:
    mov     bl, [th_normal]
    push    bx
    mov     bx, cx
    cmp     byte [payload_flags + bx], 0x02
    pop     bx
    jne     .do_log
    mov     bl, [th_warn]
.do_log:
    push    bx
    call    filter_check
    pop     bx
    jc      .skip_line
    mov     si, fmt_line_buf
    call    log_colored
.skip_line:
    pop     cx
    inc     cx
    jmp     .loop

.done:
    call    log_separator
    popa
    ret

format_payload_line:
    pusha
    mov     di, fmt_line_buf
    mov     cx, LOG_LINE_LEN - 1

    cmp     ax, [selected_idx]
    jne     .unsel

    mov     byte [di], '*'
    inc     di
    dec     cx
    jmp     .idx

.unsel:
    mov     byte [di], ' '
    inc     di
    dec     cx

.idx:
    mov     byte [di], '['
    inc     di
    dec     cx

    push    ax
    call    uint_to_str_inline
    push    ax
    push    si
    mov     si, dec_buf
.idx_copy:
    lodsb
    test    al, al
    jz      .idx_done
    cmp     cx, 0
    je      .idx_done
    stosb
    dec     cx
    jmp     .idx_copy
.idx_done:
    pop     si
    pop     ax
    pop     ax

    mov     byte [di], ']'
    inc     di
    dec     cx
    mov     byte [di], ' '
    inc     di
    dec     cx

    push    ax
    mov     bx, PAYLOAD_NAME_LEN
    mul     bx
    mov     si, payload_names
    add     si, ax
.name_copy:
    lodsb
    test    al, al
    jz      .name_done
    cmp     cx, 0
    je      .name_done
    stosb
    dec     cx
    jmp     .name_copy
.name_done:
    pop     ax

    push    bx
    mov     bx, ax
    cmp     byte [payload_flags + bx], 0x02
    pop     bx
    jne     .no_danger

    cmp     cx, 4
    jl      .no_danger

    mov     byte [di], ' '
    inc     di
    mov     byte [di], '['
    inc     di
    mov     byte [di], '!'
    inc     di
    mov     byte [di], '!'
    inc     di
    mov     byte [di], ']'
    inc     di
    sub     cx, 5

.no_danger:
    test    cx, cx
    jz      .term
.pad:
    mov     byte [di], ' '
    inc     di
    dec     cx
    jnz     .pad

.term:
    mov     byte [di], 0
    popa
    ret

filter_check:
    push    ax
    mov     al, bl
    call    filter_color_match
    pop     ax
    ret

filter_color_match:
    call    far [.api_ptr]
    ret
.api_ptr:
    dw  FILTER_BASE + 6, 0x0000

cmd_show_info:
    pusha
    call    log_separator
    mov     si, str_info_hdr
    mov     bl, [th_accent]
    call    log_colored
    mov     si, str_info_1
    mov     bl, [th_normal]
    call    log_colored
    mov     si, str_info_2
    call    log_colored
    mov     si, str_info_3
    call    log_colored
    mov     si, str_info_4
    call    log_colored
    mov     si, str_info_5
    call    log_colored
    mov     si, str_info_6
    call    log_colored
    call    log_separator
    popa
    ret

cmd_clear_log:
    pusha
    mov     word [log_line_count], 0
    mov     word [log_scroll_offset], 0
    call    ui_redraw_log
    popa
    ret

cmd_show_help:
    pusha
    call    log_separator
    mov     si, str_help_hdr
    mov     bl, [th_accent]
    call    log_colored
    mov     si, str_help_run
    mov     bl, [th_normal]
    call    log_colored
    mov     si, str_help_list
    call    log_colored
    mov     si, str_help_sel
    call    log_colored
    mov     si, str_help_sandbox
    call    log_colored
    mov     si, str_help_dump
    call    log_colored
    mov     si, str_help_info
    call    log_colored
    mov     si, str_help_clear
    call    log_colored
    mov     si, str_help_theme
    call    log_colored
    mov     si, str_help_themes
    call    log_colored
    mov     si, str_help_filter
    call    log_colored
    mov     si, str_help_filters
    call    log_colored
    mov     si, str_help_errors
    call    log_colored
    call    log_separator
    popa
    ret

cmd_select:
    pusha
    mov     si, input_buf
    call    skip_cmd_token_si
    call    skip_spaces_si
    call    parse_decimal_si
    jc      .bad

    cmp     ax, [payload_count]
    jge     .oob
    mov     [selected_idx], ax

    call    skip_decimal_si
    call    skip_spaces_si

    mov     ax, [selected_idx]
    mov     bx, PAYLOAD_ARG_LEN
    mul     bx
    mov     di, payload_args
    add     di, ax

    mov     cx, PAYLOAD_ARG_LEN - 1
.copy_arg:
    lodsb
    test    al, al
    jz      .arg_done
    stosb
    loop    .copy_arg
.arg_done:
    mov     byte [di], 0

    call    ui_redraw_payload_list
    mov     si, str_sel_ok
    mov     bl, [th_accent]
    call    log_colored
    popa
    ret
.bad:
    mov     word [last_error], ERR_BAD_ARG
    mov     si, str_err_bad_idx
    call    log_error_msg
    popa
    ret
.oob:
    mov     word [last_error], ERR_OOB
    mov     si, str_err_oob
    call    log_error_msg
    popa
    ret

cmd_hexdump:
    pusha
    mov     si, input_buf
    call    skip_cmd_token_si
    call    skip_spaces_si
    call    parse_hex_word_si
    jc      .bad

    push    es
    xor     bx, bx
    mov     es, bx
    mov     bx, ax

    mov     cx, 4

.row:
    push    cx
    push    bx

    mov     ax, bx
    call    emit_hex_word
    mov     si, str_colon_sp
    call    log_partial

    mov     cx, 8
.byte_loop:
    mov     al, [es:bx]
    call    emit_hex_byte_sp
    inc     bx
    loop    .byte_loop

    call    emit_newline
    pop     bx
    add     bx, 8
    pop     cx
    loop    .row

    pop     es
    popa
    clc
    ret

.bad:
    mov     word [last_error], ERR_BAD_ADDR
    mov     si, str_err_bad_addr
    call    log_error_msg
    popa
    stc
    ret

ui_full_redraw:
    push    es
    xor     ax, ax
    mov     es, ax
    call    ui_draw_frame
    call    ui_redraw_payload_list
    call    ui_redraw_log
    call    ui_draw_statusbar
    call    ui_draw_prompt
    pop     es
    ret

ui_draw_frame:
    push    es
    xor     ax, ax
    mov     es, ax
    pusha
    push    es
    mov     ax, VGA_SEG
    mov     es, ax
    xor     di, di
    mov     cx, SCREEN_ROWS * SCREEN_COLS
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
    call    vga_puts
    mov     di, (TITLE_ROW * SCREEN_COLS + 60) * 2
    mov     si, str_build
    mov     ah, [th_title]
    call    vga_puts
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
    call    vga_puts
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
    call    vga_puts
    mov     di, (PANEL_START_ROW * SCREEN_COLS + RIGHT_PANEL_START + 1) * 2
    mov     si, str_panel_log
    mov     ah, [th_dim]
    call    vga_puts
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
    pop     es
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
    call    vga_puts
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
    call    vga_puts

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
    call    vga_puts
    pop     bx
    pop     cx
    inc     cx
    inc     bx
    jmp     .entry

.done:
    pop     es
    popa
    ret

ui_redraw_log:
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
    add     di, RIGHT_PANEL_START + 1
    shl     di, 1
    mov     cx, SCREEN_COLS - RIGHT_PANEL_START - 2
    mov     ah, [th_dim]
    mov     al, 0x20
    rep     stosw
    inc     bx
    jmp     .clear
.clear_done:

    mov     ax, [log_line_count]
    mov     cx, PANEL_END_ROW - PANEL_START_ROW - 1
    cmp     ax, cx
    jl      .use_zero
    sub     ax, cx
    jmp     .set_start
.use_zero:
    xor     ax, ax
.set_start:
    mov     bx, [log_scroll_offset]
    add     ax, bx

    mov     cx, ax
    mov     bx, PANEL_START_ROW + 1

.render:
    cmp     bx, PANEL_END_ROW
    jge     .done
    cmp     cx, [log_line_count]
    jge     .done

    push    ax
    push    bx
    mov     bx, cx
    mov     al, [log_colors + bx]
    pop     bx
    call    filter_color_match
    pop     ax
    jc      .skip

    mov     ax, bx
    imul    ax, ax, SCREEN_COLS
    add     ax, RIGHT_PANEL_START + 1
    shl     ax, 1
    mov     di, ax

    push    bx
    push    cx
    mov     ax, cx
    mov     bx, LOG_LINE_LEN
    mul     bx
    mov     si, log_buf
    add     si, ax

    push    bx
    mov     bx, cx
    mov     ah, [log_colors + bx]
    pop     bx
    call    vga_puts
    pop     cx
    pop     bx
    inc     bx
.skip:
    inc     cx
    jmp     .render

.done:
    pop     es
    popa
    ret

log_colored:
    pusha
    push    bx
    call    log_add_line
    dec     word [log_line_count]
    mov     ax, [log_line_count]
    pop     bx
    push    di
    mov     di, ax
    mov     [log_colors + di], bl
    pop     di
    inc     word [log_line_count]
    call    ui_redraw_log
    popa
    ret

log_error_msg:
    mov     bl, [th_error]
    call    log_colored
    ret

log_accent:
    mov     bl, [th_accent]
    call    log_colored
    ret

log_separator:
    pusha
    mov     si, str_sep
    mov     bl, [th_dim]
    call    log_colored
    popa
    ret

log_add_line:
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

    mov     cx, LOG_LINE_LEN - 1
.copy:
    lodsb
    test    al, al
    jz      .pad
    stosb
    loop    .copy
    jmp     .term
.pad:
    mov     al, 0x20
    rep     stosb
.term:
    mov     byte [di], 0
    inc     word [log_line_count]
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
    popa
    ret

log_partial:
    pusha
    mov     ax, [log_line_count]
    mov     bx, LOG_LINE_LEN
    mul     bx
    mov     di, log_buf
    add     di, ax
    mov     cx, [partial_col]
    add     di, cx

.copy:
    lodsb
    test    al, al
    jz      .done
    cmp     word [partial_col], LOG_LINE_LEN - 1
    jge     .done
    stosb
    inc     word [partial_col]
    jmp     .copy
.done:
    popa
    ret

emit_newline:
    pusha
    mov     word [partial_col], 0
    mov     ax, [log_line_count]
    mov     bl, [th_normal]
    push    di
    mov     di, ax
    mov     [log_colors + di], bl
    pop     di
    inc     word [log_line_count]
    cmp     word [log_line_count], LOG_MAX_LINES
    jl      .ok
    call    log_scroll_shift
.ok:
    call    ui_redraw_log
    popa
    ret

emit_hex_word:
    pusha
    push    ax
    mov     cl, 12
    shr     ax, cl
    call    nibble_out
    pop     ax
    push    ax
    mov     cl, 8
    shr     ax, cl
    and     al, 0x0F
    call    nibble_out
    pop     ax
    push    ax
    mov     cl, 4
    shr     ax, cl
    and     al, 0x0F
    call    nibble_out
    pop     ax
    and     al, 0x0F
    call    nibble_out
    popa
    ret

emit_hex_word_nl:
    call    emit_hex_word
    call    emit_newline
    ret

emit_hex_byte_nl:
    pusha
    push    ax
    shr     al, 4
    call    nibble_out
    pop     ax
    and     al, 0x0F
    call    nibble_out
    call    emit_newline
    popa
    ret

emit_hex_byte_sp:
    pusha
    push    ax
    shr     al, 4
    call    nibble_out
    pop     ax
    and     al, 0x0F
    call    nibble_out
    mov     si, str_space
    call    log_partial
    popa
    ret

emit_hex_byte_inline:
    pusha
    push    ax
    shr     al, 4
    call    nibble_out
    pop     ax
    and     al, 0x0F
    call    nibble_out
    popa
    ret

log_decimal:
    pusha
    call    uint_to_str_inline
    mov     si, dec_buf
    call    log_partial
    popa
    ret

nibble_out:
    pusha
    and     al, 0x0F
    cmp     al, 9
    jbe     .digit
    add     al, 7
.digit:
    add     al, 0x30
    mov     [nibble_tmp], al
    mov     byte [nibble_tmp + 1], 0
    mov     si, nibble_tmp
    call    log_partial
    popa
    ret

uint_to_str_inline:
    pusha
    mov     di, dec_buf + 9
    mov     byte [di], 0
    mov     bx, 10
    test    ax, ax
    jnz     .divide
    dec     di
    mov     byte [di], '0'
    jmp     .store
.divide:
    test    ax, ax
    jz      .store
    xor     dx, dx
    div     bx
    add     dl, '0'
    dec     di
    mov     [di], dl
    jmp     .divide
.store:
    push    di
    mov     si, di
    mov     di, dec_buf
    mov     cx, 10
.shift:
    lodsb
    stosb
    loop    .shift
    pop     di
    popa
    ret

echo_char:
    push    ax
    push    bx
    mov     ah, 0x0E
    mov     bx, 0x0007
    int     0x10
    pop     bx
    pop     ax
    ret

echo_backspace:
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

echo_newline:
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
    mov     ax, [hist_head]
    cmp     ax, HIST_DEPTH
    jl      .ok
    mov     word [hist_head], 0
.ok:
    mov     ax, [hist_count]
    cmp     ax, HIST_DEPTH
    jge     .max
    inc     word [hist_count]
.max:
    mov     ax, [hist_head]
    mov     [hist_cursor], ax
    popa
    ret

hist_prev:
    pusha
    mov     ax, [hist_count]
    test    ax, ax
    jz      .done

    mov     ax, [hist_cursor]
    test    ax, ax
    jz      .wrap_prev
    dec     ax
    jmp     .load

.wrap_prev:
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
    mov     cx, HIST_ENTRY_SIZE
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
    call    ui_draw_prompt

.done:
    popa
    ret

hist_next:
    pusha
    mov     ax, [hist_count]
    test    ax, ax
    jz      .done

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

    call    ui_draw_prompt

.done:
    popa
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

to_upper:
    cmp     al, 'a'
    jb      .done
    cmp     al, 'z'
    ja      .done
    sub     al, 0x20
.done:
    ret

strcpy_bounded_name:
    push    si
    push    di
    mov     cx, PAYLOAD_NAME_LEN - 1
.loop:
    lodsb
    test    al, al
    jz      .null_term
    stosb
    loop    .loop
    jmp     .done
.null_term:
    stosb
.done:
    mov     byte [di], 0
    pop     di
    pop     si
    ret

skip_spaces_si:
.loop:
    cmp     byte [si], 0x20
    jne     .done
    inc     si
    jmp     .loop
.done:
    ret

skip_cmd_token_si:
.loop:
    mov     al, [si]
    test    al, al
    jz      .done
    cmp     al, 0x20
    je      .done
    inc     si
    jmp     .loop
.done:
    ret

skip_decimal_si:
.loop:
    mov     al, [si]
    cmp     al, '0'
    jb      .done
    cmp     al, '9'
    ja      .done
    inc     si
    jmp     .loop
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

vga_puts:
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

engine_drive        db 0
nx_active           db 0
smep_active         db 0
cpuid_edx           dd 0
cpuid_ecx           dd 0
conv_mem_kb         dw 0
selected_idx        dw 0
payload_count       dw 0
log_line_count      dw 0
log_scroll_offset   dw 0
hist_head           dw 0
hist_count          dw 0
hist_cursor         dw 0
input_len           dw 0
partial_col         dw 0
last_error          dw 0
canary_depth        dw 4
port_base           dw 0x03F8
ivt_dump_count      dw 16
e820_count          dw 0

nibble_tmp          db 0, 0
cpu_vendor          times 13 db 0
cpu_brand           times 49 db 0
dec_buf             times 11 db 0
input_buf           times INPUT_BUF_SIZE db 0
fmt_line_buf        times LOG_LINE_LEN + 2 db 0
payload_names       times MAX_PAYLOADS * PAYLOAD_NAME_LEN db 0
payload_args        times MAX_PAYLOADS * PAYLOAD_ARG_LEN db 0
payload_flags       times MAX_PAYLOADS db 0
hist_buf            times HIST_DEPTH * HIST_ENTRY_SIZE db 0
log_buf             times LOG_MAX_LINES * LOG_LINE_LEN db 0
log_colors          times LOG_MAX_LINES db 0
e820_buf            times E820_BUF_MAX * E820_ENTRY_SIZE db 0

th_normal           db COL_NORMAL
th_bright           db COL_BRIGHT
th_success          db COL_SUCCESS
th_error            db COL_ERROR
th_warn             db COL_WARN
th_accent           db COL_ACCENT
th_dim              db COL_DIM
th_selected         db COL_SELECTED
th_title            db COL_TITLE
th_status           db COL_STATUS

str_title           db "  SX-SANDBOX  >>  SHELLCODE EXECUTION & ANALYSIS ENVIRONMENT  //  x86 REAL MODE", 0
str_build           db "BUILD 2.1.0", 0
str_subtitle        db "Arch: x86-16  |  Mode: Real  |  BIOS: Legacy INT  |  Target: 0xA000", 0
str_panel_payloads  db "PAYLOADS", 0
str_panel_log       db "EXECUTION LOG", 0
str_status          db "  run  list  sel <n> [arg]  dump  theme <n>  filter <n>  themes  filters  sandbox  help", 0
str_prompt          db "sx-sandbox> ", 0
str_sep             db "------------------------------------------------------", 0
str_env_start       db "[ENV] Running environment security checks...", 0
str_cpuid_none      db "  [CPUID]   Not supported on this CPU", 0
str_nx_on           db "  [NX/DEP]  ACTIVE   -- memory regions write-xor-exec", 0
str_nx_off          db "  [NX/DEP]  INACTIVE -- regions are RWX, no exec guard", 0
str_smep_on         db "  [SMEP]    ACTIVE   -- supervisor exec of user pages blocked", 0
str_smep_off        db "  [SMEP]    INACTIVE -- ring0 can exec user-mode pages", 0
str_cpuid_hdr       db "  [CPUID]   Vendor identification complete", 0
str_vendor_pfx      db "    Vendor  : ", 0
str_ram_pfx         db "    RAM     : ", 0
str_ram_fail        db "  [RAM]     INT 12h query failed", 0
str_a20_on          db "  [A20]     ENABLED  -- full 21-bit address space active", 0
str_a20_off         db "  [A20]     DISABLED -- address line 20 wrap-around mode", 0
str_kb              db " KB conventional", 0
str_exec_dispatch   db "[EXEC] Dispatching selected payload...", 0
str_pfx_target      db "  Target  : ", 0
str_pfx_args        db "  Args    : ", 0
str_no_args         db "(none)", 0
str_sandbox_active  db "  Sandbox : active | pre-exec scan complete", 0
str_exec_fail       db "[ERR] Payload execution failed or was blocked.", 0
str_exec_blocked    db "[ERR] Sandbox blocked payload before execution.", 0
str_payload_blocked db "[ERR] Shellcode call failed.", 0
str_err_no_payload  db "[ERR] No valid payload selected. Use: sel <n>", 0
str_err_unknown     db "[ERR] Unknown command. Type 'help' for usage.", 0
str_list_hdr        db "[PAYLOADS] Available shellcode modules:", 0
str_info_hdr        db "[INFO] SX-SANDBOX System Information", 0
str_info_1          db "  Engine  : 16-bit real mode shellcode loader/sandbox", 0
str_info_2          db "  Stage2  : 0x7E00  (this module, 64 sectors)", 0
str_info_3          db "  Sandbox : 0x9000  (protection layer, 8 sectors)", 0
str_info_4          db "  Payload : 0xA000  (runtime injection target)", 0
str_info_5          db "  Theme   : 0xB000  (theme engine, 2 sectors)", 0
str_info_6          db "  Filter  : 0xC000  (log filter, 2 sectors)", 0
str_help_hdr        db "[HELP] Command Reference:", 0
str_help_run        db "  run              Execute selected payload through sandbox", 0
str_help_list       db "  list             List all available payload modules", 0
str_help_sel        db "  sel <n> [arg]    Select payload by index, optional argument", 0
str_help_sandbox    db "  sandbox          Re-run environment security checks", 0
str_help_dump       db "  dump <hex>       Hexdump 32 bytes at hex address", 0
str_help_info       db "  info             Display system memory and module info", 0
str_help_clear      db "  clear            Clear the execution log panel", 0
str_help_theme      db "  theme <1-5>      Set color theme (1=color 2=mono 3=hacker 4=retro 5=stealth)", 0
str_help_themes     db "  themes           List all available themes", 0
str_help_filter     db "  filter <0-5>     Filter log by color (0=all 1=info 2=warn 3=err 4=ok 5=accent)", 0
str_help_filters    db "  filters          List all available log filters", 0
str_help_errors     db "  errors           Show last error code and description", 0
str_sel_ok          db "[OK] Payload selection updated.", 0
str_err_bad_idx     db "[ERR] Invalid index. Provide a decimal number.", 0
str_err_oob         db "[ERR] Index out of range.", 0
str_err_bad_addr    db "[ERR] Invalid address. Use hex: dump 7c00", 0
str_err_theme       db "[ERR] Invalid theme. Use: theme <1-5>", 0
str_err_filter      db "[ERR] Invalid filter. Use: filter <0-5>", 0
str_theme_ok        db "[OK] Theme applied. Screen redrawn.", 0
str_filter_ok       db "[OK] Log filter updated.", 0
str_themes_hdr      db "[THEMES] Available color themes:", 0
str_theme_1         db "  1 - COLOR   : Full 16-color CGA palette (default)", 0
str_theme_2         db "  2 - MONO    : Monochrome white-on-black", 0
str_theme_3         db "  3 - HACKER  : Green phosphor terminal", 0
str_theme_4         db "  4 - RETRO   : Amber CRT display", 0
str_theme_5         db "  5 - STEALTH : Near-invisible dark mode", 0
str_filters_hdr     db "[FILTERS] Available log color filters:", 0
str_filter_0        db "  0 - ALL     : Show all log entries", 0
str_filter_1        db "  1 - INFO    : Show dim/accent entries only", 0
str_filter_2        db "  2 - WARN    : Show warning entries only", 0
str_filter_3        db "  3 - ERROR   : Show error entries only", 0
str_filter_4        db "  4 - SUCCESS : Show success entries only", 0
str_filter_5        db "  5 - ACCENT  : Show accent entries only", 0
str_err_hdr         db "[ERRORS] Last error status:", 0
str_err_pfx         db "  Code : 0x", 0
str_err_desc        db "  Desc : ", 0
str_errstr_none     db "No error", 0
str_errstr_disk     db "Disk read failure", 0
str_errstr_bounds   db "Address out of bounds", 0
str_errstr_sandbox  db "Sandbox blocked execution", 0
str_errstr_bad_arg  db "Invalid argument or command", 0
str_errstr_oob      db "Index out of range", 0
str_errstr_no_pl    db "No payload selected", 0
str_errstr_bad_addr db "Invalid hex address", 0
str_errstr_theme    db "Invalid theme index (1-5)", 0
str_errstr_filter   db "Invalid filter index (0-5)", 0
str_errstr_e820     db "E820 memory map query failed", 0
str_errstr_unknown  db "Unknown error", 0
str_msgbox_hdr      db "[PAYLOAD:MSGBOX] Writing segment probe stub to 0xA000...", 0
str_injected        db "  Shellcode written. Transferring control to 0xA000...", 0
str_returned        db "  Returned cleanly. Stack and segment registers intact.", 0
str_memwalk_hdr     db "[PAYLOAD:MEMWALK] Dumping BIOS Data Area (0x0400+):", 0
str_port_hdr        db "[PAYLOAD:PORTPROBE] Sampling I/O ports:", 0
str_stack_hdr       db "[PAYLOAD:STACKSMASH] Analyzing stack frame integrity...", 0
str_canary_write    db "  Writing canary pattern 0xDEAD to stack...", 0
str_stack_ok        db "  All canaries intact. Stack integrity: PASS", 0
str_stack_corrupt   db "[ERR] Stack corruption detected! Canary mismatch.", 0
str_nx_hdr          db "[PAYLOAD:NXPROBE] Testing execute permission on 0xA000...", 0
str_nx_exec         db "  NX inactive. Writing RET stub and executing...", 0
str_nx_done         db "  Execution from data region succeeded. NX: ABSENT", 0
str_nx_blocked      db "  NX active. Direct execution attempt would fault.", 0
str_cpu_hdr         db "[PAYLOAD:CPUINFO] Enumerating CPU via CPUID leaves...", 0
str_ivt_hdr         db "[PAYLOAD:IVTDUMP] Dumping interrupt vector table (0x0000):", 0
str_memmap_hdr      db "[PAYLOAD:MEMMAP] Querying E820 system memory map...", 0
str_e820_fail       db "[ERR] E820 unsupported or INT 15h failed on this system.", 0
str_e820_fallback   db "  Falling back to INT 12h conventional memory query.", 0
str_e820_no_mem     db "[ERR] INT 12h also failed. Memory info unavailable.", 0
str_e820_entries    db "  E820 entries found: ", 0
str_e820_base       db "  BASE=0x", 0
str_e820_len        db " LEN=0x", 0
str_e820_type       db " TYPE=", 0
str_e820_type_use   db "USABLE", 0
str_e820_type_res   db "RESERVED", 0
str_e820_type_acpi  db "ACPI-RECLAIMABLE", 0
str_e820_type_nvs   db "ACPI-NVS", 0
str_e820_type_bad   db "BAD-MEMORY", 0
str_e820_type_unk   db "UNKNOWN", 0
str_no_brand        db "  Brand string not available (CPUID < 0x80000004)", 0
str_feat_sse        db "  [FEAT] SSE  supported", 0
str_feat_sse2       db "  [FEAT] SSE2 supported", 0
str_feat_avx        db "  [FEAT] AVX  supported", 0
str_pfx_addr        db "  [0x", 0
str_pfx_port        db "  PORT 0x", 0
str_pfx_ss          db "  SS: 0x", 0
str_pfx_sp          db "  SP: 0x", 0
str_pfx_brand       db "  Brand  : ", 0
str_pfx_step        db "  Step   : ", 0
str_pfx_vec         db "  VEC[0x", 0
str_colon_sp        db "]: ", 0
str_arrow           db " -> 0x", 0
str_space           db " ", 0

str_pl_msgbox       db "MSGBOX     - Segment register probe", 0
str_pl_memwalk      db "MEMWALK    - BDA memory region walker", 0
str_pl_portprobe    db "PORTPROBE  - I/O port sampler [arg: hex port]", 0
str_pl_stacksmash   db "STACKSMASH - Canary integrity test [!] [arg: depth]", 0
str_pl_nxprobe      db "NXPROBE    - NX/DEP execution probe", 0
str_pl_cpuinfo      db "CPUINFO    - Full CPUID enumeration", 0
str_pl_ivtdump      db "IVTDUMP    - IVT vector dump [arg: count]", 0
str_pl_memmap       db "MEMMAP     - E820 system memory map", 0

cmd_run             db "RUN", 0
cmd_list            db "LIST", 0
cmd_info            db "INFO", 0
cmd_clear           db "CLEAR", 0
cmd_help            db "HELP", 0
cmd_sel             db "SEL", 0
cmd_sandbox         db "SANDBOX", 0
cmd_dump            db "DUMP", 0
cmd_theme           db "THEME", 0
cmd_filter          db "FILTER", 0
cmd_themes          db "THEMES", 0
cmd_filters         db "FILTERS", 0
cmd_errors          db "ERRORS", 0

times 32768 - ($ - $$) db 0
