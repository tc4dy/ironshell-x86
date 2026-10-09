BITS 16
ORG 0x9000

POLICY_ALLOW_ALL        equ 0x00
POLICY_BLOCK_DANGER     equ 0x01
POLICY_AUDIT_ONLY       equ 0x02
POLICY_LOCKDOWN         equ 0x03

EXEC_FLAG_DANGEROUS     equ 0x02
EXEC_FLAG_RING0         equ 0x04
EXEC_FLAG_IO_ACCESS     equ 0x08

SHELLCODE_BASE          equ 0xA000
SHELLCODE_LIMIT         equ 0xAFFF
SCAN_DEPTH              equ 128

IVT_ENTRY_COUNT         equ 256
IVT_ENTRY_SIZE          equ 4

REPORT_MAX              equ 32
REPORT_ENTRY_SIZE       equ 16

LOG_MAX                 equ 64
LOG_ENTRY_SIZE          equ 48

sandbox_api:
sandbox_api_entry:      jmp near sandbox_entry
sandbox_api_post_exec:  jmp near sandbox_post_exec
sandbox_api_set_policy: jmp near sandbox_set_policy
sandbox_api_get_policy: jmp near sandbox_get_policy
sandbox_api_get_report: jmp near sandbox_get_report
sandbox_api_reset:      jmp near sandbox_reset

sandbox_entry:
    push    bp
    mov     bp, sp
    pusha
    push    ds
    push    es

    xor     ax, ax
    mov     ds, ax
    mov     es, ax

    mov     al, [bp+8]
    mov     [payload_flags], al

    mov     ax, [bp+6]
    mov     [payload_index], ax

    call    sb_pre_exec
    jc      .blocked

    call    sb_snapshot_ivt
    call    sb_snapshot_regs
    clc
    jmp     .exit

.blocked:
    stc

.exit:
    pop     es
    pop     ds
    popa
    pop     bp
    retf    4

sandbox_post_exec:
    pusha
    push    ds
    push    es

    xor     ax, ax
    mov     ds, ax
    mov     es, ax

    call    sb_diff_ivt_restore
    call    sb_check_regs
    call    sb_record_event
    call    sb_update_score

    pop     es
    pop     ds
    popa
    retf

sandbox_set_policy:
    cmp     al, POLICY_LOCKDOWN
    ja      .reject
    mov     [active_policy], al
    mov     si, msg_policy_updated
    call    sb_log_info
    clc
    retf
.reject:
    stc
    retf

sandbox_get_policy:
    mov     al, [active_policy]
    retf

sandbox_get_report:
    mov     bx, report_buf
    mov     cx, [report_count]
    retf

sandbox_reset:
    pusha
    call    sb_clear_report
    call    sb_clear_log
    mov     byte [active_policy], POLICY_BLOCK_DANGER
    mov     word [report_count], 0
    mov     word [violation_count], 0
    mov     word [exec_count], 0
    mov     byte [policy_score], 100
    popa
    retf

sb_pre_exec:
    pusha

    cmp     byte [active_policy], POLICY_LOCKDOWN
    je      .lockdown

    cmp     byte [active_policy], POLICY_AUDIT_ONLY
    je      .audit

    mov     al, [payload_flags]
    test    al, EXEC_FLAG_DANGEROUS
    jz      .bounds

    cmp     byte [active_policy], POLICY_ALLOW_ALL
    je      .bounds

    cmp     byte [active_policy], POLICY_BLOCK_DANGER
    je      .dangerous

    jmp     .bounds

.bounds:
    call    sb_check_bounds
    jc      .oob

    call    sb_scan_opcodes
    jc      .badop

    popa
    clc
    ret

.lockdown:
    mov     si, msg_lockdown
    call    sb_log_violation
    jmp     .fail

.dangerous:
    mov     si, msg_blocked_danger
    call    sb_log_violation
    jmp     .fail

.oob:
    mov     si, msg_oob
    call    sb_log_violation
    jmp     .fail

.badop:
    mov     si, msg_bad_opcode
    call    sb_log_violation
    jmp     .fail

.audit:
    mov     si, msg_audit_pass
    call    sb_log_info
    popa
    clc
    ret

.fail:
    inc     word [violation_count]
    popa
    stc
    ret

sb_check_bounds:
    push    ax
    mov     ax, [payload_exec_addr]
    cmp     ax, SHELLCODE_BASE
    jb      .fail
    cmp     ax, SHELLCODE_LIMIT
    ja      .fail
    pop     ax
    clc
    ret
.fail:
    pop     ax
    stc
    ret

sb_scan_opcodes:
    push    es
    push    si
    push    cx

    xor     ax, ax
    mov     es, ax
    mov     si, SHELLCODE_BASE
    mov     cx, SCAN_DEPTH

.loop:
    mov     al, [es:si]
    inc     si
    dec     cx

    cmp     al, 0xEE
    je      .io
    cmp     al, 0xEF
    je      .io
    cmp     al, 0xEC
    je      .io
    cmp     al, 0xED
    je      .io
    cmp     al, 0xFA
    je      .cli_insn
    cmp     al, 0xFB
    je      .sti_insn
    cmp     al, 0xF4
    je      .hlt_insn
    cmp     al, 0x0F
    je      .prefix_0f
    cmp     al, 0xCD
    je      .prefix_int

    test    cx, cx
    jnz     .loop
    jmp     .clean

.prefix_0f:
    test    cx, cx
    jz      .clean
    mov     al, [es:si]
    inc     si
    dec     cx
    cmp     al, 0x01
    je      .priv
    cmp     al, 0x09
    je      .priv
    cmp     al, 0x30
    je      .priv
    cmp     al, 0x32
    je      .priv
    test    cx, cx
    jnz     .loop
    jmp     .clean

.prefix_int:
    test    cx, cx
    jz      .clean
    mov     al, [es:si]
    inc     si
    dec     cx
    cmp     al, 0x13
    je      .int13
    cmp     al, 0x1A
    je      .int1a
    cmp     al, 0x15
    je      .int15
    test    cx, cx
    jnz     .loop
    jmp     .clean

.io:
    push    si
    mov     si, msg_scan_io
    call    sb_log_info
    pop     si
    jmp     .clean

.cli_insn:
    push    si
    mov     si, msg_scan_cli
    call    sb_log_info
    pop     si
    jmp     .clean

.sti_insn:
    push    si
    mov     si, msg_scan_sti
    call    sb_log_info
    pop     si
    jmp     .clean

.hlt_insn:
    mov     si, msg_scan_hlt
    call    sb_log_violation
    pop     cx
    pop     si
    pop     es
    stc
    ret

.int13:
    push    si
    mov     si, msg_scan_int13
    call    sb_log_info
    pop     si
    jmp     .clean

.int1a:
    push    si
    mov     si, msg_scan_rtc
    call    sb_log_info
    pop     si
    jmp     .clean

.int15:
    push    si
    mov     si, msg_scan_e820
    call    sb_log_info
    pop     si
    jmp     .clean

.priv:
    mov     si, msg_scan_priv
    call    sb_log_violation
    pop     cx
    pop     si
    pop     es
    stc
    ret

.clean:
    pop     cx
    pop     si
    pop     es
    clc
    ret

sb_snapshot_ivt:
    pusha
    push    es
    push    ds

    xor     ax, ax
    mov     ds, ax
    mov     es, ax

    xor     si, si
    mov     di, ivt_snap
    mov     cx, IVT_ENTRY_COUNT * 2
    rep     movsw

    pop     ds
    pop     es
    popa
    ret

sb_diff_ivt_restore:
    pusha
    push    ds

    xor     ax, ax
    mov     ds, ax

    xor     si, si
    mov     di, ivt_snap
    mov     cx, IVT_ENTRY_COUNT
    xor     bx, bx

.check:
    mov     ax, [si]
    cmp     ax, [di]
    jne     .modified
    mov     ax, [si+2]
    cmp     ax, [di+2]
    je      .next_entry

.modified:
    mov     [ivt_vec_num], bx
    mov     ax, [si]
    mov     [ivt_new_off], ax
    mov     ax, [si+2]
    mov     [ivt_new_seg], ax
    mov     ax, [di]
    mov     [ivt_old_off], ax
    mov     ax, [di+2]
    mov     [ivt_old_seg], ax

    mov     ax, [di]
    mov     [si], ax
    mov     ax, [di+2]
    mov     [si+2], ax

    push    si
    push    di
    push    cx
    push    bx
    mov     si, msg_ivt_restored
    call    sb_log_violation
    inc     word [violation_count]
    pop     bx
    pop     cx
    pop     di
    pop     si

.next_entry:
    add     si, IVT_ENTRY_SIZE
    add     di, IVT_ENTRY_SIZE
    inc     bx
    loop    .check

    pop     ds
    popa
    ret

sb_snapshot_regs:
    mov     [snap_ax], ax
    mov     [snap_bx], bx
    mov     [snap_cx], cx
    mov     [snap_dx], dx
    mov     [snap_si], si
    mov     [snap_di], di
    mov     [snap_bp], bp
    mov     [snap_sp], sp
    mov     [snap_ss], ss
    mov     [snap_ds], ds
    mov     [snap_es], es
    pushf
    pop     ax
    mov     [snap_flags], ax
    ret

sb_check_regs:
    pusha

    mov     ax, ss
    cmp     ax, [snap_ss]
    jne     .ss_bad

    mov     ax, ds
    cmp     ax, [snap_ds]
    jne     .ds_bad

    jmp     .done

.ss_bad:
    mov     si, msg_ss_changed
    call    sb_log_violation
    inc     word [violation_count]
    jmp     .done

.ds_bad:
    mov     si, msg_ds_changed
    call    sb_log_violation
    inc     word [violation_count]

.done:
    popa
    ret

sb_record_event:
    pusha

    mov     ax, [report_count]
    cmp     ax, REPORT_MAX
    jge     .full

    mov     bx, REPORT_ENTRY_SIZE
    mul     bx
    mov     di, report_buf
    add     di, ax

    mov     ax, [exec_count]
    stosw
    mov     al, [payload_index]
    stosb
    mov     al, [payload_flags]
    stosb
    mov     al, [active_policy]
    stosb
    mov     ax, [violation_count]
    stosw
    mov     al, [policy_score]
    stosb

    inc     word [exec_count]
    inc     word [report_count]

.full:
    popa
    ret

sb_update_score:
    pusha
    mov     al, [policy_score]
    mov     bx, [violation_count]
    test    bx, bx
    jz      .done

    cmp     bx, 5
    jge     .heavy

    sub     al, 5
    jmp     .store

.heavy:
    sub     al, 20

.store:
    jnc     .save
    xor     al, al
.save:
    mov     [policy_score], al

.done:
    popa
    ret

sb_log_violation:
    pusha
    push    ds
    push    es

    xor     ax, ax
    mov     ds, ax
    mov     es, ax

    mov     ax, [log_ptr]
    cmp     ax, LOG_MAX * LOG_ENTRY_SIZE
    jge     .full

    mov     di, log_buf
    add     di, ax

    mov     byte [di], 0x01
    inc     di

    mov     cx, LOG_ENTRY_SIZE - 2
.copy:
    lodsb
    test    al, al
    jz      .pad
    stosb
    loop    .copy
    jmp     .term
.pad:
    xor     al, al
    rep     stosb
.term:
    mov     byte [di], 0
    add     word [log_ptr], LOG_ENTRY_SIZE
    inc     word [log_count]

.full:
    pop     es
    pop     ds
    popa
    ret

sb_log_info:
    pusha
    push    ds
    push    es

    xor     ax, ax
    mov     ds, ax
    mov     es, ax

    mov     ax, [log_ptr]
    cmp     ax, LOG_MAX * LOG_ENTRY_SIZE
    jge     .full

    mov     di, log_buf
    add     di, ax

    mov     byte [di], 0x00
    inc     di

    mov     cx, LOG_ENTRY_SIZE - 2
.copy:
    lodsb
    test    al, al
    jz      .pad
    stosb
    loop    .copy
    jmp     .term
.pad:
    xor     al, al
    rep     stosb
.term:
    mov     byte [di], 0
    add     word [log_ptr], LOG_ENTRY_SIZE
    inc     word [log_count]

.full:
    pop     es
    pop     ds
    popa
    ret

sb_clear_report:
    pusha
    mov     di, report_buf
    mov     cx, REPORT_MAX * REPORT_ENTRY_SIZE
    xor     al, al
    rep     stosb
    mov     word [report_count], 0
    popa
    ret

sb_clear_log:
    pusha
    mov     di, log_buf
    mov     cx, LOG_MAX * LOG_ENTRY_SIZE
    xor     al, al
    rep     stosb
    mov     word [log_ptr], 0
    mov     word [log_count], 0
    popa
    ret

active_policy       db POLICY_BLOCK_DANGER
policy_score        db 100
violation_count     dw 0
exec_count          dw 0
report_count        dw 0
log_ptr             dw 0
log_count           dw 0

payload_flags       db 0
payload_index       dw 0
payload_exec_addr   dw SHELLCODE_BASE

ivt_vec_num         dw 0
ivt_new_off         dw 0
ivt_new_seg         dw 0
ivt_old_off         dw 0
ivt_old_seg         dw 0

snap_ax             dw 0
snap_bx             dw 0
snap_cx             dw 0
snap_dx             dw 0
snap_si             dw 0
snap_di             dw 0
snap_bp             dw 0
snap_sp             dw 0
snap_ss             dw 0
snap_ds             dw 0
snap_es             dw 0
snap_flags          dw 0

ivt_snap            times IVT_ENTRY_COUNT * IVT_ENTRY_SIZE db 0
report_buf          times REPORT_MAX * REPORT_ENTRY_SIZE db 0
log_buf             times LOG_MAX * LOG_ENTRY_SIZE db 0

msg_blocked_danger  db "[SANDBOX:BLOCK] Payload flagged DANGEROUS -- BLOCK_DANGER active", 0
msg_lockdown        db "[SANDBOX:BLOCK] Execution denied -- LOCKDOWN policy active", 0
msg_oob             db "[SANDBOX:BLOCK] Payload address outside permitted exec region", 0
msg_bad_opcode      db "[SANDBOX:BLOCK] Privileged opcode detected in payload scan", 0
msg_audit_pass      db "[SANDBOX:AUDIT] Execution permitted under audit-only policy", 0
msg_ivt_restored    db "[SANDBOX:RESTORE] IVT vector modified -- auto-restored to snapshot", 0
msg_ss_changed      db "[SANDBOX:ALERT] Stack segment register modified by payload", 0
msg_ds_changed      db "[SANDBOX:ALERT] Data segment register modified by payload", 0
msg_scan_io         db "[SANDBOX:SCAN]  IN/OUT port access opcode detected", 0
msg_scan_cli        db "[SANDBOX:SCAN]  CLI instruction detected (interrupt disable)", 0
msg_scan_sti        db "[SANDBOX:SCAN]  STI instruction detected (interrupt enable)", 0
msg_scan_hlt        db "[SANDBOX:BLOCK] HLT instruction detected -- system freeze risk", 0
msg_scan_priv       db "[SANDBOX:BLOCK] Privileged system opcode in payload (MSR/WBINVD)", 0
msg_scan_int13      db "[SANDBOX:SCAN]  INT 13h disk BIOS call detected", 0
msg_scan_rtc        db "[SANDBOX:SCAN]  INT 1Ah RTC BIOS call detected", 0
msg_scan_e820       db "[SANDBOX:SCAN]  INT 15h memory query detected", 0
msg_policy_updated  db "[SANDBOX:POLICY] Enforcement policy updated", 0

times 8192 - ($ - $$) db 0
