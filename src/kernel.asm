BITS 32
org 0x100000

KERNEL_VMA      equ 0xFFFFFFFF80000000
KERNEL_PMA      equ 0x200000
DIRECT_MAP_BASE equ 0xFFFF800000000000

PTE_PRESENT     equ 1
PTE_WRITABLE    equ 2
PTE_USER        equ 4
PAGE_MASK       equ 0x000FFFFFFFFFF000
TEST_VADDR      equ 0x10000000
LAZY_BASE       equ 0x20000000
LAZY_SIZE       equ 0x3000
COW_BASE        equ 0x30000000
COW_SIZE        equ 0x1000
MMAP_BASE       equ 0x40000000

NULL_SEL        equ 0x00
KERNEL_CODE_SEL equ 0x08
KERNEL_DATA_SEL equ 0x10
USER_DATA_SEL   equ 0x18
USER_CODE_SEL   equ 0x20
TSS_SEL         equ 0x28
USER_ADDR       equ 0x50000000
USER_STACK      equ 0x50001000

VGA_ADDR        equ 0xB8000
VGA_COLS        equ 80
VGA_ROWS        equ 25
PIC1_CMD        equ 0x20
PIC1_DATA       equ 0x21
PIC2_CMD        equ 0xA0
PIC2_DATA       equ 0xA1
PIC_EOI         equ 0x20
PIT_CMD         equ 0x43
PIT_CH0         equ 0x40
KB_DATA         equ 0x60
SERIAL_PORT     equ 0x3F8
TOTAL_PAGES     equ 262144
PAGE_SIZE       equ 4096
MAX_TASKS       equ 64
STACK_SIZE      equ 4096
MSG_SIZE        equ 64
MSG_QUEUE_LEN   equ 8

TASK_FREE       equ 0
TASK_READY      equ 1
TASK_RUNNING    equ 2
TASK_RECV       equ 3
TASK_SLEEP      equ 4
TASK_DEAD       equ 5
TASK_WAIT       equ 6

TCB_STATE       equ 0
TCB_PID         equ 1
TCB_PARENT      equ 2
TCB_RSP         equ 8
TCB_ENTRY       equ 16
TCB_NAME        equ 24
TCB_MAILBOX     equ 40
TCB_MAIL_FROM   equ 552
TCB_MAIL_HEAD   equ 560
TCB_MAIL_TAIL   equ 561
TCB_MAIL_COUNT  equ 562
TCB_SLEEP       equ 568
TCB_EXIT_STATUS equ 576
TCB_CR3         equ 584
TCB_SIZE        equ 592

SYS_EXIT        equ 0
SYS_WRITE       equ 1
SYS_SEND        equ 2
SYS_RECV        equ 3
SYS_REPLY       equ 4
SYS_GETPID      equ 5
SYS_SLEEP       equ 6
SYS_YIELD       equ 7
SYS_FORK        equ 8
SYS_WAIT        equ 9
SYS_EXEC        equ 10
SYS_CLONE       equ 11

HEAP_START      equ 0x400000
HEAP_SIZE       equ 0x800000
BUDDY_BASE      equ 0x1000000
BUDDY_END       equ 0x4000000
BUDDY_MAX_ORDER equ 12

%macro TCB_BASE 2
    imul %1, %2, TCB_SIZE
    lea %1, [%1 + tcb_array]
%endmacro

section .boot start=0x100000

align 4
mb1_start:
    dd 0x1BADB002
    dd 0x00010003
    dd -(0x1BADB002 + 0x00010003)
    dd mb1_start
    dd mb1_start
    dd _end - KERNEL_VMA + KERNEL_PMA
    dd _end - KERNEL_VMA + KERNEL_PMA
    dd _start

_start:
    cli
    cld
    mov esp, boot_stack_top
    mov [mb_info], ebx
    mov [mb_magic], eax

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .no_long
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29
    jz .no_long

    mov edi, pml4 - KERNEL_VMA + KERNEL_PMA
    mov ecx, 7168
    xor eax, eax
    rep stosd

    mov eax, pml4 - KERNEL_VMA + KERNEL_PMA
    mov dword [eax], pdpt_low - KERNEL_VMA + KERNEL_PMA + 7
    mov dword [eax + 256 * 8], pdpt_direct - KERNEL_VMA + KERNEL_PMA + 3
    mov dword [eax + 511 * 8], pdpt_high - KERNEL_VMA + KERNEL_PMA + 3
    mov eax, pdpt_low - KERNEL_VMA + KERNEL_PMA
    mov dword [eax], pd_low - KERNEL_VMA + KERNEL_PMA + 3

    xor eax, eax
    mov edi, pd_low - KERNEL_VMA + KERNEL_PMA
    mov ecx, 8
.fill_low:
    mov edx, eax
    shl edx, 21
    or edx, 0x83
    mov [edi], edx
    mov dword [edi + 4], 0
    add edi, 8
    inc eax
    loop .fill_low

    mov eax, pdpt_high - KERNEL_VMA + KERNEL_PMA
    mov dword [eax + 510 * 8], pd_high - KERNEL_VMA + KERNEL_PMA + 3
    mov eax, pd_high - KERNEL_VMA + KERNEL_PMA
    mov dword [eax], KERNEL_PMA | 0x83
    mov dword [eax + 4], 0

    mov eax, pdpt_direct - KERNEL_VMA + KERNEL_PMA
    mov dword [eax], pd_direct - KERNEL_VMA + KERNEL_PMA + 3

    xor eax, eax
    mov edi, pd_direct - KERNEL_VMA + KERNEL_PMA
    mov ecx, 512
.fill_direct:
    mov edx, eax
    shl edx, 21
    or edx, 0x83
    mov [edi], edx
    mov dword [edi + 4], 0
    add edi, 8
    inc eax
    loop .fill_direct

    mov eax, pml4 - KERNEL_VMA + KERNEL_PMA
    mov cr3, eax

    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    mov eax, cr0
    or eax, 0x80010001
    mov cr0, eax

    lgdt [gdt64_desc]
    jmp 0x08:in_long_mode

.no_long:
    mov al, 'X'
    call out_serial32
    cli
    hlt
    jmp .no_long

out_serial32:
    push edx
    push ecx
    mov cl, al
    mov dx, 0x3FD
.wait:
    in al, dx
    test al, 0x20
    jz .wait
    mov al, cl
    mov dx, 0x3F8
    out dx, al
    pop ecx
    pop edx
    ret

BITS 64
in_long_mode:
    mov rax, strict qword long_mode_entry
    jmp rax

tss:
    resb 104

align 8
gdt64:
    dq 0
    dq 0x00AF9A000000FFFF
    dq 0x00AF92000000FFFF
    dq 0x00AFF2000000FFFF
    dq 0x00AFFA000000FFFF
tss_desc:
    dw 0x67
    dw 0
    db 0
    db 0x89
    db 0x00
    db 0
    dd 0
    dd 0
gdt64_end:
gdt64_desc:
    dw gdt64_end - gdt64 - 1
    dd gdt64

boot_stack: resb 1024
boot_stack_top:

mb_magic:   resd 1
mb_info:    resq 1

section .text start=KERNEL_PMA vstart=KERNEL_VMA

long_mode_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov rsp, stack_top
    cld
    call kernel_main
    cli
    hlt
    jmp $

tss_init:
    mov rax, stack_top
    mov [tss + 4], rax
    mov word [tss + 102], 104
    mov rax, tss
    mov [tss_desc + 2], ax
    mov r11, rax
    shr r11, 16
    mov [tss_desc + 4], r11b
    shr r11, 8
    mov [tss_desc + 7], r11b
    shr rax, 32
    mov [tss_desc + 8], eax
    mov ax, TSS_SEL
    ltr ax
    ret

kernel_main:
    call vga_init
    mov rsi, banner
    call kprint
    call idt_init
    call pic_init
    call pit_init
    call tss_init
    call pmm_init
    call buddy_init
    mov rax, cr3
    mov [current_pml4], rax
    mov [kernel_cr3], rax
    call buddy_test
    call slab_test
    call vmm_test
    call demand_test
    call cow_test
    call mmap_test
    mov rsi, str_selftest_ok
    call kprint
    call sched_init
    mov rsi, str_sched_ok
    call kprint
    call sched_start
    cli
    hlt
    jmp $

serial_write_al:
    push rdx
    push rcx
    mov cl, al
    mov dx, 0xE9
    out dx, al
    mov dx, SERIAL_PORT + 5
.wait:
    in al, dx
    test al, 0x20
    jz .wait
    mov al, cl
    mov dx, SERIAL_PORT
    out dx, al
    pop rcx
    pop rdx
    ret

vga_init:
    mov byte [vga_color], 0x0F
    mov rdi, VGA_ADDR
    mov rcx, VGA_ROWS * VGA_COLS
    mov ax, 0x0F20
    rep stosw
    mov byte [vga_row], 0
    mov byte [vga_col], 0
    ret

vga_scroll:
    push rsi
    push rdi
    mov rsi, VGA_ADDR + VGA_COLS * 2
    mov rdi, VGA_ADDR
    mov rcx, VGA_COLS * (VGA_ROWS - 1)
    rep movsw
    mov rdi, VGA_ADDR + VGA_COLS * (VGA_ROWS - 1) * 2
    mov rcx, VGA_COLS
    mov ax, 0x0F20
    rep stosw
    mov byte [vga_row], VGA_ROWS - 1
    pop rdi
    pop rsi
    ret

vga_set_cursor:
    push rax
    push rbx
    push rdx
    movzx ebx, byte [vga_row]
    imul ebx, VGA_COLS
    movzx ecx, byte [vga_col]
    add ebx, ecx
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov dx, 0x3D5
    mov al, bl
    out dx, al
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov dx, 0x3D5
    mov al, bh
    out dx, al
    pop rdx
    pop rbx
    pop rax
    ret

kputc:
    push rax
    call serial_write_al
    pop rax
    cmp al, 10
    je .newline
    cmp al, 13
    je .cr
    cmp al, 8
    je .backspace
    movzx rcx, byte [vga_row]
    movzx rdx, byte [vga_col]
    imul rcx, VGA_COLS
    add rcx, rdx
    shl rcx, 1
    mov ah, byte [vga_color]
    mov [VGA_ADDR + rcx], ax
    inc byte [vga_col]
    cmp byte [vga_col], VGA_COLS
    jne .done
    mov byte [vga_col], 0
    jmp .advance_row
.newline:
    mov byte [vga_col], 0
.advance_row:
    inc byte [vga_row]
    cmp byte [vga_row], VGA_ROWS
    jl .done
    call vga_scroll
.done:
    call vga_set_cursor
    ret
.cr:
    mov byte [vga_col], 0
    jmp .done
.backspace:
    cmp byte [vga_col], 0
    jne .back_col
    cmp byte [vga_row], 0
    je .done
    dec byte [vga_row]
    mov byte [vga_col], VGA_COLS - 1
    jmp .erase
.back_col:
    dec byte [vga_col]
.erase:
    movzx rcx, byte [vga_row]
    movzx rdx, byte [vga_col]
    imul rcx, VGA_COLS
    add rcx, rdx
    shl rcx, 1
    mov ax, 0x0F20
    mov [VGA_ADDR + rcx], ax
    jmp .done

kclear:
    mov rdi, VGA_ADDR
    mov rcx, VGA_ROWS * VGA_COLS
    mov ax, 0x0F20
    rep stosw
    mov byte [vga_row], 0
    mov byte [vga_col], 0
    ret

kprint:
.loop:
    lodsb
    test al, al
    jz .done
    call kputc
    jmp .loop
.done:
    ret

kprint_len:
    push rdi
    push rsi
.loop:
    test rsi, rsi
    jz .done
    mov al, [rdi]
    call kputc
    inc rdi
    dec rsi
    jmp .loop
.done:
    pop rsi
    pop rdi
    ret

knewline:
    mov al, 10
    call kputc
    ret

kprint_hex:
    push rbx
    push r12
    mov rbx, rax
    mov al, '0'
    call kputc
    mov al, 'x'
    call kputc
    mov r12, 16
.loop:
    rol rbx, 4
    mov rax, rbx
    and rax, 0xF
    cmp rax, 10
    jl .digit
    add al, 'A' - 10
    jmp .print
.digit:
    add al, '0'
.print:
    call kputc
    dec r12
    jnz .loop
    pop r12
    pop rbx
    ret

kprint_dec:
    push rbx
    push r12
    mov rbx, 10
    xor r12, r12
    test rax, rax
    jnz .loop
    mov al, '0'
    call kputc
    jmp .done
.loop:
    xor rdx, rdx
    div rbx
    push rdx
    inc r12
    test rax, rax
    jnz .loop
.print:
    pop rax
    add al, '0'
    call kputc
    dec r12
    jnz .print
.done:
    pop r12
    pop rbx
    ret

idt_init:
    xor rcx, rcx
.fill:
    mov rax, [isr_stub_table + rcx * 8]
    mov rdx, rcx
    shl rdx, 4
    add rdx, idt
    mov [rdx], ax
    shr rax, 16
    mov [rdx + 6], ax
    shr rax, 16
    mov [rdx + 8], eax
    mov word [rdx + 2], 0x08
    mov byte [rdx + 4], 0
    mov byte [rdx + 5], 0x8E
    inc rcx
    cmp rcx, 256
    jl .fill
    mov byte [idt + 128 * 16 + 5], 0xEE
    lidt [idtr]
    ret

%assign i 0
%rep 256
isr_stub_%+i:
%if (i == 8) || ((i >= 10) && (i <= 14)) || (i == 17) || (i == 21) || (i == 29) || (i == 30)
    push i
%else
    push 0
    push i
%endif
    jmp isr_common
%assign i i + 1
%endrep

isr_stub_table:
%assign i 0
%rep 256
    dq isr_stub_%+i
%assign i i + 1
%endrep

isr_common:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    mov rdi, rsp
    call isr_dispatcher
isr_return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    add rsp, 16
    iretq

isr_dispatcher:
    mov rax, [rdi + 120]
    cmp rax, 32
    jb .exception
    cmp rax, 48
    jb .irq
    cmp rax, 128
    je .syscall
    ret
.exception:
    cmp rax, 14
    je .page_fault
    mov rbx, rax
    mov rsi, str_exception
    call kprint
    mov rax, rbx
    call kprint_dec
    call knewline
    mov rsi, str_rip
    call kprint
    mov rax, [rdi + 136]
    call kprint_hex
    call knewline
    cli
    hlt
    jmp $
.page_fault:
    call page_fault_handler
    ret
.irq:
    cmp rax, 32
    je .timer
    cmp rax, 33
    je .keyboard
    cmp rax, 40
    jge .slave_eoi
    call pic_eoi_master
    ret
.slave_eoi:
    call pic_eoi_slave
    call pic_eoi_master
    ret
.timer:
    call pic_eoi_master
    call timer_tick
    ret
.keyboard:
    call pic_eoi_master
    call keyboard_handler
    ret
.syscall:
    call syscall_handler
    ret

page_fault_handler:
    push rbx
    push r12
    push r13
    mov r12, [rdi + 128]
    mov r13, cr2
    test r12, 1
    jnz .cow
    mov rax, r13
    cmp rax, LAZY_BASE
    jb .general
    cmp rax, LAZY_BASE + LAZY_SIZE
    jae .general
    shr rax, 12
    shl rax, 12
    mov rdi, rax
    push rdi
    call pmm_alloc
    pop rdi
    test rax, rax
    jz .general
    mov rdx, rax
    mov rsi, rdi
    mov rdi, [current_pml4]
    mov rcx, PTE_WRITABLE
    call vmm_map
    jmp .done
.cow:
    test r12, 2
    jz .general
    mov rax, r13
    cmp rax, COW_BASE
    jb .general
    cmp rax, COW_BASE + COW_SIZE
    jae .general
    shr rax, 12
    shl rax, 12
    mov rbx, rax
    mov rdi, [current_pml4]
    mov rsi, rbx
    call vmm_get_pte
    test rax, rax
    jz .general
    mov r10, PAGE_MASK
    and rax, r10
    mov r12, rax
    call pmm_alloc
    test rax, rax
    jz .general
    mov r13, rax
    mov rdi, r12
    call vmm_p2v
    mov rsi, rax
    mov rdi, r13
    call vmm_p2v
    mov rdi, rax
    mov rcx, 512
    rep movsq
    mov rdi, [current_pml4]
    mov rsi, rbx
    mov rdx, r13
    mov rcx, PTE_WRITABLE
    call vmm_map
    jmp .done
.general:
    mov rsi, str_pf
    call kprint
    mov rax, r13
    call kprint_hex
    mov rsi, str_rip
    call kprint
    mov rax, [rdi + 136]
    call kprint_hex
    call knewline
    cli
    hlt
    jmp $
.done:
    pop r13
    pop r12
    pop rbx
    ret

pic_init:
    mov al, 0x11
    out PIC1_CMD, al
    out PIC2_CMD, al
    mov al, 0x20
    out PIC1_DATA, al
    mov al, 0x28
    out PIC2_DATA, al
    mov al, 0x04
    out PIC1_DATA, al
    mov al, 0x02
    out PIC2_DATA, al
    mov al, 0x01
    out PIC1_DATA, al
    out PIC2_DATA, al
    mov al, 0xFC
    out PIC1_DATA, al
    mov al, 0xFF
    out PIC2_DATA, al
    ret

pic_eoi_master:
    mov al, PIC_EOI
    out PIC1_CMD, al
    ret

pic_eoi_slave:
    mov al, PIC_EOI
    out PIC2_CMD, al
    ret

pit_init:
    mov al, 0x36
    out PIT_CMD, al
    mov ax, 11932
    out PIT_CH0, al
    mov al, ah
    out PIT_CH0, al
    ret

timer_tick:
    inc qword [tick_count]
    call wake_sleepers
    call schedule
    ret

wake_sleepers:
    xor rcx, rcx
.loop:
    TCB_BASE rax, rcx
    cmp byte [rax + TCB_STATE], TASK_SLEEP
    jne .next
    dec qword [rax + TCB_SLEEP]
    jg .next
    mov byte [rax + TCB_STATE], TASK_READY
.next:
    inc rcx
    cmp rcx, MAX_TASKS
    jl .loop
    ret

kb_map:
    db 0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0, 0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0, 0, 'a', 's'
    db 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', 0, 0, 0, 0, 'z', 'x', 'c', 'v'
    db 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' ', 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

keyboard_handler:
    in al, KB_DATA
    test al, 0x80
    jnz .done
    cmp al, 0x0E
    je .backspace
    cmp al, 0x1C
    je .enter
    cmp al, 128
    jae .done
    movzx rbx, al
    mov al, [kb_map + rbx]
    test al, al
    jz .done
    call kputc
    mov rcx, [kbd_len]
    cmp rcx, 63
    jge .done
    mov [kbd_buf + rcx], al
    inc rcx
    mov [kbd_len], rcx
    mov byte [kbd_buf + rcx], 0
.done:
    ret
.backspace:
    mov rcx, [kbd_len]
    test rcx, rcx
    jz .done
    dec rcx
    mov [kbd_len], rcx
    mov byte [kbd_buf + rcx], 0
    mov al, 8
    call kputc
    ret
.enter:
    call knewline
    mov rdi, [shell_pid]
    mov rsi, kbd_buf
    call ipc_send
    mov qword [kbd_len], 0
    mov byte [kbd_buf], 0
    ret

pmm_init:
    mov rax, [mb_info]
    mov [mb_info_ptr], rax
    mov rdi, pmm_bitmap
    mov rcx, TOTAL_PAGES / 8
    mov al, 0xFF
    rep stosb
    xor rcx, rcx
.mmap_loop:
    mov rax, [mb_info_ptr]
    mov ebx, [rax + 48]
    test ebx, ebx
    jz .protect
    mov r8d, [rax + 44]
    add r8, rbx
.mmap_next:
    cmp rbx, r8
    jge .protect
    mov eax, [rbx + 20]
    cmp eax, 1
    jne .mmap_advance
    mov esi, [rbx + 4]
    mov edx, [rbx + 12]
    push rbx
    push r8
    mov rdi, rsi
    lea rsi, [rsi + rdx]
    call pmm_mark_free_range
    pop r8
    pop rbx
.mmap_advance:
    mov eax, [rbx]
    add eax, 3
    and eax, ~3
    add rbx, rax
    jmp .mmap_next
.protect:
    mov rdi, 0
    mov rsi, HEAP_START + HEAP_SIZE
    call pmm_mark_used_range
    mov qword [heap_cur], HEAP_START
    ret

pmm_mark_free_range:
    cmp rdi, TOTAL_PAGES * PAGE_SIZE
    jae .done
    cmp rsi, TOTAL_PAGES * PAGE_SIZE
    jbe .clamp_done
    mov rsi, TOTAL_PAGES * PAGE_SIZE
.clamp_done:
    shr rdi, 12
    add rsi, 4095
    shr rsi, 12
.loop:
    cmp rdi, rsi
    jge .done
    push rsi
    push rdi
    call pmm_clear_bit
    pop rdi
    pop rsi
    inc rdi
    jmp .loop
.done:
    ret

pmm_mark_used_range:
    shr rdi, 12
    add rsi, 4095
    shr rsi, 12
.loop:
    cmp rdi, rsi
    jge .done
    cmp rdi, TOTAL_PAGES
    jge .done
    push rsi
    push rdi
    call pmm_set_bit
    pop rdi
    pop rsi
    inc rdi
    jmp .loop
.done:
    ret

pmm_set_bit:
    push rcx
    push rdx
    mov rax, rdi
    shr rax, 3
    mov rcx, rdi
    and rcx, 7
    mov rdx, 1
    shl rdx, cl
    or byte [pmm_bitmap + rax], dl
    pop rdx
    pop rcx
    ret

pmm_clear_bit:
    push rcx
    push rdx
    mov rax, rdi
    shr rax, 3
    mov rcx, rdi
    and rcx, 7
    mov rdx, 1
    shl rdx, cl
    not rdx
    and byte [pmm_bitmap + rax], dl
    pop rdx
    pop rcx
    ret

pmm_test_bit:
    push rcx
    push rdx
    mov rax, rdi
    shr rax, 3
    mov rcx, rdi
    and rcx, 7
    mov dl, [pmm_bitmap + rax]
    shr dl, cl
    and dl, 1
    mov al, dl
    pop rdx
    pop rcx
    ret

buddy_push:
    push rbx
    mov rbx, rdi
    mov rax, rsi
    shl rax, 12
    mov r11, DIRECT_MAP_BASE
    add rax, r11
    mov rdx, [buddy_lists + rbx * 8]
    mov [rax], rdx
    mov [buddy_lists + rbx * 8], rsi
    pop rbx
    ret

buddy_pop:
    push rbx
    mov rbx, rdi
    mov rax, [buddy_lists + rbx * 8]
    cmp rax, -1
    je .empty
    mov rdx, rax
    shl rdx, 12
    mov r11, DIRECT_MAP_BASE
    add rdx, r11
    mov rcx, [rdx]
    mov [buddy_lists + rbx * 8], rcx
    pop rbx
    ret
.empty:
    mov rax, -1
    pop rbx
    ret

buddy_is_free:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    mov rax, [buddy_lists + rbx * 8]
.loop:
    cmp rax, -1
    je .no
    cmp rax, r12
    je .yes
    mov rdx, rax
    shl rdx, 12
    mov r11, DIRECT_MAP_BASE
    add rdx, r11
    mov rax, [rdx]
    jmp .loop
.yes:
    mov rax, 1
    pop r12
    pop rbx
    ret
.no:
    xor rax, rax
    pop r12
    pop rbx
    ret

buddy_remove:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    mov rax, [buddy_lists + rbx * 8]
    cmp rax, r12
    je .head
    mov rcx, rax
.walk:
    cmp rcx, -1
    je .done
    mov rax, rcx
    shl rax, 12
    mov r11, DIRECT_MAP_BASE
    add rax, r11
    mov rdx, [rax]
    cmp rdx, r12
    je .unlink
    mov rcx, rdx
    jmp .walk
.unlink:
    mov rax, rcx
    shl rax, 12
    mov r11, DIRECT_MAP_BASE
    add rax, r11
    mov rdx, r12
    shl rdx, 12
    mov r11, DIRECT_MAP_BASE
    add rdx, r11
    mov rdx, [rdx]
    mov [rax], rdx
    jmp .done
.head:
    mov rax, r12
    shl rax, 12
    mov r11, DIRECT_MAP_BASE
    add rax, r11
    mov rax, [rax]
    mov [buddy_lists + rbx * 8], rax
.done:
    pop r12
    pop rbx
    ret

buddy_alloc:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov rcx, rbx
.find:
    cmp rcx, BUDDY_MAX_ORDER
    jg .fail
    cmp qword [buddy_lists + rcx * 8], -1
    jne .found
    inc rcx
    jmp .find
.found:
    mov r13, rcx
    mov rdi, rcx
    call buddy_pop
    mov r12, rax
.split:
    cmp r13, rbx
    je .done
    dec r13
    mov rax, 1
    mov rcx, r13
    shl rax, cl
    add rax, r12
    mov rdi, r13
    mov rsi, rax
    call buddy_push
    jmp .split
.done:
    mov rax, r12
    shl rax, 12
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    xor rax, rax
    pop r13
    pop r12
    pop rbx
    ret

buddy_free:
    push rbx
    push r12
    push r13
    mov rax, rdi
    shr rax, 12
    mov r12, rax
    mov r13, rsi
.coalesce:
    cmp r13, BUDDY_MAX_ORDER
    jge .push
    mov rax, 1
    mov rcx, r13
    shl rax, cl
    xor rax, r12
    mov rbx, rax
    mov rdi, r13
    mov rsi, rbx
    call buddy_is_free
    test rax, rax
    jz .push
    mov rdi, r13
    mov rsi, rbx
    call buddy_remove
    cmp r12, rbx
    jbe .keep
    mov r12, rbx
.keep:
    inc r13
    jmp .coalesce
.push:
    mov rdi, r13
    mov rsi, r12
    call buddy_push
    pop r13
    pop r12
    pop rbx
    ret

buddy_init:
    push rbx
    xor rcx, rcx
.init_lists:
    mov qword [buddy_lists + rcx * 8], -1
    inc rcx
    cmp rcx, BUDDY_MAX_ORDER + 1
    jl .init_lists
    mov rdi, BUDDY_MAX_ORDER
    mov rsi, 0x1000000 >> 12
    call buddy_push
    mov rdi, BUDDY_MAX_ORDER
    mov rsi, 0x2000000 >> 12
    call buddy_push
    mov rdi, BUDDY_MAX_ORDER
    mov rsi, 0x3000000 >> 12
    call buddy_push
    pop rbx
    ret

pmm_alloc:
    xor edi, edi
    call buddy_alloc
    ret

pmm_free:
    xor esi, esi
    call buddy_free
    ret

pmm_free_pages:
    push rbx
    push r12
    push r13
    xor rbx, rbx
    xor r12, r12
.order_loop:
    cmp r12, BUDDY_MAX_ORDER + 1
    jge .done
    xor r13, r13
    mov rax, [buddy_lists + r12 * 8]
.count:
    cmp rax, -1
    je .add
    inc r13
    mov rdx, rax
    shl rdx, 12
    mov r11, DIRECT_MAP_BASE
    add rdx, r11
    mov rax, [rdx]
    jmp .count
.add:
    mov rax, 1
    mov rcx, r12
    shl rax, cl
    imul rax, r13
    add rbx, rax
    inc r12
    jmp .order_loop
.done:
    mov rax, rbx
    pop r13
    pop r12
    pop rbx
    ret

vmm_p2v:
    mov rax, rdi
    mov r11, DIRECT_MAP_BASE
    add rax, r11
    ret

vmm_next_table:
    mov rax, [rdi]
    test rax, PTE_PRESENT
    jnz .present
    push rdi
    call pmm_alloc
    pop rdi
    test rax, rax
    jz .fail
    push rdi
    push rax
    mov rdi, rax
    call vmm_p2v
    mov rdi, rax
    mov rcx, 512
    xor rax, rax
    rep stosq
    pop rax
    pop rdi
    or rax, PTE_PRESENT | PTE_WRITABLE | PTE_USER
    mov [rdi], rax
.present:
    mov rax, [rdi]
    mov r10, PAGE_MASK
    and rax, r10
    mov rdi, rax
    call vmm_p2v
    ret
.fail:
    xor rax, rax
    ret

vmm_walk_next:
    mov rax, [rdi]
    test rax, PTE_PRESENT
    jz .none
    mov r10, PAGE_MASK
    and rax, r10
    mov rdi, rax
    call vmm_p2v
    ret
.none:
    xor rax, rax
    ret

vmm_map:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov rdi, rbx
    call vmm_p2v
    mov rdi, r12
    shr rdi, 39
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    call vmm_next_table
    test rax, rax
    jz .fail
    mov rdi, r12
    shr rdi, 30
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    call vmm_next_table
    test rax, rax
    jz .fail
    mov rdi, r12
    shr rdi, 21
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    call vmm_next_table
    test rax, rax
    jz .fail
    mov rdi, r12
    shr rdi, 12
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    mov rax, r13
    mov r10, PAGE_MASK
    and rax, r10
    or rax, r14
    or rax, PTE_PRESENT
    mov [rdi], rax
    invlpg [r12]
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

vmm_unmap:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rbx
    call vmm_p2v
    mov rdi, r12
    shr rdi, 39
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    call vmm_walk_next
    test rax, rax
    jz .done
    mov rdi, r12
    shr rdi, 30
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    call vmm_walk_next
    test rax, rax
    jz .done
    mov rdi, r12
    shr rdi, 21
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    call vmm_walk_next
    test rax, rax
    jz .done
    mov rdi, r12
    shr rdi, 12
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    mov qword [rdi], 0
    invlpg [r12]
.done:
    pop r12
    pop rbx
    ret

vmm_get_pte:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rbx
    call vmm_p2v
    mov rdi, r12
    shr rdi, 39
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    call vmm_walk_next
    test rax, rax
    jz .none
    mov rdi, r12
    shr rdi, 30
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    call vmm_walk_next
    test rax, rax
    jz .none
    mov rdi, r12
    shr rdi, 21
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    call vmm_walk_next
    test rax, rax
    jz .none
    mov rdi, r12
    shr rdi, 12
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    mov rax, [rdi]
    pop r12
    pop rbx
    ret
.none:
    xor rax, rax
    pop r12
    pop rbx
    ret

vmm_get_pte_addr:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rbx
    call vmm_p2v
    mov rdi, r12
    shr rdi, 39
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    call vmm_walk_next
    test rax, rax
    jz .none
    mov rdi, r12
    shr rdi, 30
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    call vmm_walk_next
    test rax, rax
    jz .none
    mov rdi, r12
    shr rdi, 21
    and rdi, 0x1FF
    lea rdi, [rax + rdi * 8]
    call vmm_walk_next
    test rax, rax
    jz .none
    mov rdi, r12
    shr rdi, 12
    and rdi, 0x1FF
    lea rax, [rax + rdi * 8]
    pop r12
    pop rbx
    ret
.none:
    xor rax, rax
    pop r12
    pop rbx
    ret

vmm_mmap:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    shr rbx, 12
    shl rbx, 12
    add r12, 4095
    shr r12, 12
.loop:
    test r12, r12
    jz .done
    push rbx
    push r12
    call pmm_alloc
    pop r12
    pop rbx
    test rax, rax
    jz .fail
    mov rdx, rax
    mov rsi, rbx
    mov rdi, [current_pml4]
    mov rcx, r13
    push rbx
    push r12
    call vmm_map
    pop r12
    pop rbx
    add rbx, 4096
    dec r12
    jmp .loop
.done:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r13
    pop r12
    pop rbx
    ret

vmm_munmap:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    shr rbx, 12
    shl rbx, 12
    add r12, 4095
    shr r12, 12
.loop:
    test r12, r12
    jz .done
    mov rdi, [current_pml4]
    mov rsi, rbx
    push rbx
    push r12
    call vmm_unmap
    pop r12
    pop rbx
    add rbx, 4096
    dec r12
    jmp .loop
.done:
    pop r12
    pop rbx
    ret

vmm_mprotect:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    shr rbx, 12
    shl rbx, 12
    add r12, 4095
    shr r12, 12
.loop:
    test r12, r12
    jz .done
    mov rdi, [current_pml4]
    mov rsi, rbx
    push rbx
    push r12
    call vmm_get_pte_addr
    pop r12
    pop rbx
    test rax, rax
    jz .fail
    mov rdi, rax
    mov rax, [rdi]
    mov r10, PAGE_MASK
    and rax, r10
    or rax, r13
    or rax, PTE_PRESENT
    mov [rdi], rax
    invlpg [rbx]
    add rbx, 4096
    dec r12
    jmp .loop
.done:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r13
    pop r12
    pop rbx
    ret

vmm_new_space:
    push rbx
    push r12
    call pmm_alloc
    test rax, rax
    jz .fail
    mov rbx, rax
    mov rdi, rax
    call vmm_p2v
    mov rdi, rax
    mov rcx, 512
    xor rax, rax
    rep stosq
    call pmm_alloc
    test rax, rax
    jz .fail
    mov r12, rax
    mov rdi, rax
    call vmm_p2v
    mov rdi, rax
    mov rcx, 512
    xor rax, rax
    rep stosq
    mov rdi, cr3
    call vmm_p2v
    mov rsi, rax
    mov rdi, rbx
    call vmm_p2v
    mov rdi, rax
    mov rax, r12
    or rax, PTE_PRESENT | PTE_WRITABLE | PTE_USER
    mov [rdi + 0 * 8], rax
    mov rax, [rsi + 256 * 8]
    mov [rdi + 256 * 8], rax
    mov rax, [rsi + 511 * 8]
    mov [rdi + 511 * 8], rax
    mov rax, rbx
    pop r12
    pop rbx
    ret
.fail:
    xor rax, rax
    pop r12
    pop rbx
    ret

vmm_switch:
    mov cr3, rdi
    ret

vmm_test:
    push rbx
    push r12
    push r13
    call pmm_alloc
    test rax, rax
    jz .fail
    mov r12, rax
    call vmm_new_space
    test rax, rax
    jz .fail
    mov r13, rax
    mov rdi, r13
    mov rsi, TEST_VADDR
    mov rdx, r12
    mov rcx, PTE_WRITABLE
    call vmm_map
    mov rbx, cr3
    pushfq
    cli
    mov rdi, r13
    call vmm_switch
    mov rax, 0x123456789ABCDEF0
    mov [TEST_VADDR], rax
    mov rax, [TEST_VADDR]
    mov rdi, rbx
    call vmm_switch
    popfq
    mov r11, 0x123456789ABCDEF0
    cmp rax, r11
    jne .fail
    mov rsi, str_vmm_ok
    call kprint
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov rsi, str_vmm_fail
    call kprint
    pop r13
    pop r12
    pop rbx
    ret

demand_test:
    push rbx
    mov qword [LAZY_BASE], 0x1111
    mov qword [LAZY_BASE + 0x1000], 0x2222
    mov qword [LAZY_BASE + 0x2000], 0x3333
    mov rax, [LAZY_BASE]
    cmp rax, 0x1111
    jne .fail
    mov rax, [LAZY_BASE + 0x1000]
    cmp rax, 0x2222
    jne .fail
    mov rax, [LAZY_BASE + 0x2000]
    cmp rax, 0x3333
    jne .fail
    mov rsi, str_demand_ok
    call kprint
    pop rbx
    ret
.fail:
    mov rsi, str_demand_fail
    call kprint
    pop rbx
    ret

cow_test:
    push rbx
    push r12
    push r13
    call pmm_alloc
    test rax, rax
    jz .fail
    mov r12, rax
    mov rdi, r12
    call vmm_p2v
    mov rdi, rax
    mov qword [rdi], 0xAAAA
    mov rdi, [current_pml4]
    mov rsi, COW_BASE
    mov rdx, r12
    mov rcx, PTE_PRESENT
    call vmm_map
    mov qword [COW_BASE], 0xBBBB
    mov rax, [COW_BASE]
    cmp rax, 0xBBBB
    jne .fail
    mov rdi, r12
    call vmm_p2v
    mov rdi, rax
    mov rax, [rdi]
    cmp rax, 0xAAAA
    jne .fail
    mov rsi, str_cow_ok
    call kprint
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov rsi, str_cow_fail
    call kprint
    pop r13
    pop r12
    pop rbx
    ret

buddy_test:
    push rbx
    push r12
    push r13
    call pmm_free_pages
    mov r13, rax
    call pmm_alloc
    mov rbx, rax
    call pmm_alloc
    mov r12, rax
    cmp rbx, BUDDY_BASE
    jb .fail
    cmp rbx, BUDDY_END
    jae .fail
    cmp r12, BUDDY_BASE
    jb .fail
    cmp r12, BUDDY_END
    jae .fail
    mov rdi, rbx
    call pmm_free
    mov rdi, r12
    call pmm_free
    call pmm_free_pages
    cmp rax, r13
    jne .fail
    mov rsi, str_buddy_ok
    call kprint
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov rsi, str_buddy_fail
    call kprint
    pop r13
    pop r12
    pop rbx
    ret

slab_sizes: dq 16, 32, 64, 128, 256, 512, 1024, 2048

slab_refill:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    call pmm_alloc
    test rax, rax
    jz .fail
    mov rdi, rax
    call vmm_p2v
    mov r12, rax
    mov rax, [slab_sizes + rbx * 8]
    add rax, 8
    mov r13, rax
    mov rax, 4096
    xor rdx, rdx
    div r13
    mov r14, rax
    mov rdx, r12
.carve:
    test r14, r14
    jz .done
    mov [rdx], rbx
    mov rax, [slab_free + rbx * 8]
    mov [rdx + 8], rax
    lea rax, [rdx + 8]
    mov [slab_free + rbx * 8], rax
    add rdx, r13
    dec r14
    jmp .carve
.done:
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

kmalloc:
    push rbx
    add rdi, 15
    and rdi, ~15
    xor rbx, rbx
.find:
    cmp rbx, 8
    jge .fail
    cmp rdi, [slab_sizes + rbx * 8]
    jbe .found
    inc rbx
    jmp .find
.found:
    cmp qword [slab_free + rbx * 8], 0
    jne .have
    push rbx
    mov rdi, rbx
    call slab_refill
    pop rbx
    test rax, rax
    jnz .fail
.have:
    mov rax, [slab_free + rbx * 8]
    mov rcx, [rax]
    mov [slab_free + rbx * 8], rcx
    pop rbx
    ret
.fail:
    xor rax, rax
    pop rbx
    ret

kfree:
    push rbx
    mov rbx, rdi
    sub rbx, 8
    mov rcx, [rbx]
    mov rax, [slab_free + rcx * 8]
    mov [rdi], rax
    mov [slab_free + rcx * 8], rdi
    pop rbx
    ret

slab_test:
    push rbx
    push r12
    mov rdi, 100
    call kmalloc
    mov rbx, rax
    mov rdi, 100
    call kmalloc
    mov r12, rax
    cmp rbx, r12
    je .fail
    mov qword [rbx], 0xDEAD
    mov rdi, rbx
    call kfree
    mov rdi, 100
    call kmalloc
    cmp rax, rbx
    jne .fail
    mov rsi, str_slab_ok
    call kprint
    pop r12
    pop rbx
    ret
.fail:
    mov rsi, str_slab_fail
    call kprint
    pop r12
    pop rbx
    ret

mmap_test:
    push rbx
    mov rdi, MMAP_BASE
    mov rsi, 8192
    mov rdx, PTE_WRITABLE
    call vmm_mmap
    test rax, rax
    jnz .fail
    mov qword [MMAP_BASE], 0x7777
    mov rax, [MMAP_BASE]
    cmp rax, 0x7777
    jne .fail
    mov rdi, MMAP_BASE
    mov rsi, 8192
    mov rdx, PTE_WRITABLE
    call vmm_mprotect
    test rax, rax
    jnz .fail
    mov qword [MMAP_BASE + 4096], 0x8888
    mov rax, [MMAP_BASE + 4096]
    cmp rax, 0x8888
    jne .fail
    mov rdi, MMAP_BASE
    mov rsi, 8192
    call vmm_munmap
    mov rsi, str_mmap_ok
    call kprint
    pop rbx
    ret
.fail:
    mov rsi, str_mmap_fail
    call kprint
    pop rbx
    ret

sched_init:
    mov qword [current_task], 0
    mov qword [shell_pid], -1
    mov qword [echo_pid], -1
    mov rdi, init_task
    mov rsi, name_init
    call task_create
    ret

task_create:
    cli
    push rbx
    push r12
    xor rcx, rcx
.find:
    TCB_BASE rax, rcx
    cmp byte [rax + TCB_STATE], TASK_FREE
    je .found
    inc rcx
    cmp rcx, MAX_TASKS
    jl .find
    pop r12
    pop rbx
    sti
    mov rax, -1
    ret
.found:
    TCB_BASE rax, rcx
    mov [rax + TCB_ENTRY], rdi
    push rcx
    lea rdi, [rax + TCB_NAME]
    mov rcx, 15
.copy_name:
    lodsb
    stosb
    test al, al
    jz .name_done
    loop .copy_name
.name_done:
    mov byte [rdi], 0
    pop rcx
    TCB_BASE rax, rcx
    mov byte [rax + TCB_STATE], TASK_READY
    mov byte [rax + TCB_PID], cl
    mov byte [rax + TCB_PARENT], 0
    mov byte [rax + TCB_MAIL_HEAD], 0
    mov byte [rax + TCB_MAIL_TAIL], 0
    mov byte [rax + TCB_MAIL_COUNT], 0
    mov qword [rax + TCB_SLEEP], 0
    mov qword [rax + TCB_EXIT_STATUS], 0
    mov rdx, [current_pml4]
    mov [rax + TCB_CR3], rdx
    mov r12, rcx
    mov rax, rcx
    inc rax
    imul rax, STACK_SIZE
    add rax, task_stacks
    mov rbx, rsp
    mov rsp, rax
    TCB_BASE rax, r12
    mov rax, [rax + TCB_ENTRY]
    push rax
    xor rax, rax
    push rax
    push rax
    push rax
    push rax
    push rax
    push rax
    TCB_BASE rax, r12
    mov [rax + TCB_RSP], rsp
    mov rsp, rbx
    mov rax, r12
    pop r12
    pop rbx
    sti
    ret

sched_start:
    mov qword [current_task], 0
    mov byte [tcb_array + TCB_STATE], TASK_RUNNING
    mov rsp, [tcb_array + TCB_RSP]
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    sti
    ret

schedule:
    mov rax, [current_task]
    TCB_BASE rdx, rax
    cmp byte [rdx + TCB_STATE], TASK_RUNNING
    jne .keep
    mov byte [rdx + TCB_STATE], TASK_READY
.keep:
    call find_next
    cmp rax, -1
    jne .have_next
    xor rax, rax
.have_next:
    cmp rax, [current_task]
    je .same
    mov rcx, rax
    mov rdx, [current_task]
    TCB_BASE rax, rcx
    mov byte [rax + TCB_STATE], TASK_RUNNING
    mov [current_task], rcx
    mov rax, rcx
    inc rax
    imul rax, STACK_SIZE
    add rax, task_stacks
    mov [tss + 4], rax
    TCB_BASE rax, rcx
    mov rax, [rax + TCB_CR3]
    mov [current_pml4], rax
    mov r8, cr3
    cmp rax, r8
    je .no_cr3
    mov cr3, rax
.no_cr3:
    TCB_BASE rdi, rdx
    lea rdi, [rdi + TCB_RSP]
    TCB_BASE rsi, rcx
    mov rsi, [rsi + TCB_RSP]
    call switch_to
    ret
.same:
    TCB_BASE rax, rax
    mov byte [rax + TCB_STATE], TASK_RUNNING
    ret

find_next:
    mov rcx, [current_task]
    mov rdx, rcx
    inc rdx
.search1:
    cmp rdx, MAX_TASKS
    jge .search2
    TCB_BASE rax, rdx
    cmp byte [rax + TCB_STATE], TASK_READY
    je .found
    inc rdx
    jmp .search1
.search2:
    xor rdx, rdx
.search2loop:
    cmp rdx, rcx
    jg .none
    TCB_BASE rax, rdx
    cmp byte [rax + TCB_STATE], TASK_READY
    je .found
    inc rdx
    jmp .search2loop
.found:
    mov rax, rdx
    ret
.none:
    mov rax, -1
    ret

switch_to:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    mov [rdi], rsp
    mov rsp, rsi
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

ipc_send:
    cmp rdi, MAX_TASKS
    jae .fail
    cmp rdi, 0
    jl .fail
    TCB_BASE r8, rdi
    cmp byte [r8 + TCB_STATE], TASK_FREE
    je .fail
    cmp byte [r8 + TCB_MAIL_COUNT], MSG_QUEUE_LEN
    jge .fail
    movzx r9, byte [r8 + TCB_MAIL_TAIL]
    mov r10, r9
    imul r10, MSG_SIZE
    lea r10, [r8 + TCB_MAILBOX + r10]
    mov r11, MSG_SIZE
.copy:
    mov al, [rsi]
    mov [r10], al
    inc rsi
    inc r10
    dec r11
    jnz .copy
    mov r11, [current_task]
    TCB_BASE r11, r11
    movzx r11, byte [r11 + TCB_PID]
    mov byte [r8 + TCB_MAIL_FROM + r9], r11b
    inc r9
    cmp r9, MSG_QUEUE_LEN
    jl .no_wrap
    xor r9, r9
.no_wrap:
    mov byte [r8 + TCB_MAIL_TAIL], r9b
    inc byte [r8 + TCB_MAIL_COUNT]
    cmp byte [r8 + TCB_STATE], TASK_RECV
    jne .ok
    mov byte [r8 + TCB_STATE], TASK_READY
.ok:
    xor eax, eax
    ret
.fail:
    mov eax, -1
    ret

ipc_recv:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
.retry:
    mov r8, [current_task]
    TCB_BASE r8, r8
    cmp byte [r8 + TCB_MAIL_COUNT], 0
    je .block
    cmp rbx, -1
    je .match
    movzx r9, byte [r8 + TCB_MAIL_HEAD]
    movzx r10, byte [r8 + TCB_MAIL_FROM + r9]
    cmp rbx, r10
    jne .block
.match:
    movzx r9, byte [r8 + TCB_MAIL_HEAD]
    mov r10, r9
    imul r10, MSG_SIZE
    lea r10, [r8 + TCB_MAILBOX + r10]
    mov r11, MSG_SIZE
    mov rsi, r12
.copy:
    mov al, [r10]
    mov [rsi], al
    inc r10
    inc rsi
    dec r11
    jnz .copy
    movzx rax, byte [r8 + TCB_MAIL_FROM + r9]
    inc r9
    cmp r9, MSG_QUEUE_LEN
    jl .no_wrap
    xor r9, r9
.no_wrap:
    mov byte [r8 + TCB_MAIL_HEAD], r9b
    dec byte [r8 + TCB_MAIL_COUNT]
    pop r12
    pop rbx
    ret
.block:
    mov byte [r8 + TCB_STATE], TASK_RECV
    call schedule
    jmp .retry

syscall_handler:
    mov rbp, rdi
    mov rax, [rbp + 112]
    mov r10, [rbp + 72]
    mov r11, [rbp + 80]
    mov r12, [rbp + 88]
    cmp rax, SYS_EXIT
    je .exit
    cmp rax, SYS_WRITE
    je .write
    cmp rax, SYS_SEND
    je .send
    cmp rax, SYS_RECV
    je .recv
    cmp rax, SYS_REPLY
    je .reply
    cmp rax, SYS_GETPID
    je .getpid
    cmp rax, SYS_SLEEP
    je .sleep
    cmp rax, SYS_YIELD
    je .yield
    cmp rax, SYS_FORK
    je .fork
    cmp rax, SYS_WAIT
    je .wait
    cmp rax, SYS_EXEC
    je .exec
    cmp rax, SYS_CLONE
    je .clone
    mov qword [rbp + 112], -1
    ret
.write:
    mov rdi, r10
    mov rsi, r11
    call kprint_len
    mov qword [rbp + 112], 0
    ret
.send:
    mov rdi, r10
    mov rsi, r11
    call ipc_send
    mov [rbp + 112], rax
    ret
.recv:
    mov rdi, r10
    mov rsi, r11
    call ipc_recv
    mov [rbp + 112], rax
    ret
.reply:
    mov rdi, r10
    mov rsi, r11
    call ipc_send
    mov [rbp + 112], rax
    ret
.getpid:
    mov rax, [current_task]
    TCB_BASE rax, rax
    movzx rax, byte [rax + TCB_PID]
    mov [rbp + 112], rax
    ret
.sleep:
    mov rax, [current_task]
    TCB_BASE rax, rax
    mov [rax + TCB_SLEEP], r10
    mov byte [rax + TCB_STATE], TASK_SLEEP
    call schedule
    mov qword [rbp + 112], 0
    ret
.yield:
    call schedule
    mov qword [rbp + 112], 0
    ret
.exit:
    mov rax, [current_task]
    TCB_BASE rax, rax
    mov [rax + TCB_EXIT_STATUS], r10
    mov rbx, [rax + TCB_CR3]
    cmp rbx, [kernel_cr3]
    je .no_free
    mov rdi, rbx
    call free_user_pages
.no_free:
    mov rax, [current_task]
    TCB_BASE rax, rax
    mov byte [rax + TCB_STATE], TASK_DEAD
    movzx rdx, byte [rax + TCB_PARENT]
    movzx r9, byte [rax + TCB_PID]
    xor rcx, rcx
.wake_loop:
    TCB_BASE rbx, rcx
    cmp byte [rbx + TCB_STATE], TASK_WAIT
    jne .wake_next
    movzx r8, byte [rbx + TCB_PID]
    cmp r8, rdx
    je .wake_found
.wake_next:
    inc rcx
    cmp rcx, MAX_TASKS
    jl .wake_loop
    jmp .wake_done
.wake_found:
    mov byte [rbx + TCB_STATE], TASK_READY
.wake_done:
    xor rcx, rcx
.reparent_loop:
    TCB_BASE rbx, rcx
    cmp byte [rbx + TCB_STATE], TASK_FREE
    je .reparent_next
    cmp byte [rbx + TCB_STATE], TASK_DEAD
    je .reparent_next
    movzx r8, byte [rbx + TCB_PARENT]
    cmp r8, r9
    jne .reparent_next
    mov byte [rbx + TCB_PARENT], 0
.reparent_next:
    inc rcx
    cmp rcx, MAX_TASKS
    jl .reparent_loop
    call schedule
    ret
.fork:
    call do_fork
    mov [rbp + 112], rax
    ret
.wait:
    mov r14, r10
    mov r15, r11
    mov rax, [current_task]
    TCB_BASE rax, rax
    movzx r13, byte [rax + TCB_PID]
.wloop:
    xor rcx, rcx
.wscan:
    TCB_BASE rax, rcx
    cmp byte [rax + TCB_STATE], TASK_DEAD
    jne .wnext
    movzx rdx, byte [rax + TCB_PARENT]
    cmp rdx, r13
    jne .wnext
    cmp r14, -1
    je .wfound
    movzx rdx, byte [rax + TCB_PID]
    cmp rdx, r14
    jne .wnext
.wfound:
    mov rdx, [rax + TCB_EXIT_STATUS]
    test r15, r15
    jz .wnostatus
    mov [r15], rdx
.wnostatus:
    mov byte [rax + TCB_STATE], TASK_FREE
    mov [rbp + 112], rcx
    ret
.wnext:
    inc rcx
    cmp rcx, MAX_TASKS
    jl .wscan
    mov rax, [current_task]
    TCB_BASE rax, rax
    mov byte [rax + TCB_STATE], TASK_WAIT
    call schedule
    jmp .wloop
.exec:
    call do_exec
    test eax, eax
    jnz .exec_fail
    mov qword [rbp + 112], 0
    ret
.exec_fail:
    mov qword [rbp + 112], -1
    ret
.clone:
    mov rdi, r10
    mov rsi, r11
    call do_clone
    mov [rbp + 112], rax
    ret

do_fork:
    push rbx
    push r12
    push r13
    push r14
    push r15
    xor rcx, rcx
.find:
    TCB_BASE rax, rcx
    cmp byte [rax + TCB_STATE], TASK_FREE
    je .found
    inc rcx
    cmp rcx, MAX_TASKS
    jl .find
    mov rax, -1
    jmp .done
.found:
    mov r12, rcx
    TCB_BASE r14, rcx
    call vmm_new_space
    test rax, rax
    jz .fail
    mov rbx, rax
    mov rdi, [current_pml4]
    mov rsi, rbx
    call fork_copy_space
    test eax, eax
    jnz .fail
    mov [r14 + TCB_CR3], rbx
    mov rax, r12
    inc rax
    imul rax, STACK_SIZE
    add rax, task_stacks
    sub rax, 176
    mov r13, rax
    mov rsi, rbp
    mov rdi, r13
    mov rcx, 176 / 8
    rep movsq
    mov qword [r13 + 112], 0
    mov rax, isr_return
    mov [r13 - 8], rax
    lea rdi, [r13 - 56]
    mov rcx, 6
    xor rax, rax
    rep stosq
    mov byte [r14 + TCB_STATE], TASK_READY
    mov byte [r14 + TCB_PID], r12b
    mov byte [r14 + TCB_MAIL_HEAD], 0
    mov byte [r14 + TCB_MAIL_TAIL], 0
    mov byte [r14 + TCB_MAIL_COUNT], 0
    mov qword [r14 + TCB_SLEEP], 0
    mov qword [r14 + TCB_EXIT_STATUS], 0
    mov r15, [current_task]
    TCB_BASE r15, r15
    movzx r15, byte [r15 + TCB_PID]
    mov byte [r14 + TCB_PARENT], r15b
    lea rdi, [r14 + TCB_NAME]
    mov rsi, name_forked
    mov rcx, 8
.name_loop:
    lodsb
    stosb
    test al, al
    jz .name_done
    loop .name_loop
.name_done:
    mov rax, r13
    sub rax, 56
    mov [r14 + TCB_RSP], rax
    mov rax, r12
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov rax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

do_exec:
    push rbx
    push r12
    push r13
    push r14
    push r15
    call vmm_new_space
    test rax, rax
    jz .fail
    mov r12, rax
    mov rdi, rax
    call vmm_p2v
    mov rdi, rax
    mov r8, [rdi + 0 * 8]
    mov rdi, r8
    mov r9, PAGE_MASK
    and rdi, r9
    call vmm_p2v
    mov rdi, rax
    mov r9, [pdpt_low + 0 * 8]
    mov [rdi + 0 * 8], r9
    mov rdi, r12
    mov rsi, elf_binary
    call elf_load
    cmp rax, -1
    je .fail
    mov r13, rax
    call pmm_alloc
    test rax, rax
    jz .fail
    mov r14, rax
    mov rdi, r14
    call vmm_p2v
    mov rdi, rax
    mov rcx, 512
    xor rax, rax
    rep stosq
    mov rdi, r12
    mov rsi, USER_STACK
    mov rdx, r14
    mov rcx, PTE_USER | PTE_WRITABLE
    call vmm_map
    mov rax, [current_task]
    TCB_BASE rax, rax
    mov [rax + TCB_CR3], r12
    mov [current_pml4], r12
    mov cr3, r12
    mov qword [rbp + 136], r13
    mov qword [rbp + 160], USER_STACK + 4096
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

do_clone:
    push rbx
    push r12
    push r13
    push r14
    push r15
    xor rcx, rcx
.find:
    TCB_BASE rax, rcx
    cmp byte [rax + TCB_STATE], TASK_FREE
    je .found
    inc rcx
    cmp rcx, MAX_TASKS
    jl .find
    mov rax, -1
    jmp .done
.found:
    mov r12, rcx
    TCB_BASE r14, rcx
    mov r13, rdi
    mov rbx, rsi
    mov rax, rcx
    inc rax
    imul rax, STACK_SIZE
    add rax, task_stacks
    sub rax, 176
    mov r15, rax
    mov rdi, r15
    mov rcx, 22
    xor rax, rax
    rep stosq
    mov qword [r15 + 120], 128
    mov qword [r15 + 136], r13
    mov qword [r15 + 144], USER_CODE_SEL | 3
    mov qword [r15 + 152], 0x202
    mov qword [r15 + 160], rbx
    mov qword [r15 + 168], USER_DATA_SEL | 3
    mov rax, isr_return
    mov [r15 - 8], rax
    lea rdi, [r15 - 56]
    mov rcx, 6
    xor rax, rax
    rep stosq
    mov byte [r14 + TCB_STATE], TASK_READY
    mov byte [r14 + TCB_PID], r12b
    mov byte [r14 + TCB_MAIL_HEAD], 0
    mov byte [r14 + TCB_MAIL_TAIL], 0
    mov byte [r14 + TCB_MAIL_COUNT], 0
    mov qword [r14 + TCB_SLEEP], 0
    mov qword [r14 + TCB_EXIT_STATUS], 0
    mov r13, [current_task]
    TCB_BASE r13, r13
    movzx r13, byte [r13 + TCB_PID]
    mov byte [r14 + TCB_PARENT], r13b
    mov r13, cr3
    mov [r14 + TCB_CR3], r13
    lea rdi, [r14 + TCB_NAME]
    mov rsi, name_thread
    mov rcx, 8
.name_loop:
    lodsb
    stosb
    test al, al
    jz .name_done
    loop .name_loop
.name_done:
    mov rax, r15
    sub rax, 56
    mov [r14 + TCB_RSP], rax
    mov rax, r12
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

load_segment:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15, rcx
    mov rbx, r8
.loop:
    cmp rbx, 0
    jle .done
    call pmm_alloc
    test rax, rax
    jz .fail
    mov rbp, rax
    mov rdi, rbp
    call vmm_p2v
    mov rdi, rax
    mov rcx, 512
    xor rax, rax
    rep stosq
    test r15, r15
    jz .map
    mov rcx, r15
    cmp rcx, 4096
    jle .copy
    mov rcx, 4096
.copy:
    mov rdi, rbp
    call vmm_p2v
    mov rdi, rax
    mov rsi, r14
    mov r8, rcx
    rep movsb
    add r14, r8
    sub r15, r8
.map:
    mov rdi, r12
    mov rsi, r13
    mov rdx, rbp
    mov rcx, PTE_USER | PTE_WRITABLE
    call vmm_map
    add r13, 4096
    sub rbx, 4096
    jmp .loop
.done:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
.fail:
    mov eax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

elf_load:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    cmp dword [r13], 0x464C457F
    jne .fail
    mov r14, [r13 + 24]
    mov r15, [r13 + 32]
    movzx rbx, word [r13 + 56]
.ph_loop:
    test rbx, rbx
    jz .done
    lea r8, [r13 + r15]
    cmp dword [r8], 1
    jne .ph_next
    mov rdi, r12
    mov rsi, [r8 + 16]
    mov rdx, [r8 + 8]
    add rdx, r13
    mov rcx, [r8 + 32]
    mov r8, [r8 + 40]
    call load_segment
    test eax, eax
    jnz .fail
.ph_next:
    add r15, 56
    dec rbx
    jmp .ph_loop
.done:
    mov rax, r14
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail:
    mov rax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

free_user_pages:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov rdi, r12
    call vmm_p2v
    mov r8, [rax + 0 * 8]
    mov rdi, r8
    mov r9, PAGE_MASK
    and rdi, r9
    call vmm_p2v
    mov r13, rax
    mov rbx, 1
.p3:
    cmp rbx, 512
    jge .done
    mov r8, [r13 + rbx * 8]
    test r8, PTE_PRESENT
    jz .p3next
    mov rdi, r8
    mov r9, PAGE_MASK
    and rdi, r9
    call vmm_p2v
    mov r14, rax
    xor rbp, rbp
.p2:
    cmp rbp, 512
    jge .p2done
    mov r9, [r14 + rbp * 8]
    test r9, PTE_PRESENT
    jz .p2next
    test r9, 0x80
    jnz .p2next
    mov rdi, r9
    mov r10, PAGE_MASK
    and rdi, r10
    call vmm_p2v
    mov r15, rax
    xor rcx, rcx
.p1:
    cmp rcx, 512
    jge .p1done
    mov r10, [r15 + rcx * 8]
    test r10, PTE_PRESENT
    jz .p1next
    test r10, PTE_USER
    jz .p1next
    mov rdi, r10
    mov r11, PAGE_MASK
    and rdi, r11
    push rcx
    call pmm_free
    pop rcx
.p1next:
    inc rcx
    jmp .p1
.p1done:
.p2next:
    inc rbp
    jmp .p2
.p2done:
.p3next:
    inc rbx
    jmp .p3
.done:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

fork_copy_space:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov rdi, r12
    call vmm_p2v
    mov r9, [rax + 0 * 8]
    mov rdi, r9
    mov r11, PAGE_MASK
    and rdi, r11
    call vmm_p2v
    mov r14, rax
    mov rdi, r13
    call vmm_p2v
    mov r9, [rax + 0 * 8]
    mov rdi, r9
    mov r11, PAGE_MASK
    and rdi, r11
    call vmm_p2v
    mov r15, rax
    xor rbx, rbx
.p3:
    mov r8, [r14 + rbx * 8]
    test r8, PTE_PRESENT
    jz .p3next
    mov rdi, r8
    mov r11, PAGE_MASK
    and rdi, r11
    call vmm_p2v
    mov r9, [rax + 0 * 8]
    test r9, 0x80
    jnz .share
    xor rdx, rdx
.p2:
    mov rdi, r8
    mov r11, PAGE_MASK
    and rdi, r11
    call vmm_p2v
    mov r9, [rax + rdx * 8]
    test r9, PTE_PRESENT
    jz .p2next
    test r9, 0x80
    jnz .p2next
    xor rbp, rbp
.p1:
    mov rdi, r9
    mov r11, PAGE_MASK
    and rdi, r11
    call vmm_p2v
    mov rcx, [rax + rbp * 8]
    test rcx, PTE_PRESENT
    jz .p1next
    test rcx, PTE_USER
    jz .p1next
    mov r10, rcx
    mov r11, PAGE_MASK
    and r10, r11
    mov rax, rbx
    shl rax, 30
    mov r11, rdx
    shl r11, 21
    or rax, r11
    mov r11, rbp
    shl r11, 12
    or rax, r11
    push r8
    push rdx
    push r9
    push rax
    push r10
    call pmm_alloc
    test rax, rax
    jz .leaf_fail
    push rax
    mov rdi, [rsp + 8]
    call vmm_p2v
    mov rsi, rax
    mov rdi, [rsp]
    call vmm_p2v
    mov rdi, rax
    mov rcx, 512
    rep movsq
    mov rdi, r13
    mov rsi, [rsp + 16]
    mov rdx, [rsp]
    mov rcx, PTE_USER | PTE_WRITABLE
    call vmm_map
    add rsp, 24
    pop r9
    pop rdx
    pop r8
    jmp .p1next
.leaf_fail:
    add rsp, 16
    pop r9
    pop rdx
    pop r8
    mov eax, -1
    jmp .done
.p1next:
    inc rbp
    cmp rbp, 512
    jl .p1
.p2next:
    inc rdx
    cmp rdx, 512
    jl .p2
    jmp .p3next
.share:
    mov [r15 + rbx * 8], r8
.p3next:
    inc rbx
    cmp rbx, 512
    jl .p3
    xor eax, eax
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

strcmp:
    push rdi
    push rsi
.loop:
    mov al, [rdi]
    mov dl, [rsi]
    cmp al, dl
    jne .no
    test al, al
    jz .yes
    inc rdi
    inc rsi
    jmp .loop
.yes:
    xor eax, eax
    pop rsi
    pop rdi
    ret
.no:
    mov eax, 1
    pop rsi
    pop rdi
    ret

starts_with:
    push rdi
    push rsi
.loop:
    mov al, [rsi]
    test al, al
    jz .yes
    mov dl, [rdi]
    cmp al, dl
    jne .no
    inc rdi
    inc rsi
    jmp .loop
.yes:
    xor eax, eax
    pop rsi
    pop rdi
    ret
.no:
    mov eax, 1
    pop rsi
    pop rdi
    ret

init_task:
    mov rdi, shell_task
    mov rsi, name_shell
    call task_create
    mov [shell_pid], rax
    mov rdi, echo_task
    mov rsi, name_echo
    call task_create
    mov [echo_pid], rax
    mov rsi, str_init_done
    call kprint
.loop:
    hlt
    jmp .loop

shell_task:
    mov rsi, prompt
    call kprint
.loop:
    mov rdi, -1
    mov rsi, shell_buf
    mov rax, SYS_RECV
    int 0x80
    call process_command
    mov rsi, prompt
    call kprint
    jmp .loop

process_command:
    mov rdi, shell_buf
    cmp byte [rdi], 0
    je .done
    mov rdi, shell_buf
    mov rsi, cmd_help
    call strcmp
    test eax, eax
    jz .help
    mov rdi, shell_buf
    mov rsi, cmd_about
    call strcmp
    test eax, eax
    jz .about
    mov rdi, shell_buf
    mov rsi, cmd_version
    call strcmp
    test eax, eax
    jz .about
    mov rdi, shell_buf
    mov rsi, cmd_clear
    call strcmp
    test eax, eax
    jz .clear
    mov rdi, shell_buf
    mov rsi, cmd_mem
    call strcmp
    test eax, eax
    jz .mem
    mov rdi, shell_buf
    mov rsi, cmd_tasks
    call strcmp
    test eax, eax
    jz .tasks
    mov rdi, shell_buf
    mov rsi, cmd_halt
    call strcmp
    test eax, eax
    jz .halt
    mov rdi, shell_buf
    mov rsi, cmd_uptime
    call strcmp
    test eax, eax
    jz .uptime
    mov rdi, shell_buf
    mov rsi, cmd_cpu
    call strcmp
    test eax, eax
    jz .cpu
    mov rdi, shell_buf
    mov rsi, cmd_reboot
    call strcmp
    test eax, eax
    jz .reboot
    mov rdi, shell_buf
    mov rsi, cmd_demo
    call strcmp
    test eax, eax
    jz .demo
    mov rdi, shell_buf
    mov rsi, cmd_cls
    call strcmp
    test eax, eax
    jz .clear
    mov rdi, shell_buf
    mov rsi, cmd_echo
    call starts_with
    test eax, eax
    jz .echo
    mov rsi, unknown_text
    call kprint
.done:
    ret
.help:
    mov rsi, help_text
    call kprint
    ret
.about:
    mov rsi, about_text
    call kprint
    ret
.clear:
    call kclear
    ret
.mem:
    mov rsi, str_mem_free
    call kprint
    call pmm_free_pages
    call kprint_dec
    call knewline
    ret
.tasks:
    push rbx
    xor rbx, rbx
.loop:
    TCB_BASE rax, rbx
    cmp byte [rax + TCB_STATE], TASK_FREE
    je .next
    mov rax, rbx
    call kprint_dec
    mov al, ' '
    call kputc
    TCB_BASE rax, rbx
    movzx rax, byte [rax + TCB_STATE]
    cmp rax, 7
    jb .ok
    mov rax, 6
.ok:
    mov rsi, [state_names + rax * 8]
    call kprint
    mov al, ' '
    call kputc
    TCB_BASE rax, rbx
    movzx rax, byte [rax + TCB_PARENT]
    call kprint_dec
    mov al, ' '
    call kputc
    TCB_BASE rax, rbx
    lea rsi, [rax + TCB_NAME]
    call kprint
    call knewline
.next:
    inc rbx
    cmp rbx, MAX_TASKS
    jl .loop
    pop rbx
    ret
.halt:
    mov rsi, str_halt
    call kprint
    cli
    hlt
    jmp $
.echo:
    mov rsi, shell_buf + 5
    mov rdi, [echo_pid]
    mov rax, SYS_SEND
    int 0x80
    mov rdi, [echo_pid]
    mov rsi, shell_recv_buf
    mov rax, SYS_RECV
    int 0x80
    mov rsi, shell_recv_buf
    call kprint
    call knewline
    ret
.uptime:
    mov rsi, str_uptime
    call kprint
    mov rax, [tick_count]
    call kprint_dec
    mov rsi, str_uptime_s
    call kprint
    ret
.cpu:
    call cpu_vendor
    call knewline
    ret
.reboot:
    mov al, 0xFE
    out 0x64, al
    cli
    hlt
    jmp $
.demo:
    mov rdi, user_task
    mov rsi, name_user
    call task_create
    ret

cpu_vendor:
    push rbx
    push rcx
    push rdx
    mov eax, 0
    cpuid
    mov [vendor_buf], ebx
    mov [vendor_buf + 4], edx
    mov [vendor_buf + 8], ecx
    mov byte [vendor_buf + 12], 0
    mov rsi, vendor_buf
    call kprint
    pop rdx
    pop rcx
    pop rbx
    ret

echo_task:
.loop:
    mov rdi, -1
    mov rsi, echo_buf
    mov rax, SYS_RECV
    int 0x80
    mov rdi, rax
    mov rsi, echo_buf
    mov rax, SYS_REPLY
    int 0x80
    jmp .loop

user_task:
    call pmm_alloc
    test rax, rax
    jz .fail
    mov r12, rax
    mov rdi, [current_pml4]
    mov rsi, USER_ADDR
    mov rdx, r12
    mov rcx, PTE_USER | PTE_WRITABLE
    call vmm_map
    mov rdi, USER_ADDR
    mov rsi, user_code
    mov rcx, user_code_end - user_code
    rep movsb
    mov rax, USER_DATA_SEL | 3
    push rax
    mov rax, USER_ADDR + 4096
    push rax
    mov rax, 0x202
    push rax
    mov rax, USER_CODE_SEL | 3
    push rax
    mov rax, USER_ADDR
    push rax
    iretq
.fail:
    mov rsi, str_user_fail
    call kprint
    mov rax, SYS_EXIT
    int 0x80
    jmp .fail

user_code:
    mov rax, SYS_WRITE
    mov rdi, msg_parent
    mov rsi, 7
    int 0x80
    mov rax, SYS_FORK
    int 0x80
    test rax, rax
    jz .child
    mov rax, SYS_EXIT
    mov rdi, 0
    int 0x80
    jmp $
.child:
    mov rax, SYS_WRITE
    mov rdi, msg_child
    mov rsi, 6
    int 0x80
    mov rax, SYS_SLEEP
    mov rdi, 400
    int 0x80
    mov rax, SYS_EXIT
    mov rdi, 0
    int 0x80
    jmp $
user_code_end:

elf_binary:
    db 0x7F, 'E', 'L', 'F', 2, 1, 1, 0
    times 8 db 0
    dw 2
    dw 62
    dd 1
    dq USER_ADDR
    dq 64
    dq 0
    dd 0
    dw 64
    dw 56
    dw 1
    dw 0
    dw 0
    dw 0
    dd 1
    dd 7
    dq 0x80
    dq USER_ADDR
    dq USER_ADDR
    dq elf_code_end - elf_code
    dq elf_code_end - elf_code
    dq 0x1000
    times (0x80 - ($ - elf_binary)) db 0
elf_code:
    mov rax, SYS_WRITE
    mov rdi, msg_elf
    mov rsi, 4
    int 0x80
    mov rax, SYS_EXIT
    mov rdi, 0
    int 0x80
    jmp $
elf_code_end:

banner:
    db "Power Kernel 0.3.0", 10
    db "x86_64 microkernel", 10, 10, 0

str_vmm_ok db 0
str_vmm_fail db "[vmm] address space test FAILED", 10, 0
str_demand_ok db 0
str_demand_fail db "[vmm] demand paging test FAILED", 10, 0
str_cow_ok db 0
str_cow_fail db "[vmm] copy-on-write test FAILED", 10, 0
str_buddy_ok db 0
str_buddy_fail db "[mm] buddy allocator test FAILED", 10, 0
str_slab_ok db 0
str_slab_fail db "[mm] slab allocator test FAILED", 10, 0
str_mmap_ok db 0
str_mmap_fail db "[vmm] mmap/mprotect test FAILED", 10, 0
str_selftest_ok db "[ok] self-tests passed", 10, 0
str_pf db "[vmm] page fault at ", 0
str_sched_ok db "[sched] scheduler started", 10, 10, 0
str_init_done db "[init] system ready", 10, 10, 0
str_exception db "Exception #", 0
str_rip db " RIP=", 0
str_mem_free db "[mem] free pages: ", 0
str_halt db "System halted.", 10, 0
prompt db "PowerKernel> ", 0

cmd_help db "help", 0
cmd_about db "about", 0
cmd_version db "version", 0
cmd_clear db "clear", 0
cmd_cls db "cls", 0
cmd_mem db "mem", 0
cmd_tasks db "tasks", 0
cmd_halt db "halt", 0
cmd_echo db "echo ", 0
cmd_uptime db "uptime", 0
cmd_cpu db "cpu", 0
cmd_reboot db "reboot", 0
cmd_demo db "demo", 0

str_uptime db "uptime: ", 0
str_uptime_s db " ticks", 10, 0

help_text:
    db "available commands:", 10
    db "  help           show this help", 10
    db "  about          about this kernel", 10
    db "  version        print version", 10
    db "  clear / cls    clear the screen", 10
    db "  mem            free physical memory", 10
    db "  tasks          list tasks", 10
    db "  uptime         ticks since boot", 10
    db "  cpu            CPU vendor string", 10
    db "  echo <text>    echo text via IPC", 10
    db "  demo           run the process demo", 10
    db "  reboot         reboot the system", 10
    db "  halt           halt the system", 10, 0

about_text:
    db "Power Kernel 0.3.0 - x86-64 microkernel in NASM assembly", 10, 0

unknown_text db "unknown command, type 'help'", 10, 0

name_init db "init", 0
name_shell db "shell", 0
name_echo db "echo", 0
name_user db "user", 0
name_forked db "forked", 0
name_thread db "thread", 0

user_msg db "USER-OK", 10, 0
str_user_fail db "[user] ring 3 test FAILED", 10, 0
msg_parent db "parent", 10, 0
msg_child db "child", 10, 0
msg_done db "parent done", 10, 0
msg_nl db 10, 0
msg_elf db "elf", 10, 0
msg_thread db "thread", 10, 0

state_names:
    dq str_state_free, str_state_ready, str_state_running, str_state_recv, str_state_sleep, str_state_dead, str_state_wait

str_state_free db "free", 0
str_state_ready db "ready", 0
str_state_running db "running", 0
str_state_recv db "recv", 0
str_state_sleep db "sleep", 0
str_state_dead db "dead", 0
str_state_wait db "wait", 0

idtr:
    dw 256 * 16 - 1
    dq idt

align 4096
pml4:       resb 4096
pdpt_low:   resb 4096
pd_low:     resb 4096
pdpt_high:  resb 4096
pd_high:    resb 4096
pdpt_direct: resb 4096
pd_direct:  resb 4096
stack:      resb 16384
stack_top:

mb_info_ptr: resq 1
current_pml4: resq 1
kernel_cr3:  resq 1
current_task: resq 1
tick_count: resq 1
shell_pid:  resq 1
echo_pid:   resq 1
vga_row:    resb 1
vga_col:    resb 1
vga_color:  resb 1
heap_cur:   resq 1
kbd_len:    resq 1
kbd_buf:    resb 64
shell_buf:  resb 64
shell_recv_buf: resb 64
echo_buf:   resb 64
vendor_buf: resb 16

idt:        resb 256 * 16
pmm_bitmap: resb TOTAL_PAGES / 8
buddy_lists: resq BUDDY_MAX_ORDER + 1
slab_free:  resq 8
tcb_array:  resb MAX_TASKS * TCB_SIZE
task_stacks: resb MAX_TASKS * STACK_SIZE
_end:
