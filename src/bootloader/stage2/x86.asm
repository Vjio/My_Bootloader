bits 16

section _ENTRY class=TEXT

global _x86_Video_WriteCharTeletype
global _x86_div64_32
global _x86_Disk_Reset
global _x86_Disk_Read
global _x86_Disk_GetDriveParams
global __U4D
global __U4M

;
; int 10h ah=0Eh
; args: character, page
;
_x86_Video_WriteCharTeletype:
	; make new stack frame
	push bp
	mov bp, sp

	push bx                         ; save bx

	; [bp + 0] - return address (small memory model => 2 bytes)
	; [bp + 2] - old call frame
	; [bp + 4] - first argument (character)
	; [bp + 6] - second argument (page)
	; check https://www.ctyme.com/intr/rb-0106.htm if confused
	mov ah, 0Eh
	mov al, [bp + 4]
	mov bh, [bp + 6]

	int 10h

	pop bx

	mov sp, bp
	pop bp
	ret

; divides a 64 bit number by a 32 bit one
; args: 
;   [bp + 0] - ret address
;   [bp + 2] - old call frame
;   [bp + 4] - divident lower 32
;   [bp + 8] - divindent upper 32
;   [bp + 12] - divisor
;   [bp + 16] - quotient
;   [bp + 18] - remainder
;   pointers in small mem model are 2 bytes
;
_x86_div64_32:
	; make new stack frame
	push bp
	mov bp, sp

	push bx                     ; save registers

	; divide upper 32 bits
	mov eax, [bp + 8]           ; upper 32 bits of divident
	mov ecx, [bp + 12]          ; ecx <- divisor
	xor edx, edx
	div ecx                     ; eax - quotient, edx - remainder

	; store upper 32 bits of quotient
	mov bx, [bp + 16]           ; get pointer to quotient
	mov [bx + 4], eax           ; store in the upper half

	; divide upper 32 bits
	mov eax, [bp + 4]           ; lower 32 bits of divident
	mov ecx, [bp + 12]          ; ecx <- divisor
								; edx <- old remainder
	div ecx

	; store results
	mov [bx], eax
	mov bx, [bp + 18]           ; get pointer to remainder
	mov [bx], edx

	pop bx

	mov sp, bp
	pop bp
	ret

; args:
;   [bp + 0] return address
;   [bp + 2] old stack frame
;   [bp + 4] drive number
;
_x86_Disk_Reset:
	push bp
	mov bp, sp

	mov ah, 0
	mov dl, [bp + 4]

	stc
	int 13h

	mov ax, 1
	sbb ax, 0                   ; 1 on success, 0 on failure

	mov sp, bp
	pop bp
	ret

; args:
;   [bp + 0] ret addr
;   [bp + 2] old stack frame
;   [bp + 4] drive number
;   [bp + 6] cylinder
;   [bp + 8] head
;   [bp + 10] sector
;   [bp + 12] count
;   [bp + 14] dataOut
;
_x86_Disk_Read:
	push bp
	mov bp, sp

	push bx
	push es

	mov dl, [bp + 4]
	mov ch, [bp + 6]            ; low bits of cylinder

	mov cl, [bp + 7]            ; cylinder, bits 6-7
	shl cl, 6

	mov dh, [bp + 8]            ; head number

	mov al, [bp + 10]
	and al, 3Fh                 ; 3F = 0011 1111
	or cl, al                   ; sector number, bits 0-5

	mov al, [bp + 12]           ; number of sectors to read

	mov bx, [bp + 16]
	mov es, bx
	mov bx, [bp + 14]

	mov ah, 02h
	stc
	int 13h

	pop es
	pop bx

	mov sp, bp
	pop bp
	ret

; args:
;   [bp + 4] drive
;   [bp + 6] driveTypeOut
;   [bp + 8] cylindersOut
;   [bp + 10] headsOut
;   [bp + 12] sectorsOut
_x86_Disk_GetDriveParams:
	push bp
	mov bp, sp

	push es
	push bx
	push si
	push di

	mov dh, [bp + 4]
	mov di, 0
	mov es, di
	mov ah, 08h

	stc
	int 13h

	; returns
	mov ax, 1
	sbb ax, 0

	mov si, [bp + 6]
	mov [si], bl

	mov bl, ch          ; cylinders - lower bits in ch
	mov bh, cl          ; cylinders - upper bits in cl (6-7)
	shr bh, 6
	mov si, [bp + 8]
	mov [si], bx

	mov si, [bp + 10]
	mov [si], dh        ; head number

	mov si, [bp + 12]
	xor bl, bl
	mov bl, cl          ; cl - max sector number in bits 0-5
	and bl, 3Fh
	mov [si], bl

	; restore registers
	pop di
	pop si
	pop bx
	pop es

	mov sp, bp
	pop bp
	ret

; U4D
; Operation:      Unsigned 4 byte divide
; Inputs:         DX;AX   Dividend
;                 CX;BX   Divisor
; Outputs:        DX;AX   Quotient
;                 CX;BX   Remainder
; Volatile:       none
;
__U4D:
	shl edx, 16         ; dx to upper half of edx
	mov dx, ax          ; edx - dividend
	mov eax, edx        ; eax - dividend
	xor edx, edx

	shl ecx, 16         ; cx to upper half of ecx
	mov cx, bx          ; ecx - divisor

	div ecx             ; eax - quot, edx - remainder
	mov ebx, edx
	mov ecx, edx
	shr ecx, 16

	mov edx, eax
	shr edx, 16

	ret


; U4M
; Operation:      integer four byte multiply
; Inputs:         DX;AX   integer M1
;                 CX;BX   integer M2
; Outputs:        DX;AX   product
; Volatile:       CX, BX destroyed
;
__U4M:
    shl edx, 16         ; dx to upper half of edx
    mov dx, ax          ; m1 in edx
    mov eax, edx        ; m1 in eax

    shl ecx, 16         ; cx to upper half of ecx
    mov cx, bx          ; m2 in ecx

    mul ecx             ; result in edx:eax (we only need eax)
    mov edx, eax        ; move upper half to dx
    shr edx, 16

    ret

