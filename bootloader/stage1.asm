[BITS 16]
[ORG 0x7C00]

jmp short start
nop

oem_id db 'MYOS1.0 '
bpb:
  times 79 db 0

start:
  cli
  xor ax, ax
  mov ss, ax
  mov sp, 0x7C00
  mov ds, ax
  mov es, ax

  mov ah, 0x00
  mov dl, 0x80
  int 0x13
  jc disk_reset_failed

  mov ah, 0x02
  mov al, 1
  mov ch, 0x00
  mov cl, 8
  mov dh, 0x00
  mov dl, 0x80
  mov bx, 0x1000
  int 0x13
  jc load_failed

  mov ah, 0x02
  mov al, 20
  mov ch, 0x00
  mov cl, 9
  mov dh, 0x00
  mov dl, 0x80
  mov bx, 0x8000
  int 0x13
  jc load_failed

  jmp 0x1000

disk_reset_failed:
  jmp halt

load_failed:
  jmp halt

halt:
  hlt
  jmp halt

times 510-($-$$) db 0
dw 0xAA55
