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
cmsg	DB	"Memory resize success", 13, 10, "$"
_DATA   ENDS
_TEXT   SEGMENT PARA PUBLIC 'CODE'
        ASSUME  cs:_TEXT, ds:DGROUP, ss:DGROUP
start:
        mov     ax, DGROUP
        mov     ds, ax
		call	resize_buffer
		call	allocate_buffer
		call	deallocate_buffer
		jmp		done
allocate_buffer: ;uses DOS int 21, 48h to allocate memory
		push	bx
		;mov		bx, 4000	;BX: number of paragraphs to allocate
		mov		bx, 7			;BX: number of paragraphs to allocate
		mov		ah, 48h
        int     21h				;DOS allocate memory interrupt
		jc		error			;check for error
		call	success1
		pop		bx
		ret
deallocate_buffer:
		push	bx
		mov		es,	ax			;segment of block to free
		mov		ah, 49h
        int     21h				;DOS allocate memory interrupt
		jc		error			;check for error
		call	success2
		pop		bx
		ret
resize_buffer:
		push	bx
		mov		es,	ax			;segment of block to free
		mov		bx, 2000		;new size in paragraphs
		mov		ah, 4Ah
        int     21h				;DOS allocate memory interrupt
		jc		error			;check for error
		call	success3
		pop		bx
		ret
success1:
		mov	dx, OFFSET amsg
		jmp print_success
success2:
		mov	dx, OFFSET bmsg
		jmp print_success
success3:
		mov	dx, OFFSET cmsg
print_success:
		push	ax
		mov	ah, 09h
		int	21h						;write to terminal
		pop		ax
		ret
error:
		mov	ah, 09h
		mov	dx, OFFSET emsg
		int	21h						;write to terminal
done:
		mov	ax, 4C00h
		int	21h						;end program
_TEXT   ENDS            ; program ends
        END     start
