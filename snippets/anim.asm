include ..\davidk.inc
		.DOSSEG
;MEMORY RESERVATION
;DB Reserves space in one Byte (1 byte) units.  
;DW Reserves space in one Word (2 byte) units.  
;DD Reserves space in one Double (4 byte) units.  
;DQ Reserves space in one Quad (8 byte) units.  
;DT Reserves space in one Ten (10 byte) units.  
DGROUP  GROUP   _DATA, STACK, _BUFF1
;BGROUP  GROUP   _BUFF1, _BUFF2
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
		call	save_oldmode
		call	set_mode13h
		;call	animate_ball
		call	draw_pixel
		jmp		done
;******************************
;VGA Mode Functions
;******************************
save_oldmode:
        mov     ah, 0fh     ;get video mode 
        int     10h
        mov		oldmode, al ;save it as the 'old mode'
		ret
set_mode13h:
        mov     ah, 00h     ;videomode interrupt
        mov     al, 13h     ;set new mode to 00h
        int     10h
        mov     ah, 06h     ;"scroll up window"
        mov     al, 00h     ;erases the background (can wipe screen)
        int     10h
        mov     dx, 03c6h   
        mov     al, 0ffh  
        out     dx, al      ;'thump the register', same as o3c6 ff
        mov     dx, 03c8h
        mov     al, 05h
        out     dx, al      ;register 2
        mov     dx, 01c9h
        mov     al, 3fh
        out     dx, al      ;register 3
        mov     al, 30h
        out     dx, al
        mov     al, 3fh
        out     dx, al
		ret
;******************************
;Animation Functions
;******************************
animate_ball:
	mov     cx, 320			;pixels to animate
	;mov     cx, 32000			;screen width
	;les		di, buffer1
	mov		ax, OFFSET buffer1
	mov		es, ax
	xor		di, di
animbloop:
	inc		di
	call	draw_box
	;call	delay_frame
	call	write_to_screen
	loop    animbloop           ;loops while decrementing CX for us
	ret
delay_frame:		;subroutine to delay until the next frame
	push	dx ;dx - backup of ax, holding newtime
	push	bx ;bh - holds deltaTotal ;bl - holds oldTime
	xor		bx, bx				;used for counting delta time(ch) and oldtime (cl)
del_loop:
	call	get_time
	mov		dx, ax				;in case we need it again
	;mov	bx, ax				;in case we need it again
del_sub:			
	sub		al, bl				;delta = newtime - oldtime
	cmp		al, 0
	jl		del_zero			;we overflowed
	add		bh, al				;add new delta to running delta total
	mov		bl, dl				;store newTime in oldTime
	;check - is deltatime greater than our threshold?
	;cmp		bh, 50				;FRAME_THRESHOLD (30ms)
	cmp		bh, FRAME_THRESHOLD				;FRAME_THRESHOLD (30ms)
	;cmp		bh, 10				;FRAME_THRESHOLD (30ms)
	;cmp		bh, 0FFFFh				;FRAME_THRESHOLD (30ms)
	jge		del_fin
	jmp		del_loop
del_fin:
	pop		bx
	pop		dx
	ret
del_zero:
	;mov		al, dl				;If negative, add 100 to newtime and repeat
	mov		ax, dx				;If negative, add 100 to newtime and repeat
	add		al, 100
	jmp del_sub

;******************************
;Drawing functions
;******************************
draw_pixel:
		les		di, screen
		mov		es:[di + 100],1 ;draw to buffer
		mov		es:[di + 200],1 ;draw to buffer
		mov		es:[di + 300],1 ;draw to buffer
		call	write_to_screen
		ret

clear_buffer:			;move all zeroes into the background
		;les		di, buffer1
		;mov		ax, OFFSET buffer1
		;mov		es, ax
		xor		di, di
		mov		cx, SCREEN_SIZE
cloop:
        ;mov     es:[di], 0    ;move an 02hex into wherever offset of di points
        mov byte ptr buffer1[di], 0    ;move an 02hex into wherever offset of di points
		inc		di
		loop cloop
		ret
write_to_screen:			;move all zeroes into the background
		;Use ES:DI and DS:SI to copy from one and write to the other
		;lds		si, buffer1
		;mov		ax, OFFSET buffer1
		;mov		ds, ax						;set DS to buffer1 address
		xor		si, si						;si=0
		les		di, screen 
		mov		cx, SCREEN_SIZE
wloop:
		mov		ax, word ptr buffer1[si]
        mov     es:[di], ax					;copy byte from buffer to screen
        ;mov byte ptr es:[di], buffer1[si]    ;copy byte from buffer to screen
        ;mov     word ptr es:[di], ds:[si]    ;copy byte from buffer to screen
		inc		di
		inc		si
		loop cloop
		ret

draw_box:	
		push	cx				;store this for safekeeping
		push	dx				;store this for safekeeping
		push	di				;store this for safekeeping
		sub		di, 1605		;slide it back to the start of the line, 5 lines up (5 + 1605)
        mov     cx, 121			;11 x 11
		jmp		bloop
bloop:      ;this loop is decrementing CX for us for free!
        mov     es:[di], 02h    ;move an 02hex into wherever offset of di points
        inc		di
		mov		ax, cx			
		dec		ax				;decrement by one to adjust timing
		mov		dl, 11		
		div		dl				;check if we've finished one line
		cmp		ah, 0
		je		aloop			;time for new line
        loop    bloop           ;loop on this current line
		jmp		done_box
aloop:      
		call	circ_newline	;bump us down by one line
		loop	bloop
done_box:
		pop		di
		pop		dx
		pop		cx
		ret						;we're done

circ_newline:
		;remove 11 to move back to first position
		;add 320 to move to next line
		add		di, 309
		;add		di, 320
		ret
;******************************
;Utility Functions
;******************************
get_time:
		push	cx
		push	dx
;Get System Time			21h		2Ch
;	RETURN:
;	CH = hour CL = minute DH = second DL = 1/100 seconds
;   Function actually returns values in AH/AL at the moment
        mov     ah, 2Ch     ;
        mov     al, 00h     ;
        int     21h
		mov		ax, dx		;move to accumulator for output
		pop		dx
		pop		cx
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
