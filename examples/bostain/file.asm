	.DOSSEG
DGROUP	GROUP	_DATA, STACK
STACK	SEGMENT	PARA STACK 'STACK'
	DB	256 DUP (?)				;question mark indicates zeroes or don't cares. not sure.
STACK	ENDS
_DATA	SEGMENT	PARA PUBLIC 'DATA'
fhandle	DW	?
fn	DB	"pocket.dic", 0     ; indicates we're zero-terminating our name, instead of '$'-terminating
emsg	DB	"I/O error", 13, 10, "$"
buf	DB	33 DUP (?)				;DUPlicate - meaning fill with the following, in this case, a zero
_DATA	ENDS
_TEXT	SEGMENT	PARA PUBLIC 'CODE'
	ASSUME	cs:_TEXT, ds:DGROUP, ss:DGROUP
start:
	mov	ax, DGROUP				;Address to beginning of DGROUP
	mov	ds, ax					;Set data segment there
	mov	ax, 3d00h				;interrupt id 3Dh
	mov	dx, OFFSET fn			;-filename, zero-terminated
	int	21h						;Open File
	jc	error
	mov	fhandle, ax		;store our filehandle in memory
rloop:
	mov	ax, 3f00h				;interrupt id 3fh
	mov	bx, fhandle				;moves block of memory
	mov	cx, 32					;read 32 bytes
	mov	dx, OFFSET buf          ;OFFSET - moves runtime address of buf into dx
	int	21h						;Read from file
	jc	error
	cmp	ax, 0					;number of bytes read
	jz	eof
	mov	si, ax
	mov	byte ptr buf[si], '$' ; indexed direct instruction. 
                              ; verify it worked using -d ds:18 1 21
	mov	ah, 09h
	mov	dx, OFFSET buf
	int	21h						;write to terminal
	jmp	rloop
eof:
	mov	ax, 3e00h
	mov	dx, OFFSET fn
	int	21h						;close file
	jmp	done
error:
	mov	ah, 09h
	mov	dx, OFFSET emsg
	int	21h						;write to terminal
done:
	mov	ax, 4C00h
	int	21h						;end program
_TEXT	ENDS
	END	start
