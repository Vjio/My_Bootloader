; loaded in memory here
org 0x7C00
bits 16

; shortcut for \n
%define ENDL 0x0D, 0x0A

; FAT12 (File Allocation Table) header. taken directly from the FAT documentation
; This must be a valid FAT12 header because the disk image is formatted
; as FAT12 and this boot sector replaces the one mkfs.fat generated.
; The code below also reads these fields (sectors per fat, heads, etc.)
; to locate the root directory and stage 2.
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2					; 2 for redundancy
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
							db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'VJI BOOT   '        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes


; code starts here
start:
	; setup segments registers
	mov ax, 0
	; can't write to ds, es dirrectly
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax          ; move stack segment
	mov sp, 0x7C00      ; move stack pointer so we don't overwrite

	; some BIOSes might start us at 07C0:0000 instead of 0000:7C00, make sure we are in the
	; expected location
	push ax
	push word .after
	; retf pops both ip and the code segment
	retf

	; this function reads the drives geometry
	; and the searches for the stage 2 binary on the disk
.after:

	; BIOS should set DL to drive number
	mov [ebr_drive_number], dl

	; show loading message
	mov si, msg_loading
	call puts

	; read drive parameters (sectors per track and head count),
	; instead of relying on data on formatted disk
	push es
	mov ah, 08h
	int 13h
	; BIOS int uses CF for ret value
	jc floppy_error
	pop es

	; ch holds the upper part of the cylinder count
	; cl upper 2 bits hold the lower part of the cylinder count
	; cl lower 6 bits hold the sector count
	and cl, 0x3F                        ; AND 0011 1111
	xor ch, ch
	mov [bdb_sectors_per_track], cx     ; sector count

	; dh = maxIndex, index starts from 0. +1 to find total number of heads
	inc dh
	mov [bdb_heads], dh                 ; head count

	; compute LBA of root directory = reserved + fats * sectors_per_fat
	; note: this section can be hardcoded
	mov ax, [bdb_sectors_per_fat]
	mov bl, [bdb_fat_count]
	xor bh, bh
	mul bx                              ; ax = (fats * sectors_per_fat)
	add ax, [bdb_reserved_sectors]      ; ax = LBA of root directory
	push ax

	; compute size of root directory in sectors = (entry_size * number_of_entries) / bytes_per_sector
	; 32 - FAT_entry_size
	mov ax, [bdb_dir_entries_count]
	shl ax, 5                           ; ax *= entry_size
	xor dx, dx
	div word [bdb_bytes_per_sector]     ; number of sectors we need to read

	test dx, dx                         ; if dx != 0, add 1
	jz .root_dir_after
	inc ax                              ; division remainder != 0, add 1
										; this means we have a sector only partially filled with entries
.root_dir_after:
	; read root directory
	mov cl, al                          ; cl = number of sectors to read = size of root directory
	pop ax                              ; ax = LBA of root directory
	mov dl, [ebr_drive_number]          ; dl = drive number (we saved it previously)
	mov bx, buffer                      ; es:bx = buffer
	call disk_read

	; search for 2nd stage binary
	xor bx, bx							; entry counter
	mov di, buffer

.search_stage_2:
	mov si, file_stage_2_bin
	mov cx, 11                          ; compare up to 11 characters
	push di
	cld									; set DF to 0
	repe cmpsb
	pop di
	je .found_stage_2

	add di, FAT_entry_size				; keep walking the buffer
	inc bx
	cmp bx, [bdb_dir_entries_count]
	jl .search_stage_2

	; stage 2 not found
	jmp stage_2_not_found_error

.found_stage_2:
	; di holds the address of the FAT entry of the 2nd stage binary
	mov ax, [di + 26]                   ; first logical cluster field (offset 26)
	mov [stage_2_cluster], ax

	; load FAT from disk into memory
	mov ax, [bdb_reserved_sectors]
	mov bx, buffer
	mov cl, [bdb_sectors_per_fat]
	mov dl, [ebr_drive_number]
	call disk_read

	; read 2nd stage and process FAT chain
	mov bx, STAGE_2_LOAD_SEGMENT
	mov es, bx
	mov bx, STAGE_2_LOAD_OFFSET

.load_stage_2_loop:
	; Read next cluster
	mov ax, [stage_2_cluster]
	
	; not nice :( hardcoded value
	add ax, 31                          ; first cluster = (stage_2_cluster - 2) * sectors_per_cluster + start_sector
										; start sector = reserved + fats + root directory size = 1 + 18 + 14 = 33
	mov cl, 1
	mov dl, [ebr_drive_number]
	call disk_read

	add bx, [bdb_bytes_per_sector]

	; compute location of next cluster
	mov ax, [stage_2_cluster]
	mov cx, 3
	mul cx
	mov cx, 2
	div cx                              ; ax = index of entry in FAT, dx = cluster mod 2

	mov si, buffer
	add si, ax
	mov ax, [ds:si]                     ; read entry from FAT table at index ax

	or dx, dx
	jz .even

.odd:
	shr ax, 4
	jmp .next_cluster_after

.even:
	and ax, 0x0FFF

.next_cluster_after:
	cmp ax, 0x0FF8                      ; end of chain
	jae .read_finish

	mov [stage_2_cluster], ax
	jmp .load_stage_2_loop

.read_finish:
	; jump to to the 2nd stage
	mov dl, [ebr_drive_number] 			; boot device in dl

	mov ax, STAGE_2_LOAD_SEGMENT        ; set segment registers
	mov ds, ax
	mov es, ax

	jmp STAGE_2_LOAD_SEGMENT:STAGE_2_LOAD_OFFSET


; Prints a string to the screen
; Params:
;   ds:si points to string
puts:
	; push all registers that will be modified
	push si
	push ax
	push bx

	cld			; set DF to 0
.loop:
	; loads [si] into al. increments si
	lodsb
	or al, al   ; verify if next char is NULL
	jz .done

	; BIOS INT 10h, interuption for writting
	mov ah, 0x0e
	mov bh, 0	; page number (the video card has 7 buffers called pages)
	int 0x10

	jmp .loop

.done:
	pop bx
	pop ax
	pop si
	ret


; Error handlers
;
floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

stage_2_not_found_error:
    mov si, msg_stage_2_not_found
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h                     ; wait for keypress
	jmp 0FFFFh:0                ; jump to beginning of BIOS to reboot


;
; Disk routines
;

;
; Converts an LBA(Logical Block Adress) address 
; to a CHS(Cylinder Head Sector) address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
lba_to_chs:
	push ax
	push dx

	xor dx, dx
	div word [bdb_sectors_per_track]	; ax = LBA / SectorsPerTrack
										; dx = LBA % SectorsPerTrack

	inc dx								; dx = sector number = Lba % SectorsPerTrack + 1
	mov cx, dx							;

	xor dx, dx
	div word [bdb_heads]				; ax = (LBA / SectorsPerTrack) / heads = cylinder
										; dx = (LBA / SectorsPerTrack) % heads = head
	mov dh, dl							; dh = head

; CX =	     ---CH--- ---CL---
; cylinder = 76543210 98------
; sector =   -------- --543210

	mov ch, al							; ch = cylinder (lower 8 bits)
	shl ah, 6							;
	or cl, ah							; cl = higher 2 bits

	pop ax
	mov dl, al							; restore
	pop ax
	ret

;
; Reads sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
;
; We will cal int 13, with these parameters:
; 	- ah: 02
; 	- al: number of sectors to read
; 	- ch: cylinder number
; 	- cl: sector number
; 	- dh: head number
; 	- dl: drive number
; 	- es:bx: pointer to buffer
; which has these returns:
	; - ah: status
	; - al: number of sectors read
	; - cf: 0 (succes) or 1 (fail)
; read int 13 documentation for more information
disk_read:
	push ax                             ; save registers we will modify
	push bx
	push cx
	push dx
	push di

	push cx
	call lba_to_chs
	pop ax

	mov ah, 02h
	mov di, 3							; retry count

.retry:
	pusha								; for safety. unsure what registers the interrupt will modify
	stc									; set carry flag
	int 13h								; carry flag cleared = succes
	jnc .done							; jump if carry not set

; read failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
; all attemps are exhausted
	jmp floppy_error

.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax                             ; restore registers modified
	ret


;
; Resets disk controller
; Parameters:
;   dl: drive number
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret

msg_loading:			db 'Loading...', ENDL, 0
msg_read_failed:        db 'Read from disk failed!', ENDL, 0
msg_stage_2_not_found:   db 'stage_2.BIN file not found!', ENDL, 0
file_stage_2_bin:        db 'STAGE2  BIN'	; this must be exactly 11 characters and uppercase
stage_2_cluster:         dw 0

; DEFINES

FAT_entry_size:			 equ 32
STAGE_2_LOAD_SEGMENT     equ 0x0000
STAGE_2_LOAD_OFFSET      equ 0x500

; the bios will expect the last 2 bytes of the first section (512 bits) of memory to be 5
; it looks for this signature so that it knows it is bootable
times 510-($-$$) db 0
dw 0AA55h

buffer: