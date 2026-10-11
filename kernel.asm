; MYOS tiny microkernel
; All kernel code is 32-bit NASM.
bits 32
org 0x1000

VIDEO equ 0xB8000
PIC1 equ 0x20
PIC2 equ 0xA0
PIC1_DATA equ 0x21
PIC2_DATA equ 0xA1
PIT_CH0 equ 0x40
PIT_CMD equ 0x43

start:
    cli
    mov esp, stack_top
    call vga_clear
    mov esi, banner
    call puts

    call idt_setup
    call pic_setup
    call pit_setup
    call keyboard_setup

    sti
    mov esi, prompt
    call puts

.idle:
    hlt
    jmp .idle

; ---------------- VGA console ----------------
vga_clear:
    push eax
    push ecx
    push edi
    mov edi, VIDEO
    mov ax, 0x0720
    mov ecx, 80*25
    rep stosw
    mov dword [cur_x], 0
    mov dword [cur_y], 0
    pop edi
    pop ecx
    pop eax
    ret

newline:
    mov dword [cur_x], 0
    inc dword [cur_y]
    cmp dword [cur_y], 25
    jb .done
    call vga_clear
.done:
    ret

putc:
    push eax
    push ebx
    push ecx
    push edx
    cmp al, 10
    je .nl
    cmp al, 13
    je .cr
    mov ebx, [cur_y]
    imul ebx, 160
    mov ecx, [cur_x]
    imul ecx, 2
    add ebx, ecx
    add ebx, VIDEO
    mov [ebx], al
    mov byte [ebx+1], 0x07
    inc dword [cur_x]
    cmp dword [cur_x], 80
    jb .done
    call newline
    jmp .done
.nl:
    call newline
    jmp .done
.cr:
    mov dword [cur_x], 0
.done:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

puts:
.next:
    lodsb
    test al, al
    jz .done
    call putc
    jmp .next
.done:
    ret

; ---------------- IDT ----------------
idt_setup:
    lidt [idt_desc]
    ret

; 256 entries, each initially points to spurious_handler.
idt:
%assign i 0
%rep 256
    dw spurious_handler
    dw 0x08
    db 0
    db 10001110b
    dw spurious_handler >> 16
%assign i i+1
%endrep

idt_desc:
    dw idt_end-idt-1
    dd idt
idt_end:

spurious_handler:
    iretd

; ---------------- PIC 8259 ----------------
pic_setup:
    mov al, 0x11
    out PIC1, al
    out PIC2, al
    mov al, 0x20
    out PIC1_DATA, al
    mov al, 0x28
    out PIC2_DATA, al
    mov al, 4
    out PIC1_DATA, al
    mov al, 2
    out PIC2_DATA, al
    mov al, 1
    out PIC1_DATA, al
    out PIC2_DATA, al
    ; unmask IRQ0 (timer) and IRQ1 (keyboard)
    mov al, 0xFC
    out PIC1_DATA, al
    mov al, 0xFF
    out PIC2_DATA, al
    ret

; ---------------- PIT ----------------
pit_setup:
    ; 1193182 / 100 = 11931 => ~100 Hz
    mov al, 0x36
    out PIT_CMD, al
    mov ax, 11931
    out PIT_CH0, al
    mov al, ah
    out PIT_CH0, al
    ret

timer_irq:
    pushad
    inc dword [ticks]
    mov al, 0x20
    out PIC1, al
    popad
    iretd

; ---------------- Keyboard ----------------
keyboard_setup:
    ; IRQ1 = vector 0x21. Install handler manually.
    mov eax, keyboard_irq
    mov word [idt + 0x21*8], ax
    shr eax, 16
    mov word [idt + 0x21*8 + 6], ax
    ; IRQ0 = vector 0x20.
    mov eax, timer_irq
    mov word [idt + 0x20*8], ax
    shr eax, 16
    mov word [idt + 0x20*8 + 6], ax
    ret

keyboard_irq:
    pushad
    in al, 0x60
    test al, 0x80
    jnz .eoi

    movzx eax, al
    cmp eax, 0x0E
    je .backspace
    cmp eax, 0x1C
    je .enter

    mov esi, keymap
    mov al, [esi+eax]
    test al, al
    jz .eoi
    call putc
    call command_append
    jmp .eoi

.backspace:
    call command_backspace
    jmp .eoi

.enter:
    call command_enter

.eoi:
    mov al, 0x20
    out PIC1, al
    popad
    iretd

; ---------------- Tiny command service ----------------
; This is intentionally a kernel-resident shell, not userland yet.
cmd_buf times 64 db 0
cmd_len dd 0

command_append:
    push eax
    mov eax, [cmd_len]
    cmp eax, 63
    jae .done
    mov [cmd_buf+eax], al
    inc dword [cmd_len]
.done:
    pop eax
    ret

command_backspace:
    cmp dword [cmd_len], 0
    je .done
    dec dword [cmd_len]
    ; redraw last character as space
    mov eax, [cur_x]
    cmp eax, 0
    jne .same
    cmp dword [cur_y], 0
    je .done
    dec dword [cur_y]
    mov dword [cur_x], 79
    jmp .erase
.same:
    dec dword [cur_x]
.erase:
    mov eax, [cur_y]
    imul eax, 160
    mov edx, [cur_x]
    imul edx, 2
    add eax, edx
    add eax, VIDEO
    mov word [eax], 0x0720
.done:
    ret

command_enter:
    push esi
    call newline
    mov byte [cmd_buf+0], 0
    ; compare commands without libc
    mov esi, cmd_buf
    mov edi, cmd_help
    call strcmp
    jc .help
    mov esi, cmd_buf
    mov edi, cmd_clear
    call strcmp
    jc .clear
    mov esi, cmd_ticks
    mov edi, cmd_ticks_name
    call strcmp
    jc .ticks
    mov esi, cmd_about
    mov edi, cmd_about_name
    call strcmp
    jc .about
    cmp dword [cmd_len], 0
    je .prompt
    mov esi, unknown
    call puts
    jmp .prompt
.help:
    mov esi, help_text
    call puts
    jmp .prompt
.clear:
    call vga_clear
    jmp .prompt
.ticks:
    mov esi, ticks_text
    call puts
    mov eax, [ticks]
    call print_dec
    call newline
    jmp .prompt
.about:
    mov esi, about_text
    call puts
.prompt:
    mov dword [cmd_len], 0
    mov esi, prompt
    call puts
    pop esi
    ret

; strcmp: ESI and EDI zero-terminated. CF=1 if equal.
strcmp:
.loop:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .no
    test al, al
    jz .yes
    inc esi
    inc edi
    jmp .loop
.yes:
    stc
    ret
.no:
    clc
    ret

print_dec:
    push eax
    push ebx
    push ecx
    push edx
    cmp eax, 0
    jne .convert
    mov al, '0'
    call putc
    jmp .done
.convert:
    xor ecx, ecx
    mov ebx, 10
.loop:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .loop
.out:
    pop eax
    add al, '0'
    call putc
    loop .out
.done:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------- Keyboard map ----------------
keymap:
times 0x10 db 0
db '1','2','3','4','5','6','7','8','9','0','-','=',0,0
db 'q','w','e','r','t','y','u','i','o','p','[',']',0,0
db 'a','s','d','f','g','h','j','k','l',';',39,'`',0,92
db 'z','x','c','v','b','n','m',',','.','/'

banner db "MYOS microkernel 0.1",10
       db "ring0 console / PIC / PIT / PS2",10
       db "type 'help' and press Enter",10,10,0
prompt db "myos> ",0
help_text db "commands: help clear ticks about",10,0
about_text db "MYOS: tiny x86 assembly microkernel prototype",10,0
ticks_text db "ticks: ",0
unknown db "unknown command",10,0
cmd_help db "help",0
cmd_clear db "clear",0
cmd_ticks_name db "ticks",0
cmd_about_name db "about",0

cur_x dd 0
cur_y dd 0
ticks dd 0

align 16
stack_bottom:
times 8192 db 0
stack_top:
