include davidk.inc
		.DOSSEG

;Ball struct, representing a bouncing ball
BALL			struct	;6 bytes in size
	Xpos	        DW 160
	Ypos	        DW 100 ;consider making this a byte?
	deltaX          DB 0
	deltaY			DB 0
	colliding       DB 0
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
numballs DW     ?  ;number of balls in the array. A word since we'll be using it in CX
EOrigSegment  DW      ?  
EGroupSegment DW      ?  
DGroupSegment DW      ?  

fn	DB	"balls.txt", 0     ; indicates we're zero-terminating our name, instead of '$'-terminating
fhandle	DW	?
emsg	DB	"I/O Error.", 13, 10, "$"
buffer2	DB		512 DUP (03) ; dedicate 64000 bytes for our buffer
tempBall DB     8 DUP (?)    ; temporary ball

_DATA   ENDS
EGROUP  GROUP   _BUFF1, _BALLS
_BUFF1	SEGMENT PARA PUBLIC 'BUFF1'
;buffer1	DB		64000 DUP (?) ; dedicate 64000 bytes for our buffer
buffer1	DB		64000 DUP (03) ; dedicate 64000 bytes for our buffer
_BUFF1  ENDS

_BALLS	SEGMENT PARA PUBLIC 'BALLS'
balls	DB		256 DUP (07) ; 
_BALLS  ENDS

_TEXT   SEGMENT PARA PUBLIC 'CODE'
        ASSUME  cs:_TEXT, ds:DGROUP, ss:DGROUP, es:EGROUP
start:
        mov     ax, DGROUP					;set Dsegment to the DGROUP
        mov     ds, ax
		mov		DGroupSegment, ax
		mov		ax, es

		mov		EOrigSegment, ax			;backup the original segment
        mov     ax, EGROUP
        mov     es, ax
		mov		EGroupSegment, ax			;store the EGROUp segment

		call	parse_input
		
		call	save_oldmode				;save initial video mode
		call	set_mode13h					;set to 256-color 320x200

		mov		ax, _BUFF1
		mov		es, ax						;set ES to buffer1 segment
		mov		di, offset buffer1			; start at element 1

		call	clear_buffer				;clear out the text from the buffer 
		call	clear_screen

		call	init_ball
		call	animate_ball				;this will loop until forever
		jmp		done
;******************************
;VGA Mode Subroutines
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
;Animation Subroutines
;******************************
init_balls_from_input:				;subroutine to initialize all balls from input
		xor		di, di				;byte counter
start_readinput:
		mov		tempBall, 0			;zero out tempball
		xor		dx, dx				;DL - 10^x counter DH - stack counter
		xor		bx, bx				;BX - running total
		xor		si, si				;Tempball ring counter, marks which bytes to write to 
readloop:			;read parameters from buffer
		mov		al, buffer2[di]
		cmp		al, 20h				;Is character a space?
		je		end_number
		cmp     al, 0Dh				;is character a carriage return?
		je		next_line
		cmp     al, 0Ah 			;is character a newline?
		je		next_line
		cmp		al, "$"				;$ signifies end of input
		je		done_init

		mov		ah, al				;back up AL in AH
		call	check_character		;IS character an ascii number?
		cmp		al, 1
		je		digit_found			;found!
		jmp		next_char			;unrecognized character. keep going.
digit_found:		;store the digit on the stack
		mov		al, ah
		sub		al, 30h				;remove 30hex to get an actual number
		cbw
		push	ax					;store the number on the stack
		inc		dh					;dh counts how many items we have on the stack
		jmp		next_char
end_number:			;found a whole number. convert it from base 10 and store it 
		xor		dl, dl				;use BL as a 10^x counter
base10loop:			;use BH as a counter of items on the stack
		pop		ax 
		mul		dl					;multiply it by the appropriate base
		add		bx, ax				;running total

		inc		dl					;next power of ten
		dec		dh
		cmp		dh, 0				;out of items?
		jne		base10loop
		call	store_in_tempball	;store the finished product in tempball
		;fall into next_char
next_char:
		inc		di					;next byte
		jmp		readloop
next_line:		;next line, so let's try to init a ball from what we have
ball_found:
		call	init_ball_from_temp
		add		di, BALL_BYTES		;slide to next ball bucket
		inc		cx
		jmp		start_readinput
done_init:		
		ret

store_in_tempball: ;stores a number in the proper position in tempball
		mov		word ptr tempBall[si], bx
		inc		si
		cmp		si, 7				;have we run over 7?
		jg		reset_counter
		cmp		si,	1				;are we in no man's land?
		je		extra_bump
		cmp		si,	3				;are we in no man's land?
		je		extra_bump
tempball_done:
		ret
extra_bump:
		inc		si
		jmp		tempball_done
reset_counter:
		xor		si, si
		jmp		tempball_done

init_ball_from_temp:		;make sure that di points to the right offset
		push	di
		mov		di, es:OFFSET balls
		ASSUME	di:PTR BALL
		;ASSUME  tempBall:PTR BALL
		mov 	ax,	word ptr tempBall[0]
		mov 	es:[di].Xpos,		ax
		mov 	ax,	word ptr tempBall[2]
		mov 	es:[di].Ypos,   	ax
		mov 	al,	byte ptr tempBall[4]
		mov 	es:[di].deltaX, 	al
		mov 	al,	byte ptr tempBall[5]
		mov 	es:[di].deltaY, 	al
		mov 	al,	byte ptr tempBall[6]
		mov		es:[di].colliding,  al
		mov 	al,	byte ptr tempBall[7]
		mov 	es:[di].color,  	al
		ASSUME	di:nothing
		inc		numballs			;mark down how many we've found
		pop		di
		ret
init_ball:		;subroutine to initialize one ball to bounce around
		push	di
		mov		di, es:OFFSET balls
		ASSUME	di:PTR BALL
		mov		es:[di].colliding, 0
		mov 	es:[di].Xpos, 160
		mov 	es:[di].Ypos, 100
		mov 	es:[di].deltaX, 1
		mov 	es:[di].deltaY, 1
		mov 	es:[di].color,  5
		add		di, BALL_BYTES		;slide to next ball
		mov		es:[di].colliding, 0
		mov 	es:[di].Xpos, 80
		mov 	es:[di].Ypos, 80
		mov 	es:[di].deltaX, -1
		mov 	es:[di].deltaY, 1
		mov 	es:[di].color,  4
		add		di, BALL_BYTES		;slide to next ball
		mov		es:[di].colliding, 0
		mov 	es:[di].Xpos, 250
		mov 	es:[di].Ypos, 180
		mov 	es:[di].deltaX, -1
		mov 	es:[di].deltaY, -1
		mov 	es:[di].color,  4
		ASSUME	di:nothing
		pop		di
		mov		numballs, 3
		ret
animate_ball:
		;mov		cx, 16000			;screen width
		;mov     	cx, 1600			;screen width
		;mov     	cx, 640			;screen width
		;les		di, buffer1
		;mov		ax, OFFSET buffer1
		;mov		es, ax
		;xor		di, di

		;mov		ax, EGroupSegment
		;mov		es, ax
mainloop:
		mov		cx, numballs			;init our ball counter
		mov		ax, 0					;load offset of ball in ax
		jmp		each_ball
next_ball:
		mov		ax, si					;restore offset from register
		add		ax, BALL_BYTES			;increment to next ball
each_ball:
		call	detect_collision
		call	move_ball				;move ball and handle collision
		mov		si, ax					;hold on to our offset
		call	get_ball_color			;put color in bl
		call	get_ball_pixel			;put current pixel offset in AX
		mov		di, ax					;point to the right pixel
		call	draw_circle
		loop    next_ball			    ;else, loop to next round of animation
		call	write_to_screen
		call	clear_buffer
		;call	delay_second
		;call	check_key				;check for user input
		jmp	mainloop				;loop forever
		;jmp		each_ball				;loop forever
		ret
;******************************
;Physics Subroutines
;******************************
detect_collision:			;subroutine to detect a collision and correct the deltaX/deltaY
		;PARAMETERS: AX: ball's offset in array
		push	di
		push	ax
		push	bx
		mov		di, es:OFFSET balls
		add		di, ax
		ASSUME	di:PTR BALL
		mov		ax, es:[di].Ypos 	;lookup y pos
		mov		bx, es:[di].Xpos	;lookup x pos
		cmp		ax, 5
		jle		y_collision
		cmp		ax, 195
		jge		y_collision
		cmp		bx, 5
		jle		x_collision
		cmp		bx, 315
		jge		x_collision
		jmp		done_collision		;no collisions found
x_collision:				;if X is < 5 or > 315
		neg		es:[di].deltaX
		call	increment_ball_color;
		jmp		done_collision
y_collision:				;if Y is < 5 or > 195
		neg		es:[di].deltaY
		call	increment_ball_color;
done_collision:
		ASSUME	di:nothing
		pop		bx
		pop		ax
		pop		di
		ret
get_xy_coord: 
;parameters: AX: ball's offset in array
;return:     BX: x-coord AX:y-coord
;presumes es points to EGroupSegment
		push	di
		mov		di, es:OFFSET balls
		add		di, ax
		ASSUME	di:PTR BALL
		mov		bx, es:[di].Xpos	;lookup current x
		mov		ax, es:[di].Ypos	;lookup current y
		ASSUME	di:nothing
		pop		di
		ret
move_ball: ;adjusts ball's position based on deltaX, deltaY
;parameters: AX: ball's offset in array
		push	di
		push	ax
		mov		di, es:OFFSET balls
		add		di, ax
		ASSUME	di:PTR BALL
		mov		al, es:[di].deltaX	;lookup delta x
		cbw
		add		es:[di].Xpos, ax
		mov		al, es:[di].deltaY 	;lookup delta y
		cbw
		add		es:[di].Ypos, ax		
		pop		ax
		pop		di
		ASSUME	di:nothing
		ret
get_ball_pixel: ;returns the ball's pixel positioning based on coordinates
;INPUT: AX: Ball displacement in array
		call	get_xy_coord
		call	get_delta_pixel
		ret
get_delta_pixel: ;returns the ball's pixel displacement based on coordinates
				;INPUT: BX:X-coord AX:Y-coord
				;RETURN: AX: pixel displacement
		push	dx
		mov		dx, 320
		mul		dx					;multiply deltY by 320

		add		ax, bx				;deltaPixel = X-coord + Y-coord * 320
		pop		dx
		ret
get_ball_color:
;parameters: AX:ball offset in array
;returns: DL: Ball color
		push	di
		mov		di, es:OFFSET balls
		add		di, ax
		ASSUME	di:PTR BALL
		mov		dl, es:[di].color	;lookup current color
		ASSUME	di:nothing
		pop		di
		ret
increment_ball_color:
		mov		al, es:[di].color 	
		add		al, 8				;change color by 8, which is not an even factor of 255
		cmp		al, 0				;make sure we don't match the background color
		mov		es:[di].color, al
		ret
;******************************
;Drawing subroutines
;******************************
draw_pixels:
		push	cx
		cbw							;only draw 1/100ths of second
		mov		cx, ax
		les		di, screen
pix_loop:
		mov		es:[di], 1 ;draw to buffer
		add		di, 10
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
		push	ds
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
		pop		ds
		pop		cx
		pop		di
		ret
draw_circle: ;draws a circle using its offset? using its color?
;LINE 1;00001110000
;LINE 2;00110001100
;LINE 3;01000000010
;LINE 3;01000000010
;LINE 4;10000000001
;LINE 4;10000000001
;LINE 4;10000000001
;LINE 3;01000000010
;LINE 3;01000000010
;LINE 2;00110001100
;LINE 1;00001110000
		push	di				;store this for safekeeping
		sub		di, 1606		;draw from the top left (11 + 11*320)
		call	draw_circ1
		call	circ_newline
		call	draw_circ2
		call	circ_newline
		call	draw_circ3
		call	circ_newline
		call	draw_circ3
		call	circ_newline
		call	draw_circ4
		call	circ_newline
		call	draw_circ4
		call	circ_newline
		call	draw_circ4
		call	circ_newline
		call	draw_circ3
		call	circ_newline
		call	draw_circ3
		call	circ_newline
		call	draw_circ2
		call	circ_newline
		call	draw_circ1
		pop		di
		ret
draw_circ1: ;LINE 1;00001110000
		add		di, 4
		mov		es:[di],   dl	;TODO: COLOR HERE
		mov		es:[di+1], dl	;TODO: COLOR HERE
		mov		es:[di+2], dl	;TODO: COLOR HERE
		add		di, 6
		ret
draw_circ2: ;LINE 2;00110001100
		add		di, 2
		mov		es:[di],   dl	;TODO: COLOR HERE
		mov		es:[di+1], dl	;TODO: COLOR HERE
		add		di, 5
		mov		es:[di],   dl	;TODO: COLOR HERE
		mov		es:[di+1], dl	;TODO: COLOR HERE
		add		di, 3
		ret
draw_circ3: ;LINE 3;01000000010
		add		di, 1
		mov		es:[di], dl	;TODO: COLOR HERE
		add		di, 8
		mov		es:[di], dl	;TODO: COLOR HERE
		add		di, 1
		ret
draw_circ4: ;LINE 4;10000000001
		mov		es:[di], dl	;TODO: COLOR HERE
		add		di, 10
		mov		es:[di], dl	;TODO: COLOR HERE
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
		;add		di, 309 		;remove 11 to move back to first position
		add		di, 310 		;remove 10 to move back to first position
		ret
;******************************
;I/O Subroutines
;******************************
parse_input:
	
	;fetch the command line parameters
	call	open_file				;based on the parameters, open a file
	call	read_file 				;from the file, read the data into the buffer
	call	init_balls_from_input	;from the buffer, read the parameters and init the balls
	ret
	;jmp		done
	;"balls.txt"
open_file:
	mov		ax, 3d00h				;interrupt id 3Dh
	mov		dx, OFFSET fn			;-filename, zero-terminated
	int		21h						;Open File
	jc		error					;error!
	mov		fhandle, ax				;store our filehandle in memory
	ret
read_file:
	mov		ax, 3f00h				;interrupt id 3fh
	mov		bx, fhandle				;moves block of memory
	mov		cx, 512					;read 128 bytes
	mov		dx, OFFSET buffer2      ;OFFSET - moves runtime address of buf into dx
	int		21h						;Read from file, leaving contents in buffer2
	jc		error
	mov		si, ax
	mov		byte ptr buffer2[si], '$'; place a '$' after the end of input, so we know it's the end
	;cmp		ax, 0					;number of bytes read
	jmp		eof

	;mov		si, ax
	;mov		byte ptr buffer2[si], '$'; indexed direct instruction. 
	;mov		ah, 09h					; verify it worked using -d ds:18 1 21
	;mov		dx, OFFSET buffer2
	;int		21h						;write to terminal
	;jmp		read_file
eof:
	mov		ax, 3e00h
	mov		dx, OFFSET fn
	int		21h						;close file
	ret
error:
	mov		ah, 09h
	mov		dx, OFFSET emsg
	int		21h						;write to terminal
	jmp		done
;******************************
;Timing/Delay Subroutines
;******************************
get_time:
	push	cx
	push	dx
;Get System Time			21h		2Ch
;	RETURN:
;	CH = hour CL = minute DH = second DL = 1/100 seconds
;   Function actually returns DX values in AH/AL at the moment
	mov     ah, 2Ch     ;
	;mov     al, 00h     ;
	int     21h
	;mov		ax, cx
	mov		ax, dx		;move to accumulator for output

	pop		dx
	pop		cx
	ret
delay_test:		;test the delay method by delaying then drawing some stuff on the screen
	call	get_time
	call	draw_pixels
	call	circ_newline
	ret
delay_frame:		;subroutine to delay until the next frame
	push	dx ;dx - backup of ax, holding newtime
	push	bx ;bl - total bh - lastTime	
	xor		bx, bx	
	call	get_time
	mov		bh, ah				;store our first "lastTime"
frame_loop:
	call	get_time
	mov		dx, ax
	sub		ah, bh				;newtime - oldTime
	add		bl, ah  			;add new delta to total
	cmp		bl, 3   			;has total hit 3 seconds?
	jge		frame_done
	mov		bh, dh				;mark newTime as lastTime
	jmp		frame_loop			;keep looping
frame_done:
	pop		bx
	pop		dx				
	ret
delay_second:		;subroutine to delay until the next second
	push	dx ;dx - backup of ax, holding newtime
	push	bx ;bl - holds Total ;bh - holds oldTime
	xor		bx, bx				;used for counting delta time(ch) and oldtime (cl)
	call	get_time
	mov		bh, al
del_loop:
	call	get_time
	mov		dx, ax				;in case we need it again
del_sub:			
	sub		al, bh				;delta = newtime - oldtime
	cmp		al, 0
	jl		del_zero			;we overflowed
	add		bl, al				;add new delta to running total
	mov		bh, dl				;store newTime in oldTime
	cmp		bl, 01				;has it been 3/100 seconds?
	jge		del_fin
	jmp		del_loop
del_fin:
	pop		bx
	pop		dx
	ret
del_zero:
	mov		ax, dx				;If negative, add 100 to newtime and repeat
	add		al, 100
	jmp del_sub
;******************************
;Misc Subroutines
;******************************
check_key:
	mov     ah, 06h         ;
	int     21h             ;interrupt DOS, 'direct console input'
	jz		done
	ret
check_character:	;checks the input byte (in AL) and replaces it with a code indicating its type
	and		al, 0F0h					;ignore the right nibble
	xor 	al, 030h					;xor with 30 hex to check left nibble
	cmp 	al, 0						;should be all zeroes if it was ASCII number
	je		ascii_byte
misc_byte:					;if none of the above
	mov		al, 0						;return 4
	jmp char_done
ascii_byte:		  				  		;if ASCII number
	mov		al, 1 						;return 2
char_done:
	ret
;******************************
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
