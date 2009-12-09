	.DOSSEG
DGROUP	GROUP	_DATA, STACK
STACK	SEGMENT	PARA STACK 'STACK'
	DB	256 DUP (?)
STACK	ENDS
_DATA	SEGMENT	PARA PUBLIC 'DATA'
msg	DB	"Spam Musubi!", 13, 10, '$'
_DATA	ENDS
_TEXT	SEGMENT	PARA PUBLIC 'CODE'
	ASSUME	cs:_TEXT, ds:DGROUP, ss:DGROUP
start:
	mov	ax, DGROUP  
	mov	ds, ax      ;
	mov	ah, 9h      ; what is this? location of data segment?
	mov	dx, OFFSET msg ; load address(offset?) of msg into dx
	int	21h         ; fire interrupt, which draws "hello world"
	mov	ax, 4C00h   ; exit program code
	int	21h
_TEXT	ENDS
	END	start

