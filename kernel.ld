OUTPUT_FORMAT("elf64-x86-64")
ENTRY(kmain)

SECTIONS
{
    . = 0x200000;

    .text.start : 
    { 
        KEEP(
            *(.text.start)
        ) 
    }

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
