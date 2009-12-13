		.DOSSEG
;MEMORY RESERVATION
;DB Reserves space in one Byte (1 byte) units.  
;DW Reserves space in one Word (2 byte) units.  
;DD Reserves space in one Double (4 byte) units.  
;DQ Reserves space in one Quad (8 byte) units.  
;DT Reserves space in one Ten (10 byte) units.  
DGROUP  GROUP   _DATA, STACK
STACK   SEGMENT PARA STACK 'STACK'
        DB      256 DUP (?) ;DUP for duplicate, ie 'fill the space with the following'
STACK   ENDS
_DATA   SEGMENT PARA PUBLIC 'DATA'
emsg	DB	"Memory error", 13, 10, "$"
amsg	DB	"Memory allocation success", 13, 10, "$"
bmsg	DB	"Memory release success", 13, 10, "$"
;screen  DD      0a0000000h
;deltx   DW      0000h
;delty   DW      0000h
;screen  DD      0a0007D00h ; halfway down screen
;screen  DD      0a0007D6Ah ; line in middle
_DATA   ENDS
_TEXT   SEGMENT PARA PUBLIC 'CODE'
        ASSUME  cs:_TEXT, ds:DGROUP, ss:DGROUP
start:
        mov     ax, DGROUP
        mov     ds, ax
		call	allocate_buffer
		call	deallocate_buffer
		jmp		done
allocate_buffer: ;uses DOS int 21, 48h to allocate memory
		push	bx
		;mov		bx, 4000	;BX: number of paragraphs to allocate
		mov		bx, 200	;BX: number of paragraphs to allocate
		mov		ah, 48h
        int     21h			;DOS allocate memory interrupt
		jc		error ;check for error
		pop		bx
		ret
deallocate_buffer:
		push	bx
		mov		es,	ax		;segment of block to free
		mov		ah, 49h
        int     21h			;DOS allocate memory interrupt
		jc		error ;check for error
		pop		bx
		ret
success1:
	mov	ah, 09h
	mov	dx, OFFSET amsg
	int	21h						;write to terminal
success2:
	mov	ah, 09h
	mov	dx, OFFSET bmsg
	int	21h						;write to terminal
error:
	mov	ah, 09h
	mov	dx, OFFSET emsg
	int	21h						;write to terminal
done:
	mov	ax, 4C00h
	int	21h						;end program

_TEXT   ENDS            ; program ends
        END     start
