	.DOSSEG
DGROUP	GROUP	_DATA, STACK
STACK	SEGMENT PARA STACK 'STACK'
	DB	100h DUP (?)
STACK	ENDS
_DATA	SEGMENT WORD PUBLIC 'DATA'
buffer	DB	100h DUP (0)
errormsg DB	"Invalid Input!", 13, 10, '$'
_DATA	ENDS
_TEXT	SEGMENT WORD PUBLIC 'CODE'
	ASSUME	cs:_TEXT, ds:DGROUP, ss:DGROUP
start:
	mov	ax, DGROUP
	mov	ds, ax
	mov	di, OFFSET buffer       ;prep DI to write to output buffer
	mov	si, 82h                 ;prep si to read CLI parameters
	mov	al, es:[80h]            ;load the first character of input into AL
	cmp	al, 0                   ;is it blank?           
	je	done                    ;if so, we're done
	dec	al		                ;else, decrement it
	cbw                         ;convert byte to word
	mov	cl, 3                   
	div	cl                      ;divide our new byte by three, al/ah now hold quotient/remainder
	sub	cx, cx                  ;subtract ax by cx, storing the result in cx
	inc	al                      ;increment once, why?
	mov	cl, al                  ;move quotient into cl
	cmp	ah, 2                   ;if we have two remainder (two exceptions to hte rule)
	je	two
	cmp	ah, 1
	je	one                     ;if we have one remainder
	dec	cx              
loop1:
    call output_and_increment
two:                            ;loop will fall through here, writing the second number
	call output_and_increment
one:                            ;loop will fall through here, writing the third number
	call output_and_increment
	cmp	cx, 1                   ;if counter hits one, we're done
	je	next
	mov	al, ','
	mov	[di], al                ;add the comma
	inc	di
	dec	cx
	jmp	loop1                   ;decrement and loop
next:
	mov	al, 10                  ;is this 10hex(DLE) or 10dec(LF)? 
	mov	[di], al
	inc	di
	mov	al, '$'
	mov	[di], al
	mov	ah, 9h
	mov	dx, OFFSET buffer
	int	21h
done:
	mov	ax, 4C00h
	int	21h
error:
	mov	ah, 9h
	mov	dx, OFFSET errormsg        ;load the error message
	int	21h                     ;show the error
    jmp done                    ;quit the program

;
;------------------------------
;UTILITY FUNCTIONS
;------------------------------
output_and_increment:
	mov	al, es:[si]             ;read the byte from input
    mov dl, al                  ;back up a copy
    call check_character        ;do we have bad input?
    cmp al, 0                   ;if we didn't have a number
    je  error                   ;abort and show error
    mov al, dl                  ;restore our copy
	mov	[di], al                ;move it to output
	inc	di
	inc	si
    ret

check_character:	;checks the input byte (in AL) and replaces it with a code indicating its type
	and		al, 0F0h					;ignore the right nibble
	xor 	al, 030h						;xor with 30 hex to check left nibble
	cmp 	al, 0						;should be all zeroes if it was ASCII number
	je		ascii_byte
misc_byte:					;if none of the above
	mov		al, 0						;return 4
	jmp char_done
ascii_byte:		  				  		;if ASCII number
	mov		al, 1 						;return 2
	jmp char_done
char_done:
	ret
_TEXT	ENDS
	END	start
