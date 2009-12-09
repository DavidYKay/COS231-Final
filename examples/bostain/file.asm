	.DOSSEG
DGROUP	GROUP	_DATA, STACK
STACK	SEGMENT	PARA STACK 'STACK'
	DB	256 DUP (?)
STACK	ENDS
_DATA	SEGMENT	PARA PUBLIC 'DATA'
fhandle	DW	?
fn	DB	"pocket.dic", 0     ; indicates we're zero-terminating our name, instead of '$'-terminating
emsg	DB	"I/O error", 13, 10, "$"
buf	DB	33 DUP (?)
_DATA	ENDS
_TEXT	SEGMENT	PARA PUBLIC 'CODE'
	ASSUME	cs:_TEXT, ds:DGROUP, ss:DGROUP
start:
	mov	ax, DGROUP
	mov	ds, ax
	mov	ax, 3d00h
	mov	dx, OFFSET fn
	int	21h
	jc	error
	mov	fhandle, ax
rloop:
	mov	ax, 3f00h
	mov	bx, fhandle
	mov	cx, 32
	mov	dx, OFFSET buf
	int	21h
	jc	error
	cmp	ax, 0
	jz	eof
	mov	si, ax
	mov	byte ptr buf[si], '$' ; indexed direct instruction. 
                              ; verify it worked using -d ds:18 1 21
	mov	ah, 09h
	mov	dx, OFFSET buf
	int	21h
	jmp	rloop
eof:
	mov	ax, 3e00h
	mov	dx, OFFSET fn
	int	21h
	jmp	done
error:
	mov	ah, 09h
	mov	dx, OFFSET emsg
	int	21h
done:
	mov	ax, 4C00h
	int	21h
_TEXT	ENDS
	END	start
