%ifndef CONFIG_ERRORS_ASM
%define CONFIG_ERRORS_ASM

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
ERR_LOADER_TOO_BIG      equ 0x0B
ERR_STAGE2_TOO_BIG      equ 0x0C
ERR_SANDBOX_TOO_BIG     equ 0x0D
ERR_THEME_TOO_BIG       equ 0x0E
ERR_FILTER_TOO_BIG      equ 0x0F

%endif
