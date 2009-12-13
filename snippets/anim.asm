		.DOSSEG

;MEMORY RESERVATION
;DB Reserves space in one Byte (1 byte) units.  
;DW Reserves space in one Word (2 byte) units.  
;DD Reserves space in one Double (4 byte) units.  
;DQ Reserves space in one Quad (8 byte) units.  
;DT Reserves space in one Ten (10 byte) units.  
DGROUP  GROUP   _DATA, STACK
BGROUP  GROUP   _BUFF1, _BUFF2
STACK   SEGMENT PARA STACK 'STACK'
        DB      256 DUP (?) ;DUP for duplicate, ie 'fill the space with the following'
STACK   ENDS
_DATA   SEGMENT PARA PUBLIC 'DATA'
screen  DD      0a0000000h
;deltx   DW      0000h
;delty   DW      0000h
oldmode DB      ?  
_DATA   ENDS
_BUFF1	SEGMENT PARA PUBLIC 'BUFF1'
buffer1	DB		64000 DUP (?) ; dedicate 64000 bytes for our buffer
_BUFF1  ENDS
_BUFF2	SEGMENT PARA PUBLIC 'BUFF2'
buffer2	DB		64000 DUP (?) ; dedicate 64000 bytes for our buffer
_BUFF2  ENDS
_TEXT   SEGMENT PARA PUBLIC 'CODE'
        ASSUME  cs:_TEXT, ds:DGROUP, ss:DGROUP
start:
        mov     ax, DGROUP
        mov     ds, ax
		call	clear_background
		jmp		done

clear_background:			;move all zeroes into the background
		mov		es, screen
		mov		di, 0
		mov		cx, SCREEN_SIZE
cloop:
        mov     es:[di], 0    ;move an 02hex into wherever offset of di points
		inc		di
		loop cloop
		ret
done:
        mov     ah, 08h         ;after loop
        int     21h             ;interrupt DOS, 'wait for keypress'
        mov     ah, 00h
        mov     al, oldmode
        int     10h
        mov     ax, 4c00h
        int     21h     ; waiting for key
_TEXT   ENDS            ; program ends
        END     start
