        .DOSSEG
DGROUP  GROUP   _DATA, STACK
STACK   SEGMENT PARA STACK 'STACK'
        DB      256 DUP (?)
STACK   ENDS
_DATA   SEGMENT PARA PUBLIC 'DATA'
screen  DD      0a0000000h
;screen  DD      0a0007D00h ; halfway down screen
;screen  DD      0a0007D6Ah ; line in middle
oldmode DB      ?
_DATA   ENDS
_TEXT   SEGMENT PARA PUBLIC 'CODE'

start:

    mov ax, 13h ; AH=0 (Change video mode), AL=13h (Mode)
    int 10h ; Video BIOS interrupt

    ;OK. We have the mode switched. Lets put a single pixel on the screen:

    mov ax, 0A000h ; The offset to video memory
    mov es, ax ; We load it to ES through AX, becouse immediate operation is not allowed on ES
    mov ax, 0 ; 0 will put it in top left corner. To put it in top right corner load with 320, in the middle of the screen 32010.
    ;mov ax, 32010 ; 0 will put it in top left corner. To put it in top right corner load with 320, in the middle of the screen 32010.
    ;mov ax, 0FFh ; 0 will put it in top left corner. To put it in top right corner load with 320, in the middle of the screen 32010.
    mov di, ax ; load Destination Index register with ax value (the coords to put the pixel)
    mov dl, 7 ; Grey color.
    mov es:[di], dl ; And we put the pixel

;putpixel:
;;Before calling it we set ax with Y coord, bx with X and dl with the color.
;    mov cx,320
;    mul cx; multiply AX by 320 (cx value)
;    add ax,bx ; and add X
;    mov di,ax
;    mov es:[di],dl
;    ret


_TEXT   ENDS            ;// program ends
        END     start
