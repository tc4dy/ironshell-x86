%ifndef CONFIG_MEMORY_ASM
%define CONFIG_MEMORY_ASM

STAGE1_ORG              equ 0x7C00
STAGE1_SEG              equ 0x0000
STAGE1_OFF              equ 0x7C00

LOADER_ORG              equ 0x7E00
LOADER_SEG              equ 0x0000
LOADER_OFF              equ 0x7E00
LOADER_LBA              equ 1
LOADER_SECTORS          equ 4
LOADER_MAX_BYTES        equ 2048

STAGE2_ORG              equ 0x10000
STAGE2_SEG              equ 0x1000
STAGE2_OFF              equ 0x0000
STAGE2_LBA              equ 3
STAGE2_SECTORS          equ 64
STAGE2_MAX_BYTES        equ 32768

SANDBOX_ORG             equ 0x9000
SANDBOX_SEG             equ 0x0000
SANDBOX_OFF             equ 0x9000
SANDBOX_LBA             equ 67
SANDBOX_SECTORS         equ 16
SANDBOX_MAX_BYTES       equ 8192

SHELLCODE_BASE          equ 0xA000
SHELLCODE_LIMIT         equ 0xAFFF

THEME_ORG               equ 0xB000
THEME_SEG               equ 0x0000
THEME_OFF               equ 0xB000
THEME_LBA               equ 87
THEME_SECTORS           equ 2
THEME_MAX_BYTES         equ 1024

FILTER_ORG              equ 0xC000
FILTER_SEG              equ 0x0000
FILTER_OFF              equ 0xC000
FILTER_LBA              equ 89
FILTER_SECTORS          equ 2
FILTER_MAX_BYTES        equ 1024

IVT_BASE                equ 0x0000
IVT_ENTRY_COUNT         equ 256
IVT_ENTRY_SIZE          equ 4
IVT_TOTAL_BYTES         equ 1024

BDA_BASE                equ 0x0400
BDA_SIZE                equ 256

VGA_SEG                 equ 0xB800
VGA_OFF                 equ 0x0000
SCREEN_COLS             equ 80
SCREEN_ROWS             equ 25
VGA_ROW_BYTES           equ 160
VGA_TOTAL_BYTES         equ 4000

BOOT_DRIVE_ADDR         equ 0x0500
E820_COUNT_ADDR         equ 0x0502
E820_BUF_ADDR           equ 0x0504
E820_BUF_MAX            equ 32
E820_ENTRY_SIZE         equ 20
E820_SIGNATURE          equ 0x534D4150

CONV_MEM_KB_ADDR        equ 0x0514
A20_TEST_ADDR           equ 0x0516

COL_DEFAULT             equ 0x07
COL_BRIGHT              equ 0x0F
COL_SUCCESS             equ 0x0A
COL_ERROR               equ 0x0C
COL_WARN                equ 0x0E
COL_ACCENT              equ 0x0B
COL_DIM                 equ 0x08
COL_SELECTED            equ 0x2F
COL_TITLE               equ 0x4F
COL_STATUS              equ 0x30

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

%endif
