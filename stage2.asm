BITS 16
ORG 0x7E00

SANDBOX_ENTRY           equ 0x9000
SHELLCODE_BASE          equ 0xA000

MAX_PAYLOADS            equ 8
PAYLOAD_NAME_LEN        equ 32

INPUT_BUF_SIZE          equ 128

HIST_DEPTH              equ 8
HIST_ENTRY_SIZE         equ 64

LOG_LINE_LEN            equ 54
LOG_MAX_LINES           equ 256

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

stage2_main:
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax
    mov     sp, 0x7BFC

    mov     [engine_drive], dl

    call    init_payloads
    call    ui_full_redraw
    call    run_env_checks
    call    shell_loop

    cli
    hlt
    jmp     $

init_payloads:
    pusha
    mov     di, payload_names
    mov     cx, MAX_PAYLOADS * PAYLOAD_NAME_LEN
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

    mov     si, str_pl_msgbox
    mov     di, payload_names + 0 * PAYLOAD_NAME_LEN
    call    strcpy_bounded
    mov     byte [payload_flags + 0], 0x01

    mov     si, str_pl_memwalk
    mov     di, payload_names + 1 * PAYLOAD_NAME_LEN
    call    strcpy_bounded
    mov     byte [payload_flags + 1], 0x01

    mov     si, str_pl_portprobe
    mov     di, payload_names + 2 * PAYLOAD_NAME_LEN
    call    strcpy_bounded
    mov     byte [payload_flags + 2], 0x01

    mov     si, str_pl_stacksmash
    mov     di, payload_names + 3 * PAYLOAD_NAME_LEN
    call    strcpy_bounded
    mov     byte [payload_flags + 3], 0x02

    mov     si, str_pl_nxprobe
    mov     di, payload_names + 4 * PAYLOAD_NAME_LEN
    call    strcpy_bounded
    mov     byte [payload_flags + 4], 0x01

    mov     si, str_pl_cpuinfo
    mov     di, payload_names + 5 * PAYLOAD_NAME_LEN
    call    strcpy_bounded
    mov     byte [payload_flags + 5], 0x01

    mov     si, str_pl_ivtdump
    mov     di, payload_names + 6 * PAYLOAD_NAME_LEN
    call    strcpy_bounded
    mov     byte [payload_flags + 6], 0x01

    mov     word [payload_count], 7
    popa
    ret

run_env_checks:
    call    log_separator
    mov     si, str_env_start
    call    log_accent
    call    check_nx
    call    check_smep
    call    check_cpuid
    call    check_ram
    call    check_a20
    call    log_separator
    ret

check_nx:
    pusha
    mov     eax, 0x80000001
    cpuid
    test    edx, (1 << 20)
    jz      .off
    mov     si, str_nx_on
    mov     bl, COL_WARN
    call    log_colored
    mov     byte [nx_active], 1
    popa
    ret
.off:
    mov     si, str_nx_off
    mov     bl, COL_SUCCESS
    call    log_colored
    mov     byte [nx_active], 0
    popa
    ret

check_smep:
    pusha
    mov     eax, 7
    xor     ecx, ecx
    cpuid
    test    ebx, (1 << 7)
    jz      .off
    mov     si, str_smep_on
    mov     bl, COL_WARN
    call    log_colored
    mov     byte [smep_active], 1
    popa
    ret
.off:
    mov     si, str_smep_off
    mov     bl, COL_SUCCESS
    call    log_colored
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
    mov     bl, COL_ACCENT
    call    log_colored

    mov     si, str_vendor_pfx
    call    log_partial
    mov     si, cpu_vendor
    mov     bl, COL_BRIGHT
    call    log_colored

    popa
    ret

check_ram:
    pusha
    int     0x12
    mov     [conv_mem_kb], ax
    mov     si, str_ram_pfx
    call    log_partial
    mov     ax, [conv_mem_kb]
    call    log_decimal
    mov     si, str_kb
    mov     bl, COL_DIM
    call    log_colored
    popa
    ret

check_a20:
    pusha
    call    test_a20
    jc      .on
    mov     si, str_a20_off
    mov     bl, COL_ERROR
    call    log_colored
    popa
    ret
.on:
    mov     si, str_a20_on
    mov     bl, COL_SUCCESS
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
    jmp     .key

.hist_up:
    call    hist_prev
    jmp     .key

.hist_down:
    call    hist_next
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

dispatch_cmd:
    pusha
    mov     si, input_buf
    cmp     byte [si], 0
    je      .done

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

    mov     si, str_err_unknown
    call    log_error
    jmp     .done

.run:       call cmd_run_payload   ; jmp .done intentional fallthrough
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
    call    log_accent

    push    ax
    mov     si, str_pfx_target
    call    log_partial
    pop     ax
    push    ax

    mov     bx, PAYLOAD_NAME_LEN
    mul     bx
    mov     si, payload_names
    add     si, ax
    mov     bl, COL_BRIGHT
    call    log_colored

    mov     si, str_sandbox_active
    mov     bl, COL_DIM
    call    log_colored

    pop     ax
    call    exec_payload
    call    log_separator
    popa
    ret

.invalid:
    mov     si, str_err_no_payload
    call    log_error
    popa
    ret

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
    ret

payload_msgbox:
    pusha
    push    es
    xor     ax, ax
    mov     es, ax

    mov     si, str_msgbox_hdr
    mov     bl, COL_SUCCESS
    call    log_colored

    mov     word [es:SHELLCODE_BASE + 0], 0xB8C0
    mov     word [es:SHELLCODE_BASE + 2], 0x07C0
    mov     word [es:SHELLCODE_BASE + 4], 0x90C3

    mov     si, str_injected
    mov     bl, COL_ACCENT
    call    log_colored

    call    SHELLCODE_BASE

    mov     si, str_returned
    mov     bl, COL_SUCCESS
    call    log_colored

    pop     es
    popa
    ret

payload_memwalk:
    pusha
    push    es
    xor     ax, ax
    mov     es, ax

    mov     si, str_memwalk_hdr
    mov     bl, COL_SUCCESS
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

    pop     bx
    push    bx
    mov     ax, [es:bx]
    call    emit_hex_word_nl

    add     bx, 2
    pop     bx
    add     bx, 2
    pop     cx
    loop    .row

    pop     es
    popa
    ret

payload_portprobe:
    pusha

    mov     si, str_port_hdr
    mov     bl, COL_SUCCESS
    call    log_colored

    mov     cx, 8
    mov     dx, 0x03F8

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
    ret

payload_stacksmash:
    pusha

    mov     si, str_stack_hdr
    mov     bl, COL_WARN
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

    mov     si, str_canary_write
    mov     bl, COL_WARN
    call    log_colored

    mov     cx, 4
.push_canary:
    push    word 0xDEAD
    loop    .push_canary

    mov     cx, 4
.check_canary:
    pop     ax
    cmp     ax, 0xDEAD
    jne     .corrupt
    loop    .check_canary

    mov     si, str_stack_ok
    mov     bl, COL_SUCCESS
    call    log_colored
    popa
    ret

.corrupt:
    mov     si, str_stack_corrupt
    call    log_error
    popa
    ret

payload_nxprobe:
    pusha

    mov     si, str_nx_hdr
    mov     bl, COL_SUCCESS
    call    log_colored

    cmp     byte [nx_active], 1
    je      .nx_present

    push    es
    xor     ax, ax
    mov     es, ax
    mov     byte [es:SHELLCODE_BASE], 0xC3
    pop     es

    mov     si, str_nx_exec
    mov     bl, COL_SUCCESS
    call    log_colored

    call    SHELLCODE_BASE

    mov     si, str_nx_done
    mov     bl, COL_SUCCESS
    call    log_colored
    popa
    ret

.nx_present:
    mov     si, str_nx_blocked
    mov     bl, COL_WARN
    call    log_colored
    popa
    ret

payload_cpuinfo:
    pusha

    mov     si, str_cpu_hdr
    mov     bl, COL_SUCCESS
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
    mov     bl, COL_BRIGHT
    call    log_colored
    jmp     .features

.no_brand:
    mov     si, str_no_brand
    mov     bl, COL_DIM
    call    log_colored

.features:
    mov     eax, 1
    cpuid
    mov     si, str_pfx_step
    call    log_partial
    and     eax, 0x0F
    call    log_decimal
    call    emit_newline

    mov     edx, [cpuid_edx]
    test    edx, (1 << 25)
    jz      .no_sse
    mov     si, str_feat_sse
    mov     bl, COL_SUCCESS
    call    log_colored
.no_sse:
    test    edx, (1 << 26)
    jz      .no_sse2
    mov     si, str_feat_sse2
    mov     bl, COL_SUCCESS
    call    log_colored
.no_sse2:
    mov     ecx, [cpuid_ecx]
    test    ecx, (1 << 28)
    jz      .no_avx
    mov     si, str_feat_avx
    mov     bl, COL_SUCCESS
    call    log_colored
.no_avx:
    popa
    ret

payload_ivtdump:
    pusha
    push    es
    xor     ax, ax
    mov     es, ax

    mov     si, str_ivt_hdr
    mov     bl, COL_SUCCESS
    call    log_colored

    xor     bx, bx
    mov     cx, 16

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
    ret

cmd_list_payloads:
    pusha
    call    log_separator
    mov     si, str_list_hdr
    call    log_accent

    xor     cx, cx
.loop:
    cmp     cx, [payload_count]
    jge     .done

    push    cx
    cmp     cx, [selected_idx]
    jne     .not_sel

    mov     si, str_sel_marker
    mov     bl, COL_SELECTED
    call    log_partial_col
    jmp     .name

.not_sel:
    mov     si, str_unsel_marker
    mov     bl, COL_DIM
    call    log_partial_col

.name:
    pop     cx
    push    cx

    mov     ax, cx
    mov     bx, PAYLOAD_NAME_LEN
    mul     bx
    mov     si, payload_names
    add     si, ax

    mov     bl, COL_NORMAL
    cmp     byte [payload_flags + cx], 0x02
    jne     .safe
    mov     bl, COL_WARN

.safe:
    call    log_colored

    pop     cx
    inc     cx
    jmp     .loop

.done:
    call    log_separator
    popa
    ret

cmd_show_info:
    pusha
    call    log_separator
    mov     si, str_info_hdr
    call    log_accent
    mov     si, str_info_1
    mov     bl, COL_NORMAL
    call    log_colored
    mov     si, str_info_2
    call    log_colored
    mov     si, str_info_3
    call    log_colored
    mov     si, str_info_4
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
    call    log_accent
    mov     si, str_help_run
    mov     bl, COL_NORMAL
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
    call    log_separator
    popa
    ret

cmd_select:
    pusha
    mov     si, input_buf + 4
    call    skip_spaces
    call    parse_decimal
    jc      .bad
    cmp     ax, [payload_count]
    jge     .oob
    mov     [selected_idx], ax
    call    ui_redraw_payload_list
    mov     si, str_sel_ok
    call    log_accent
    popa
    ret
.bad:
    mov     si, str_err_bad_idx
    call    log_error
    popa
    ret
.oob:
    mov     si, str_err_oob
    call    log_error
    popa
    ret

cmd_hexdump:
    pusha
    mov     si, input_buf + 5
    call    skip_spaces
    call    parse_hex_word
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
    ret

.bad:
    mov     si, str_err_bad_addr
    call    log_error
    popa
    ret

ui_full_redraw:
    call    ui_draw_frame
    call    ui_redraw_payload_list
    call    ui_redraw_log
    call    ui_draw_statusbar
    call    ui_draw_prompt
    ret

ui_draw_frame:
    pusha
    push    es
    mov     ax, VGA_SEG
    mov     es, ax

    xor     di, di
    mov     cx, SCREEN_ROWS * SCREEN_COLS
    mov     ax, (0x01 << 8) | 0x20
    rep     stosw

    mov     di, TITLE_ROW * VGA_ROW_BYTES
    mov     cx, SCREEN_COLS
    mov     ax, (0x40 << 8) | 0x20
    rep     stosw
    mov     di, TITLE_ROW * VGA_ROW_BYTES
    mov     si, str_title
    mov     ah, COL_TITLE
    call    vga_puts

    mov     di, (TITLE_ROW * SCREEN_COLS + 60) * 2
    mov     si, str_build
    mov     ah, 0x4B
    call    vga_puts

    mov     di, DIVIDER_ROW * VGA_ROW_BYTES
    mov     cx, SCREEN_COLS
    mov     ax, (COL_DIM << 8) | 0xCD
    rep     stosw
    mov     di, DIVIDER_ROW * VGA_ROW_BYTES
    mov     ax, (COL_DIM << 8) | 0xC9
    stosw
    mov     di, (DIVIDER_ROW * SCREEN_COLS + 79) * 2
    mov     ax, (COL_DIM << 8) | 0xBB
    stosw

    mov     di, SUB_ROW * VGA_ROW_BYTES
    mov     cx, SCREEN_COLS
    mov     ax, (COL_DIM << 8) | 0x20
    rep     stosw
    mov     di, (SUB_ROW * SCREEN_COLS + 1) * 2
    mov     si, str_subtitle
    mov     ah, COL_ACCENT
    call    vga_puts

    mov     di, DIVIDER2_ROW * VGA_ROW_BYTES
    mov     cx, SCREEN_COLS
    mov     ax, (COL_DIM << 8) | 0xC4
    rep     stosw
    mov     di, DIVIDER2_ROW * VGA_ROW_BYTES
    mov     ax, (COL_DIM << 8) | 0xC7
    stosw
    mov     di, (DIVIDER2_ROW * SCREEN_COLS + 79) * 2
    mov     ax, (COL_DIM << 8) | 0xB6
    stosw

    mov     bx, PANEL_START_ROW
.borders:
    cmp     bx, PANEL_END_ROW
    jg      .borders_done

    mov     di, bx
    imul    di, di, SCREEN_COLS
    shl     di, 1
    mov     ax, (COL_DIM << 8) | 0xB3
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
    mov     ax, (COL_DIM << 8) | 0xB3
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
    mov     ah, COL_DIM
    call    vga_puts

    mov     di, (PANEL_START_ROW * SCREEN_COLS + RIGHT_PANEL_START + 1) * 2
    mov     si, str_panel_log
    mov     ah, COL_DIM
    call    vga_puts

    mov     di, PANEL_END_ROW * VGA_ROW_BYTES
    mov     cx, SCREEN_COLS
    mov     ax, (COL_DIM << 8) | 0xC4
    rep     stosw
    mov     di, PANEL_END_ROW * VGA_ROW_BYTES
    mov     ax, (COL_DIM << 8) | 0xC0
    stosw
    mov     di, (PANEL_END_ROW * SCREEN_COLS + LEFT_PANEL_COLS) * 2
    mov     ax, (COL_DIM << 8) | 0xC1
    stosw
    mov     di, (PANEL_END_ROW * SCREEN_COLS + LEFT_PANEL_COLS + 1) * 2
    mov     ax, (COL_DIM << 8) | 0xC4
    stosw
    mov     di, (PANEL_END_ROW * SCREEN_COLS + 79) * 2
    mov     ax, (COL_DIM << 8) | 0xD9
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
    mov     ax, (COL_STATUS << 8) | 0x20
    rep     stosw
    mov     di, STATUS_ROW * VGA_ROW_BYTES
    mov     si, str_status
    mov     ah, COL_STATUS
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
    mov     ax, (COL_DIM << 8) | 0x20
    rep     stosw

    mov     di, PROMPT_ROW * VGA_ROW_BYTES
    mov     si, str_prompt
    mov     ah, COL_SUCCESS
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
    mov     ax, (0x01 << 8) | 0x20
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

    mov     ax, (COL_SELECTED << 8) | 0x10
    stosw
    stosw
    sub     di, 4
    add     di, 4
    mov     ah, COL_SELECTED
    jmp     .print

.normal:
    add     di, 4
    mov     ah, COL_NORMAL

    cmp     byte [payload_flags + cx], 0x02
    jne     .print
    mov     ah, COL_WARN

.print:
    push    cx
    mov     ax, cx
    mov     bx, PAYLOAD_NAME_LEN
    mul     bx
    mov     si, payload_names
    add     si, ax
    call    vga_puts
    pop     cx
    inc     cx

    mov     bx, PANEL_START_ROW + 1
    add     bx, cx
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
    mov     ax, (0x01 << 8) | 0x20
    rep     stosw
    inc     bx
    jmp     .clear
.clear_done:

    mov     ax, [log_line_count]
    mov     cx, PANEL_END_ROW - PANEL_START_ROW - 1
    sub     ax, cx
    jge     .set_start
    xor     ax, ax
.set_start:
    add     ax, [log_scroll_offset]

    mov     cx, ax
    mov     bx, PANEL_START_ROW + 1

.render:
    cmp     bx, PANEL_END_ROW
    jge     .done
    cmp     cx, [log_line_count]
    jge     .done

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

    mov     ax, cx
    mov     ah, [log_colors + cx]

    call    vga_puts
    pop     cx
    pop     bx

    inc     cx
    inc     bx
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
    mov     [log_colors + ax], bl
    inc     word [log_line_count]
    call    ui_redraw_log
    popa
    ret

log_accent:
    mov     bl, COL_ACCENT
    call    log_colored
    ret

log_error:
    mov     bl, COL_ERROR
    call    log_colored
    ret

log_separator:
    pusha
    mov     si, str_sep
    mov     bl, COL_DIM
    call    log_colored
    popa
    ret

log_add_line:
    pusha
    mov     ax, [log_line_count]
    cmp     ax, LOG_MAX_LINES
    jl      .ok
    call    log_scroll_up
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

log_scroll_up:
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

log_partial_col:
    ret

emit_newline:
    pusha
    mov     word [partial_col], 0
    inc     word [log_line_count]
    cmp     word [log_line_count], LOG_MAX_LINES
    jl      .ok
    call    log_scroll_up
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
    push    ax
    shr     al, 4
    call    nibble_out
    pop     ax
    and     al, 0x0F
    call    nibble_out
    call    emit_newline
    ret

emit_hex_byte_sp:
    push    ax
    push    si
    push    ax
    shr     al, 4
    call    nibble_out
    pop     ax
    and     al, 0x0F
    call    nibble_out
    mov     si, str_space
    call    log_partial
    pop     si
    pop     ax
    ret

emit_hex_byte_inline:
    push    ax
    shr     al, 4
    call    nibble_out
    pop     ax
    and     al, 0x0F
    call    nibble_out
    ret

log_decimal:
    pusha
    call    uint_to_str
    mov     si, dec_buf
    call    log_partial
    popa
    ret

nibble_out:
    push    si
    push    ax
    and     al, 0x0F
    cmp     al, 9
    jbe     .digit
    add     al, 7
.digit:
    add     al, 0x30
    mov     [nibble_tmp], al
    mov     si, nibble_tmp
    call    log_partial
    pop     ax
    pop     si
    ret

uint_to_str:
    pusha
    mov     di, dec_buf + 9
    mov     byte [di], 0
    mov     bx, 10
    test    ax, ax
    jnz     .divide
    dec     di
    mov     byte [di], '0'
    jmp     .done
.divide:
    test    ax, ax
    jz      .done
    xor     dx, dx
    div     bx
    add     dl, '0'
    dec     di
    mov     [di], dl
    jmp     .divide
.done:
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

    mov     cx, HIST_ENTRY_SIZE - 1
    xor     ax, ax
    repne   scasb
    sub     di, input_buf
    dec     di
    mov     [input_len], di

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

strcpy_bounded:
    push    si
    push    di
    mov     cx, PAYLOAD_NAME_LEN - 1
.loop:
    lodsb
    stosb
    test    al, al
    jz      .done
    loop    .loop
.done:
    mov     byte [di], 0
    pop     di
    pop     si
    ret

skip_spaces:
.loop:
    cmp     byte [si], 0x20
    jne     .done
    inc     si
    jmp     .loop
.done:
    ret

parse_decimal:
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
    mov     dx, 10
    mul     dx
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

parse_hex_word:
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
nibble_tmp          db 0, 0

cpu_vendor          times 13 db 0
cpu_brand           times 50 db 0
dec_buf             times 11 db 0
input_buf           times INPUT_BUF_SIZE db 0
payload_names       times MAX_PAYLOADS * PAYLOAD_NAME_LEN db 0
payload_flags       times MAX_PAYLOADS db 0
hist_buf            times HIST_DEPTH * HIST_ENTRY_SIZE db 0
log_buf             times LOG_MAX_LINES * LOG_LINE_LEN db 0
log_colors          times LOG_MAX_LINES db 0

str_title           db "  SX-SANDBOX  >>  SHELLCODE EXECUTION & ANALYSIS ENVIRONMENT  //  x86 REAL MODE", 0
str_build           db "BUILD 2.0.0", 0
str_subtitle        db "Arch: x86-16  |  Mode: Real  |  BIOS: Legacy INT  |  Target: 0xA000", 0
str_panel_payloads  db "PAYLOADS", 0
str_panel_log       db "EXECUTION LOG", 0
str_status          db "  [ENTER] Run  [UP/DN] History  |  run  list  sel <n>  dump <addr>  sandbox  info  clear  help", 0
str_prompt          db "sx-sandbox> ", 0
str_sep             db "------------------------------------------------------", 0
str_env_start       db "[ENV] Running environment security checks...", 0
str_nx_on           db "  [NX/DEP]  ACTIVE   -- memory regions write-xor-exec", 0
str_nx_off          db "  [NX/DEP]  INACTIVE -- regions are RWX, no exec guard", 0
str_smep_on         db "  [SMEP]    ACTIVE   -- supervisor exec of user pages blocked", 0
str_smep_off        db "  [SMEP]    INACTIVE -- ring0 can exec user-mode pages", 0
str_cpuid_hdr       db "  [CPUID]   Vendor identification complete", 0
str_vendor_pfx      db "    Vendor  : ", 0
str_ram_pfx         db "    RAM     : ", 0
str_a20_on          db "  [A20]     ENABLED  -- full 21-bit address space active", 0
str_a20_off         db "  [A20]     DISABLED -- address line 20 wrap-around mode", 0
str_kb              db " KB conventional", 0
str_exec_dispatch   db "[EXEC] Dispatching selected payload...", 0
str_pfx_target      db "  Target  : ", 0
str_sandbox_active  db "  Sandbox : active | pre-exec scan complete", 0
str_err_no_payload  db "[ERR] No valid payload selected. Use: sel <n>", 0
str_err_unknown     db "[ERR] Unknown command. Type 'help' for usage.", 0
str_list_hdr        db "[PAYLOADS] Available shellcode modules:", 0
str_sel_marker      db "  [*] ", 0
str_unsel_marker    db "  [ ] ", 0
str_info_hdr        db "[INFO] SX-SANDBOX System Information", 0
str_info_1          db "  Engine  : 16-bit real mode shellcode loader/sandbox", 0
str_info_2          db "  Stage2  : 0x7E00  (this module, 12 sectors)", 0
str_info_3          db "  Sandbox : 0x9000  (protection layer, 8 sectors)", 0
str_info_4          db "  Payload : 0xA000  (runtime injection target)", 0
str_help_hdr        db "[HELP] Command Reference:", 0
str_help_run        db "  run              Execute selected payload through sandbox", 0
str_help_list       db "  list             List all available payload modules", 0
str_help_sel        db "  sel <n>          Select payload by index number", 0
str_help_sandbox    db "  sandbox          Re-run environment security checks", 0
str_help_dump       db "  dump <hex>       Hexdump 32 bytes at hex address", 0
str_help_info       db "  info             Display system memory and module info", 0
str_help_clear      db "  clear            Clear the execution log panel", 0
str_sel_ok          db "[OK] Payload selection updated.", 0
str_err_bad_idx     db "[ERR] Invalid index format. Provide a decimal number.", 0
str_err_oob         db "[ERR] Index out of range.", 0
str_err_bad_addr    db "[ERR] Invalid address. Use hex format, e.g.: dump 7c00", 0
str_msgbox_hdr      db "[PAYLOAD:MSGBOX] Writing segment probe stub to 0xA000...", 0
str_injected        db "  Shellcode written. Transferring control to 0xA000...", 0
str_returned        db "  Returned cleanly. Stack and segment registers intact.", 0
str_memwalk_hdr     db "[PAYLOAD:MEMWALK] Dumping BIOS Data Area (0x0400+):", 0
str_port_hdr        db "[PAYLOAD:PORTPROBE] Sampling I/O ports (0x03F8 base):", 0
str_stack_hdr       db "[PAYLOAD:STACKSMASH] Analyzing stack frame integrity...", 0
str_canary_write    db "  Writing canary pattern 0xDEAD x4 to stack...", 0
str_stack_ok        db "  All canaries intact. Stack integrity: PASS", 0
str_stack_corrupt   db "[ERR] Stack corruption detected! Canary mismatch.", 0
str_nx_hdr          db "[PAYLOAD:NXPROBE] Testing execute permission on 0xA000...", 0
str_nx_exec         db "  NX inactive. Writing RET stub and executing...", 0
str_nx_done         db "  Execution from data region succeeded. NX: ABSENT", 0
str_nx_blocked      db "  NX active. Direct execution attempt would fault.", 0
str_cpu_hdr         db "[PAYLOAD:CPUINFO] Enumerating CPU via CPUID leaves...", 0
str_ivt_hdr         db "[PAYLOAD:IVTDUMP] Dumping interrupt vector table (0x0000):", 0
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
str_pl_portprobe    db "PORTPROBE  - I/O port sampler", 0
str_pl_stacksmash   db "STACKSMASH - Canary integrity test [!]", 0
str_pl_nxprobe      db "NXPROBE    - NX/DEP execution probe", 0
str_pl_cpuinfo      db "CPUINFO    - Full CPUID enumeration", 0
str_pl_ivtdump      db "IVTDUMP    - IVT vector dump (INT 0-15)", 0

cmd_run             db "RUN", 0
cmd_list            db "LIST", 0
cmd_info            db "INFO", 0
cmd_clear           db "CLEAR", 0
cmd_help            db "HELP", 0
cmd_sel             db "SEL", 0
cmd_sandbox         db "SANDBOX", 0
cmd_dump            db "DUMP", 0

times 6144 - ($ - $$) db 0