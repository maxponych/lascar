[BITS 16]
[ORG 0x1000]

stack32_top equ 0x20000
stack64_top equ 0x60000

start:
  cli
  xor ax, ax
  mov ds, ax
  mov es, ax
  mov ss, ax
  mov sp, 0x7C00

  lgdt [gdt32_descriptor]

  mov eax, cr0
  or eax, 1
  mov cr0, eax

  jmp 0x08:pm_start

[BITS 32]
pm_start:
  mov ax, 0x10
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax
  mov esp, stack32_top

  call setup_page_tables
  mov eax, page_table_l4
  mov cr3, eax

  mov eax, cr4
  or eax, 1 << 5
  mov cr4, eax

  mov ecx, 0xC0000080
  rdmsr
  or eax, 1 << 8
  wrmsr

  mov eax, cr0
  or eax, 1 << 31
  mov cr0, eax

  lgdt [gdt64_descriptor]
  jmp 0x08:lm_start

setup_page_tables:
  mov edi, page_table_l4
  xor eax, eax
  mov ecx, 1024
  rep stosd
  mov edi, page_table_l3
  rep stosd
  mov edi, page_table_l2
  rep stosd

  mov eax, page_table_l3
  or eax, 3
  mov [page_table_l4], eax
  mov eax, page_table_l2
  or eax, 3
  mov [page_table_l3], eax    

  xor ecx, ecx
  mov edi, page_table_l2
.loop_pd:
  mov eax, ecx
  shl eax, 21
  or eax, 0x83
  mov [edi + ecx*8], eax
  inc ecx
  cmp ecx, 512
  jne .loop_pd
  ret

[BITS 64]
lm_start:
  mov ax, 0
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax
  mov rsp, stack64_top
  and rsp, -16

  mov rax, 0x8000
  jmp rax

section .data
align 4
gdt32_start:
  dq 0
  dq 0x00CF9A000000FFFF
  dq 0x00CF92000000FFFF
gdt32_end:
gdt32_descriptor:
  dw gdt32_end - gdt32_start - 1
  dd gdt32_start
  dw 0

gdt64_start:
  dq 0
  dq 0x0020980000000000
gdt64_end:
gdt64_descriptor:
  dw gdt64_end - gdt64_start - 1
  dq gdt64_start

section .bss
align 4096
page_table_l4:
  resb 4096
page_table_l3:
  resb 4096
page_table_l2:
  resb 4096

