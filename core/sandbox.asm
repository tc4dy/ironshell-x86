%include "config/memory.asm"
%include "config/errors.asm"
%include "config/policies.asm"
%include "core/ivt.asm"

BITS 16
ORG SANDBOX_ORG

sandbox_api:
sandbox_api_entry:      jmp near sandbox_entry
sandbox_api_post_exec:  jmp near sandbox_post_exec
sandbox_api_set_policy: jmp near sandbox_set_policy
sandbox_api_get_policy: jmp near sandbox_get_policy
sandbox_api_get_score:  jmp near sandbox_get_score
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

    call    sb_call_ivt_snapshot
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

    call    sb_call_ivt_diff
    call    sb_check_regs
    call    sb_update_score

    pop     es
    pop     ds
    popa
    retf

sandbox_set_policy:
    cmp     al, POLICY_LOCKDOWN
    ja      .reject
    mov     [active_policy], al
    clc
    retf
.reject:
    stc
    retf

sandbox_get_policy:
    mov     al, [active_policy]
    retf

sandbox_get_score:
    mov     al, [policy_score]
    retf

sandbox_reset:
    pusha
    mov     byte [active_policy], POLICY_BLOCK_DANGER
    mov     byte [policy_score], 100
    mov     word [violation_count], 0
    mov     word [exec_count], 0
    mov     byte [payload_flags], 0
    mov     word [payload_index], 0
    call    sb_call_ivt_clear
    popa
    retf

sb_call_ivt_snapshot:
    push    ds
    push    es
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    call    far [ivt_snapshot_ptr]
    pop     es
    pop     ds
    ret

sb_call_ivt_diff:
    push    ds
    push    es
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    call    far [ivt_diff_ptr]
    jnc     .no_diff
    
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    
    mov     si, msg_ivt_restored
    call    sb_log_violation
    inc     word [violation_count]
    
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax

.no_diff:
    pop     es
    pop     ds
    ret

sb_call_ivt_clear:
    push    ds
    push    es
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    call    far [ivt_clear_ptr]
    pop     es
    pop     ds
    ret

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
    popa
    clc
    ret

.fail:
    inc     word [violation_count]
    popa
    stc
    ret

sb_check_bounds:
    mov     ax, [payload_exec_addr]
    cmp     ax, SHELLCODE_BASE
    jb      .fail
    cmp     ax, SHELLCODE_LIMIT
    ja      .fail
    clc
    ret
.fail:
    stc
    ret

sb_scan_opcodes:
    push    es
    push    si
    push    cx
    push    bx

    xor     ax, ax
    mov     es, ax
    mov     si, SHELLCODE_BASE
    mov     cx, SCAN_DEPTH_MAX

.loop:
    test    cx, cx
    jz      .clean

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
    cmp     al, 0xF4
    je      .hlt_insn
    cmp     al, 0x0F
    je      .prefix_0f
    cmp     al, 0xCD
    je      .prefix_int
    jmp     .loop

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
    jmp     .loop

.prefix_int:
    test    cx, cx
    jz      .clean
    inc     si
    dec     cx
    jmp     .loop

.io:
    jmp     .loop

.hlt_insn:
    pop     bx
    pop     cx
    pop     si
    pop     es
    stc
    ret

.priv:
    pop     bx
    pop     cx
    pop     si
    pop     es
    stc
    ret

.clean:
    pop     bx
    pop     cx
    pop     si
    pop     es
    clc
    ret

sb_snapshot_regs:
    push    bp
    mov     bp, sp
    mov     ax, [bp+2]
    mov     [snap_bp], ax

    mov     [snap_ax], ax
    mov     [snap_bx], bx
    mov     [snap_cx], cx
    mov     [snap_dx], dx
    mov     [snap_si], si
    mov     [snap_di], di
    mov     [snap_sp], sp
    mov     ax, ss
    mov     [snap_ss], ax
    mov     ax, ds
    mov     [snap_ds], ax
    mov     ax, es
    mov     [snap_es], ax
    pushf
    pop     ax
    mov     [snap_flags], ax

    pop     bp
    ret

sb_check_regs:
    pusha

    mov     ax, ds
    cmp     ax, [snap_ds]
    jne     .ds_bad

    mov     ax, es
    cmp     ax, [snap_es]
    jne     .es_bad

    jmp     .done

.ds_bad:
    mov     si, msg_ds_changed
    call    sb_log_violation
    inc     word [violation_count]
    jmp     .done

.es_bad:
    mov     si, msg_es_changed
    call    sb_log_violation
    inc     word [violation_count]

.done:
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

    mov     ax, [sb_log_ptr]
    cmp     ax, LOG_MAX * LOG_ENTRY_SIZE
    jge     .full

    mov     di, sb_log_buf
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
    add     word [sb_log_ptr], LOG_ENTRY_SIZE
    inc     word [sb_log_count]

.full:
    pop     es
    pop     ds
    popa
    ret

active_policy       db POLICY_BLOCK_DANGER
policy_score        db 100
violation_count     dw 0
exec_count          dw 0
sb_log_ptr          dw 0
sb_log_count        dw 0

payload_flags       db 0
payload_index       dw 0
payload_exec_addr   dw SHELLCODE_BASE

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

ivt_snapshot_ptr    dw  ivt_snapshot, SANDBOX_SEG
ivt_diff_ptr        dw  ivt_diff_restore, SANDBOX_SEG
ivt_clear_ptr       dw  ivt_clear_snapshot, SANDBOX_SEG

sb_log_buf          times LOG_MAX * LOG_ENTRY_SIZE db 0

msg_blocked_danger  db "Payload flagged DANGEROUS, blocked by policy", 0
msg_lockdown        db "Execution denied, LOCKDOWN policy active", 0
msg_oob             db "Payload address outside permitted region", 0
msg_bad_opcode      db "Privileged opcode detected in payload scan", 0
msg_ivt_restored    db "IVT modified, auto-restored to snapshot", 0
msg_ds_changed      db "Data segment register modified by payload", 0
msg_es_changed      db "Extra segment register modified by payload", 0

times SANDBOX_MAX_BYTES - ($ - $$) db 0
