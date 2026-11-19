%ifndef CONFIG_POLICIES_ASM
%define CONFIG_POLICIES_ASM

POLICY_ALLOW_ALL        equ 0x00
POLICY_BLOCK_DANGER     equ 0x01
POLICY_AUDIT_ONLY       equ 0x02
POLICY_LOCKDOWN         equ 0x03

EXEC_FLAG_SAFE          equ 0x01
EXEC_FLAG_DANGEROUS     equ 0x02
EXEC_FLAG_RING0         equ 0x04
EXEC_FLAG_IO_ACCESS     equ 0x08

SCAN_DEPTH_MIN          equ 128
SCAN_DEPTH_MAX          equ 512

REPORT_MAX              equ 32
REPORT_ENTRY_SIZE       equ 16

LOG_MAX                 equ 64
LOG_ENTRY_SIZE          equ 48

%endif
