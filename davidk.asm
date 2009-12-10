        .DOSSEG
;MEMORY RESERVATION
;DB Reserves space in one Byte (1 byte) units.  
;DW Reserves space in one Word (2 byte) units.  
;DD Reserves space in one Double (4 byte) units.  
;DQ Reserves space in one Quad (8 byte) units.  
;DT Reserves space in one Ten (10 byte) units.  
DGROUP  GROUP   _DATA, STACK
STACK   SEGMENT PARA STACK 'STACK'
        DB      256 DUP (?)
STACK   ENDS
_DATA   SEGMENT PARA PUBLIC 'DATA'
screen  DD      0a0000000h
	
;circle 
;00001110000
;00110001100
;01000000010
;10000000001
;10000000001
;10000000001
;01000000010
;00110001100
;00001110000

;screen  DD      0a0007D00h ; halfway down screen
;screen  DD      0a0007D6Ah ; line in middle
;buffer	 DW					; dedicate a WORD for our buffer?
oldmode DB      ?
_DATA   ENDS
_TEXT   SEGMENT PARA PUBLIC 'CODE'
        ASSUME  cs:_TEXT, ds:DGROUP, ss:DGROUP
start:
        mov     ax, DGROUP
        mov     ds, ax
        mov     ah, 0fh     ;get video mode 
        int     10h
        mov		oldmode, al ;save it as the 'old mode'
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
        les		di, screen      ;les - (reg16, mem32). loads mem32 into reg16 and the ES register
		;call	draw_line_horiz
		;call	draw_line_vert
		;mov		di, 319			;top right corner
		;call	draw_line_vert
		;mov		di, 0
		;call	draw_line_vert
		;mov		di, 63680		;bottom left corner
		;call	draw_line_horiz
		;call	animate_ball
		mov		di, 32160		;center of screen
		;mov		di, 32000		;center of screen
		call	draw_box
		jmp		done

;EXAMPLE GAME LOOP
;const int FRAMES_PER_SECOND = 25;
;const int SKIP_TICKS = 1000 / FRAMES_PER_SECOND;
;
;DWORD next_game_tick = GetTickCount(); 
;// GetTickCount() returns the current number of milliseconds
;// that have elapsed since the system was started
;
;int sleep_time = 0;
;
;bool game_is_running = true;
;
;while( game_is_running ) {
;	update_game();
;	display_game();
;
;	next_game_tick += SKIP_TICKS;
;	sleep_time      = next_game_tick - GetTickCount();
;	if( sleep_time >= 0 ) {
;		Sleep( sleep_time );
;	}
;	else {
;		// Shit, we are running behind!
;	}
;}

;******************************
;Drawing Functions
;******************************
draw_line_horiz:		;draws a line, left to right, the width of the screen
        mov     cx, 320			;screen width
        ;les		di, screen      ;les - (reg16, mem32). loads mem32 into reg16 and the ES register
hloop:      ;this loop is decrementing CX for us for free!
        mov     es:[di], 02h    ;move an 02hex into wherever offset of di points
        inc		di
        loop    hloop           ;loops while decrementing CX for us
		ret
draw_line_vert:			;draws a line, top to bottom, the height of the screen
        mov     cx, 200			;screen length
        ;les		di, screen      ;les - (reg16, mem32). loads mem32 into reg16 and the ES register
vloop:      ;this loop is decrementing CX for us for free!
        mov     es:[di], 02h    ;move an 02hex into wherever offset of di points
        ;inc		di
		add		di, 320
        loop    vloop           ;loops while decrementing CX for us
		ret
draw_borders:	;draws the borders around the edge of the screen
dloop:      ;this loop is decrementing CX for us for free!
        mov     es:[di], 02h    ;move an 02hex into wherever offset of di points
        inc		di
        loop    dloop           ;loops while decrementing CX for us
		ret
draw_box:	;draws the borders around the edge of the screen
		push	dx				;store this for safekeeping
		sub		di, 1605				;slide it back to the start of the line, 5 lines up (5 + 1605)
        mov     cx, 121			;11 x 11
		jmp		bloop
bloop:      ;this loop is decrementing CX for us for free!
        mov     es:[di], 02h    ;move an 02hex into wherever offset of di points
        inc		di
		mov		ax, cx			
		dec		ax				;decrement by one to adjust timing
		mov		dl, 11			;prep for div
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
		ret						;we're done
draw_circle:	;draws a bitmap, centered at the point passed in ax
;later, replace this with bitmap draw
		call	find_topleft
		call	draw_box
		;call	circle1
		;call	circ_newline
		;call	circle2
		;call	circ_newline
		;call	circle3
		;call	circ_newline
		;call	circle4
		;call	circ_newline
		;call	circle4
		;call	circ_newline
		;call	circle4
		;call	circ_newline
		;call	circle3
		;call	circ_newline
		;call	circle2
		;call	circ_newline
		;call	circle1
		;first -5 to shift left
		;then -(5 * 320)=1600 to shift up
		ret
circ_newline:
		;remove 11 to move back to first position
		;add 320 to move to next line
		add		di, 309
		;add		di, 320
		ret
circle1:
        ;mov     cx, 11			;line length
		
        mov     es:[di], 0000    ;move an 02hex into wherever offset of di points
        mov     es:[di + 2], 0000    ;move an 02hex into wherever offset of di points
        mov     es:[di + 4], 0000    ;move an 02hex into wherever offset of di points
        mov     es:[di + 6], 0000    ;move an 02hex into wherever offset of di points
        mov     es:[di + 8], 0000    ;move an 02hex into wherever offset of di points
        mov     es:[di + 10], 0000    ;move an 02hex into wherever offset of di points
		ret
circle2:
        mov     es:[di], 0022h    ;move an 02hex into wherever offset of di points
        mov     es:[di + 4], 0002h    ;move an 02hex into wherever offset of di points
        mov     es:[di + 8], 2000h    ;move an 02hex into wherever offset of di points
		ret
circle3:
        mov     es:[di], 0200h    ;move an 02hex into wherever offset of di points
        mov     es:[di + 4], 0000h    ;move an 02hex into wherever offset of di points
        mov     es:[di + 8], 0200h    ;move an 02hex into wherever offset of di points
		ret
circle4:
        mov     es:[di], 2000h    ;move an 02hex into wherever offset of di points
        mov     es:[di + 4], 0000h    ;move an 02hex into wherever offset of di points
        mov     es:[di + 8], 0200h    ;move an 02hex into wherever offset of di points
		ret
;circle 
;00001110000
;00110001100
;01000000010
;10000000001
;10000000001
;10000000001
;01000000010
;00110001100
;00001110000
;******************************
;UTILITY FUNCTIONS
;******************************

find_topleft: 
		sub		di, 1605	;find top left, based on center point
		ret
;******************************
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