%include "config/memory.asm"
%include "config/errors.asm"
%include "config/policies.asm"
%include "lib/string.asm"
%include "lib/math.asm"
%include "ui/screen.asm"
%include "ui/log.asm"
%include "ui/input.asm"
%include "ui/menu.asm"
%include "core/sysinfo.asm"
%include "core/payloads.asm"

BITS 16
ORG STAGE2_OFF

stage2_main:
    xor     ax, ax
    mov     ss, ax
    mov     sp, 0x7BFC

    mov     ax, STAGE2_SEG
    mov     ds, ax
    mov     es, ax

    mov     [engine_drive], dl
    mov     word [last_error], ERR_NONE

    call    theme_init_defaults
    call    init_payloads
    call    log_init
    call    input_init

    call    ui_full_redraw
    call    run_env_checks
    call    shell_loop

    cli
    hlt

theme_init_defaults:
    mov     byte [th_normal],   COL_DEFAULT
    mov     byte [th_bright],   COL_BRIGHT
    mov     byte [th_success],  COL_SUCCESS
    mov     byte [th_error],    COL_ERROR
    mov     byte [th_warn],     COL_WARN
    mov     byte [th_accent],   COL_ACCENT
    mov     byte [th_dim],      COL_DIM
    mov     byte [th_selected], COL_SELECTED
    mov     byte [th_title],    COL_TITLE
    mov     byte [th_status],   COL_STATUS
    ret

run_env_checks:
    call    log_separator
    mov     si, str_env_start
    mov     bl, [th_accent]
    call    log_colored

    call    sysinfo_check_cpuid
    jc      .no_cpuid
    call    check_nx
    call    check_smep
    call    check_cpuid_vendor
.no_cpuid:

    call    check_ram
    call    check_a20
    call    log_separator
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

check_cpuid_vendor:
    pusha
    mov     eax, 0
    cpuid
    mov     [cpu_vendor], ebx
    mov     [cpu_vendor + 4], edx
    mov     [cpu_vendor + 8], ecx
    mov     byte [cpu_vendor + 12], 0

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
    call    sysinfo_conv_mem
    jc      .fail
    mov     si, str_ram_pfx
    call    log_partial
    mov     ax, [CONV_MEM_KB_ADDR]
    call    log_decimal
    mov     si, str_kb
    mov     bl, [th_dim]
    call    log_colored
    popa
    ret
.fail:
    mov     si, str_ram_fail
    mov     bl, [th_error]
    call    log_colored
    popa
    ret

check_a20:
    pusha
    call    sysinfo_check_a20
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

shell_loop:
    call    ui_draw_prompt
.main:
    call    input_readline
    call    dispatch_cmd
    jmp     .main

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
.clear:     call log_clear
            call ui_redraw_log_panel
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
    call    payload_dispatch
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
    call    far [sandbox_entry_ptr]
    pop     bp
    ret

sandbox_post:
    call    far [sandbox_post_ptr]
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

    push    ax
    call    far [theme_set_ptr]
    pop     ax
    jc      .bad

    mov     di, th_normal
    call    far [theme_copy_ptr]

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

    call    far [filter_set_ptr]
    jc      .bad

    call    ui_redraw_log_panel

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
    mov     al, bl
    call    far [filter_match_ptr]
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
    call    uint_to_str
    push    si
    mov     si, di
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

    cmp     cx, 5
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

    call    log_new_line
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
    call    uint_to_str
    mov     si, dec_buf
    call    log_partial
    popa
    ret

nibble_out:
    pusha
    call    hex_nibble_to_ascii
    mov     [nibble_tmp], al
    mov     byte [nibble_tmp + 1], 0
    mov     si, nibble_tmp
    call    log_partial
    popa
    ret

log_colored:
    pusha
    push    bx
    call    log_add_string
    dec     word [log_line_count]
    mov     ax, [log_line_count]
    pop     bx
    push    di
    mov     di, ax
    mov     [log_colors + di], bl
    pop     di
    inc     word [log_line_count]
    call    ui_redraw_log_panel
    popa
    ret

log_error_msg:
    mov     bl, [th_error]
    call    log_colored
    ret

log_partial:
    pusha
    mov     ax, [log_line_count]
    mov     bx, LOG_LINE_LEN
    mul     bx
    mov     di, log_buf
    add     di, ax
    mov     cx, [log_partial_col]
    add     di, cx

.copy:
    lodsb
    test    al, al
    jz      .done
    cmp     word [log_partial_col], LOG_LINE_LEN - 1
    jge     .done
    stosb
    inc     word [log_partial_col]
    jmp     .copy
.done:
    popa
    ret

emit_newline:
    pusha
    mov     word [log_partial_col], 0
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
    call    ui_redraw_log_panel
    popa
    ret

log_separator:
    pusha
    mov     si, str_sep
    mov     bl, [th_dim]
    call    log_colored
    popa
    ret

ui_redraw_log_panel:
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
    call    far [filter_match_ptr]
    pop     bx
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
    call    ui_vga_puts
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

ui_full_redraw:
    push    es
    xor     ax, ax
    mov     es, ax
    call    ui_draw_frame
    call    ui_redraw_payload_list
    call    ui_redraw_log_panel
    call    ui_draw_statusbar
    call    ui_draw_prompt
    pop     es
    ret

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

strcpy_bounded_name:
    push    cx
    mov     cx, PAYLOAD_NAME_LEN - 1
    call    strcpy_bounded
    pop     cx
    ret

engine_drive        db 0
nx_active           db 0
smep_active         db 0
cpuid_edx           dd 0
cpuid_ecx           dd 0
selected_idx        dw 0
payload_count       dw 0
last_error          dw 0
canary_depth        dw 4
port_base           dw 0x03F8
ivt_dump_count      dw 16

nibble_tmp          db 0, 0
cpu_vendor          times 13 db 0
cpu_brand           times 49 db 0
dec_buf             times 11 db 0
fmt_line_buf        times LOG_LINE_LEN + 2 db 0
payload_names       times MAX_PAYLOADS * PAYLOAD_NAME_LEN db 0
payload_args        times MAX_PAYLOADS * PAYLOAD_ARG_LEN db 0
payload_flags       times MAX_PAYLOADS db 0

th_normal           db COL_DEFAULT
th_bright           db COL_BRIGHT
th_success          db COL_SUCCESS
th_error            db COL_ERROR
th_warn             db COL_WARN
th_accent           db COL_ACCENT
th_dim              db COL_DIM
th_selected         db COL_SELECTED
th_title            db COL_TITLE
th_status           db COL_STATUS

sandbox_entry_ptr   dw SANDBOX_ORG + 0, 0x0000
sandbox_post_ptr    dw SANDBOX_ORG + 3, 0x0000
theme_set_ptr       dw THEME_ORG + 0, 0x0000
theme_copy_ptr      dw THEME_ORG + 42, 0x0000
filter_set_ptr      dw FILTER_ORG + 0, 0x0000
filter_match_ptr    dw FILTER_ORG + 6, 0x0000

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
str_err_no_payload  db "[ERR] No valid payload selected. Use: sel <n>", 0
str_err_unknown     db "[ERR] Unknown command. Type 'help' for usage.", 0
str_list_hdr        db "[PAYLOADS] Available shellcode modules:", 0
str_info_hdr        db "[INFO] SX-SANDBOX System Information", 0
str_info_1          db "  Engine  : 16-bit real mode shellcode loader/sandbox", 0
str_info_2          db "  Stage2  : 0x1000  (this module, 64 sectors)", 0
str_info_3          db "  Sandbox : 0x9000  (protection layer, 16 sectors)", 0
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
str_help_theme      db "  theme <1-5>      Set color theme", 0
str_help_themes     db "  themes           List all available themes", 0
str_help_filter     db "  filter <0-5>     Filter log by color", 0
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

times STAGE2_MAX_BYTES - ($ - $$) db 0
