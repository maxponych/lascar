OUTPUT_FORMAT("elf64-x86-64")
ENTRY(fs_parser)

SECTIONS
{
    . = 0x8000;

    .text : {
        *(.text)
    }

    .rodata : {
        *(.rodata)
    }

    .data : {
        *(.data)
    }

    .bss : {
        *(.bss)
        *(COMMON)
    }
}
