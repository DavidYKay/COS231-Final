include ..\davidk.inc
		.DOSSEG

;Ball struct, representing a bouncing ball
BALL			struct	;6 bytes in size
	colliding       DB 0
	Xpos	        DB 160
	Ypos	        DB 100
	deltaX          DB 0
	deltaY			DB 0
	color	        DB 0
BALL			ends

;MEMORY RESERVATION
;DB Reserves space in one Byte	 (1 byte) units.  
;DW Reserves space in one Word 	 (2 byte) units.  
;DD Reserves space in one Double (4 byte) units.  
;DQ Reserves space in one Quad   (8 byte) units.  
;DT Reserves space in one Ten   (10 byte) units.  
DGROUP  GROUP   _DATA, STACK
STACK   SEGMENT PARA STACK 'STACK'
        DB      256 DUP (?) ;DUP for duplicate, ie 'fill the space with the following'
STACK   ENDS
_DATA   SEGMENT PARA PUBLIC 'DATA'
screen  DD      0a0000000h
oldmode DB      ?  
EOrigSegment  DW      ?  
EGroupSegment DW      ?  
DGroupSegment DW      ?  
_DATA   ENDS
EGROUP  GROUP   _BUFF1, _BALLS
_BUFF1	SEGMENT PARA PUBLIC 'BUFF1'
;buffer1	DB		64000 DUP (?) ; dedicate 64000 bytes for our buffer
buffer1	DB		64000 DUP (03) ; dedicate 64000 bytes for our buffer
_BUFF1  ENDS
_BALLS	SEGMENT PARA PUBLIC 'BALLS'
balls	DB		256 DUP (?) ; 
_BALLS  ENDS

_TEXT   SEGMENT PARA PUBLIC 'CODE'
        ASSUME  cs:_TEXT, ds:DGROUP, ss:DGROUP, es:EGROUP
start:
        mov     ax, DGROUP
        mov     ds, ax
		mov		DGroupSegment, ax
		mov		ax, es
		mov		EOrigSegment, ax			;backup the original segment
        mov     ax, EGROUP
        mov     es, ax
		mov		EGroupSegment, ax			;store the EGROUp segment

		call	save_oldmode				;save initial video mode
		call	set_mode13h					;set to 256-color 320x200

		mov		ax, _BUFF1
		mov		es, ax						;set ES to buffer1 segment
		mov		di, offset buffer1			; start at element 1
		;mov		di, 32500
		mov		di, 1700

		;call	clear_buffer
		;call	clear_screen
		;call	animate_box
		
		call	init_ball
		call	get_ball_pixel
		;call	animate_ball
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
animate_box:
		mov     cx, 16000			;screen width
		;les		di, buffer1
		;mov		ax, OFFSET buffer1
		;mov		es, ax
		;xor		di, di
animboxloop:
		call	draw_box
		;call	delay_frame
		;call	delay_second
		call	write_to_screen
		call	clear_buffer
		;call	clear_screen
		inc		di
		loop    animboxloop           ;loops while decrementing CX for us
		ret
init_ball:		;subroutine to initialize one ball to bounce around
		push	di
		ASSUME	di:PTR BALL
		mov		di, OFFSET balls
		mov		es:[di].colliding, 0
		mov 	es:[di].Xpos, 160
		mov 	es:[di].Ypos, 100
		mov 	es:[di].deltaX, 10
		mov 	es:[di].deltaY, 0
		mov 	es:[di].color, 1
		ASSUME	di:nothing
		pop		di
		ret
animate_ball:
		mov     cx, 1600			;screen width
		;les		di, buffer1
		;mov		ax, OFFSET buffer1
		;mov		es, ax
		;xor		di, di

		;mov		ax, EGroupSegment
		;mov		es, ax
animballloop:
		call	move_ball				;move ball and handle collision
		call	get_ball_pixel			;get current DI based on x,y
		;mov		di, ax					;point to the right pixel
		;call	draw_box
		;;call	draw_ball
		;call	write_to_screen
		;call	clear_buffer
		;;call	clear_screen

		;;call	delay_frame
		loop    animballloop           ;loops while decrementing CX for us
		ret
get_xy_coord: 
;parameters: AX: offset
;return AH: x-coord AL:y-coord
;presumes es points to EGroupSegment
		push	bx
		mov		ax, bx
		ASSUME	ax:PTR BALL
		mov		ah, es:[bx].deltaX	;lookup delta x
		mov		al, es:[bx].deltaY	;lookup delta y
		ASSUME	ax:nothing
		pop		bx
		ret
move_ball: ;adjusts ball's position based on deltaX, deltaY
		;presumes es points to EGroupSegment
		;push	es
		;mov		EGroupSegment, ax
		;mov		es, ax
		push	di
		ASSUME	di:PTR BALL
		mov		di, OFFSET balls
		mov		al, es:[di].deltaX	;lookup delta x
		add		es:[di].Xpos, al
		mov		al, es:[di].deltaY 	;lookup delta y
		add		es:[di].Ypos,	al		
		pop		di
		ASSUME	di:nothing
		;pop		es
		ret
get_ball_pixel: ;returns the ball's pixel positioning based on coordinates
		call	get_xy_coord
		call	get_delta_pixel
		ret
get_delta_pixel: ;returns the ball's pixel displacement based on coordinates
				;INPUT: AH:X-coord AL:Y-coord
				;RETURN: AX: pixel displacement
		push	bx
		push	dx
		mov		bx, ax				;BH: X BL: Y

		mov		dx, 320
		cbw							;Y-coord to 16 bits
		mul		dx					;multiply deltY by 320
		mov		dx, ax				;store low-order result in dx

		mov		al, bh				;convert delta-X to 16bit
		cbw

		add		dx, ax				;deltaPixel = X-coord + Y-coord * 320
		pop		dx
		pop		bx
		ret
;get_coordinate_change: ;returns the change in ball's pixel placement based on deltaX, deltaY
;		push	es
;		push	bx
;		push	dx
;		xor		bx, bx				;we'll hold our temp value in here
;
;		mov		EGroupSegment, ax
;		mov		es, ax
;		mov		al, balls.deltaX	;lookup delta x
;		add		bx, al
;		mov		al, balls.deltaY 	;lookup delta y
;
;		pop		dx
;		pop		bx
;		pop		es
;		ret
;******************************
;Drawing subroutines
;******************************
draw_pixels:
		push	cx
		cbw		
		mov		cx, ax
		les		di, screen
pix_loop:
		mov		es:[di], 1 ;draw to buffer
		add		di, 100
		loop	pix_loop
		;call	write_to_screen
		pop		cx
		ret
clear_screen:
		push	es
		les		di, screen
		jmp		clear_main
clear_buffer:			;move all zeroes into the background
		push	es
		mov		ax, _BUFF1
		mov		es, ax
		;mov		ax, OFFSET buffer1
		;mov		ax, es
clear_main:
		push	di
		push	cx
		xor		di, di
		mov		cx, SCREEN_SIZE
cloop:
        ;mov     es:[di], 0    ;move an 02hex into wherever offset of di points
        mov byte ptr es:[di], 3    ;move an 02hex into wherever offset of di points
		inc		di
		loop cloop
		pop		cx
		pop		di
		pop		es
		ret
write_to_screen:			;move all zeroes into the background
		push	di
		push	cx
		push	bx
		mov		bx, ds
		;Use ES:DI and DS:SI to copy from one and write to the other
		;mov		ax, _BUFF1
		;mov		es, ax						;set ES to buffer1 segment
		;mov		di, OFFSET buffer1			; start at element 1
		xor		di, di						;di=0
		
		;les		di, screen 
		lds		si, screen					;point ds:[si] to vga
		mov		cx, SCREEN_SIZE				;loop thru each pixel
wloop:
		;mov		al, byte ptr buffer1[di]	;fetch
		mov		al, byte ptr es:[di]	;fetch
        ;mov     es:[di], al					;copy byte from buffer to screen
        ;mov     es:[di], 02h					;copy byte from buffer to screen
        ;mov     ds:[si], 02h					;copy byte from buffer to screen
        mov     ds:[si], al					;copy byte from buffer to screen
		inc		di
		inc		si
		loop	wloop
		mov		ds, bx
		pop		bx
		pop		cx
		pop		di
		ret
draw_box:	
		;parameters: DI - center of box
		;ES - start of draw buffer
		push	cx				;store this for safekeeping
		push	di				;store this for safekeeping
		push	dx				;store this for safekeeping
		sub		di, 1605		;slide it back to the start of the line, 5 lines up (5 + 1600)
        mov     cx, 121			;11 x 11
bloop:      ;this loop is decrementing CX for us for free!
        mov     es:[di], 04h    ;move an 02hex into wherever offset of di points
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
		pop		dx
		pop		di
		pop		cx
		ret						;we're done

circ_newline:					;add 320 to move to next line
		add		di, 309 		;remove 11 to move back to first position
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
        ;mov     al, 00h     ;
        int     21h
		mov		ax, dx		;move to accumulator for output
		pop		dx
		pop		cx
		ret
delay_test:		;test the delay method by delaying then drawing some stuff on the screen
	call	get_time
	call	draw_pixels
	call	circ_newline
	ret
delay_second:		;subroutine to delay until the next frame
	push	dx ;dx - backup of ax, holding newtime
	push	bx ;bl - holds deltaTotal ;bh - holds oldTime
	xor		bx, bx				;used for counting delta time(ch) and oldtime (cl)
del_loop:
	call	get_time
	mov		dx, ax				;in case we need it again
del_sub:			
	sub		ah, bh				;delta = newtime - oldtime
	cmp		ah, 0
	jl		del_zero			;we overflowed
	add		bl, ah				;add new delta to running delta total
	mov		bh, dh				;store newTime in oldTime
	cmp		bl, 3				;has it been 3 seconds?
	jge		del_fin
	jmp		del_loop
del_fin:
	pop		bx
	pop		dx
	ret
del_zero:
	mov		ax, dx				;If negative, add 100 to newtime and repeat
	add		al, 60
	jmp del_sub
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
