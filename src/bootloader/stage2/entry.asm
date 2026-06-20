bits 16

section .entry

extern __bss_start
extern __end
extern start
global entry

entry:
    cli

    ; save boot drive
    mov [g_BootDrive], dl

    ; setup stack
    mov ax, ds
    mov ss, ax
    mov sp, 0xFFF0
    mov bp, sp

    ; enable A20 line
    call enable_A20

    ; load GDT
    lgdt [g_GDTDesc]

    ; set protection enable flag in CR0
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; far jump into protected mode
    jmp dword 08h:.pmode
    
.pmode:
    ; we are now in protected mode!
    [bits 32]
    
    ; setup segment registers
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
   
    ; clear bss (uninitialized data)
    mov edi, __bss_start
    mov ecx, __end
    sub ecx, edi
    mov al, 0
    cld
    rep stosb

    ; expect boot drive in dl, send it as argument to cstart function
    xor edx, edx
    mov dl, [g_BootDrive]
    push edx
    call start

    cli
    hlt

enable_A20:
    [bits 16]
    ; code taken from os dev wiki
    call    a20wait
    mov     al, KbdControllerDisableKeyboard
    out     KbdControllerCommandPort,al         ; disable keyboard

    call    a20wait
    mov     al,KbdControllerReadCtrlOutputPort
    out     KbdControllerCommandPort,al         ; read controller output port

    call    a20wait2
    in      al,KbdControllerDataPort         ; save response byte
    push    eax

    call    a20wait
    mov     al,KbdControllerWriteCtrlOutputPort
    out     KbdControllerCommandPort,al         ; write next byte into controller output port

    call    a20wait
    pop     eax
    or      al,2            ; set controller output bit for A20 on
    out     KbdControllerDataPort,al         ; activate A20

    call    a20wait
    mov     al,KbdControllerEnableKeyboard
    out     KbdControllerCommandPort,al         ; reactivate keyboard

    call    a20wait
    ret

a20wait:                        ; wait until input buffer is clear
    in      al,KbdControllerCommandPort
    test    al,2
    jnz     a20wait
    ret


a20wait2:                       ; wait until response byte has arrived
    in      al,KbdControllerCommandPort
    test    al,1
    jz      a20wait2
    ret


KbdControllerDataPort               equ 0x60
KbdControllerCommandPort            equ 0x64
KbdControllerDisableKeyboard        equ 0xAD
KbdControllerEnableKeyboard         equ 0xAE
KbdControllerReadCtrlOutputPort     equ 0xD0
KbdControllerWriteCtrlOutputPort    equ 0xD1

; Global Descriptor Table - https://wiki.osdev.org/GDT_Tutorial
g_GDT:      ; NULL descriptor
            dq 0

            ; 32-bit code segment
            dw 0FFFFh                   ; limit (bits 0-15) = 0xFFFFF for full 32-bit range
            dw 0                        ; base (bits 0-15) = 0x0
            db 0                        ; base (bits 16-23)
            db 10011010b                ; access (present, ring 0, code segment, executable, direction 0, readable)
            db 11001111b                ; granularity (4k pages, 32-bit pmode) + limit (bits 16-19)
            db 0                        ; base high

            ; 32-bit data segment
            dw 0FFFFh                   ; limit (bits 0-15) = 0xFFFFF for full 32-bit range
            dw 0                        ; base (bits 0-15) = 0x0
            db 0                        ; base (bits 16-23)
            db 10010010b                ; access (present, ring 0, data segment, executable, direction 0, writable)
            db 11001111b                ; granularity (4k pages, 32-bit pmode) + limit (bits 16-19)
            db 0                        ; base high

            ; 16-bit code segment
            dw 0FFFFh                   ; limit (bits 0-15) = 0xFFFFF
            dw 0                        ; base (bits 0-15) = 0x0
            db 0                        ; base (bits 16-23)
            db 10011010b                ; access (present, ring 0, code segment, executable, direction 0, readable)
            db 00001111b                ; granularity (1b pages, 16-bit pmode) + limit (bits 16-19)
            db 0                        ; base high

            ; 16-bit data segment
            dw 0FFFFh                   ; limit (bits 0-15) = 0xFFFFF
            dw 0                        ; base (bits 0-15) = 0x0
            db 0                        ; base (bits 16-23)
            db 10010010b                ; access (present, ring 0, data segment, executable, direction 0, writable)
            db 00001111b                ; granularity (1b pages, 16-bit pmode) + limit (bits 16-19)
            db 0                        ; base high

g_GDTDesc:  dw g_GDTDesc - g_GDT - 1    ; limit = size of GDT
            dd g_GDT                    ; address of GDT

g_BootDrive: db 0
