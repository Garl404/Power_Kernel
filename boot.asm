; MYOS microkernel boot sector
; NASM, BIOS, x86 32-bit
bits 16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    mov [boot_drive], dl

    mov si, msg
    call print

    ; Load kernel from LBA 1 to physical 0x1000.
    mov si, dap
    mov dl, [boot_drive]
    mov ah, 0x42
    int 0x13
    jc disk_error

    cli
    in al, 0x92
    or al, 2
    out 0x92, al

    lgdt [gdt_desc]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected

disk_error:
    mov si, err
    call print
.hang:
    cli
    hlt
    jmp .hang

print:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print
.done:
    ret

bits 32
protected:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov esp, 0x90000
    jmp 0x1000

align 8
gdt:
    dq 0
    ; code
    dw 0xFFFF, 0
    db 0, 10011010b, 11001111b, 0
    ; data
    dw 0xFFFF, 0
    db 0, 10010010b, 11001111b, 0
gdt_end:

gdt_desc:
    dw gdt_end-gdt-1
    dd gdt

boot_drive db 0
msg db "MYOS microkernel boot...",13,10,0
err db "Disk read error.",13,10,0

dap:
    db 0x10, 0
    dw 64
    dw 0x1000
    dw 0
    dq 1

times 510-($-$$) db 0
dw 0xAA55
