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
        ;mov     cx, 64000      ;screen size
        mov     cx, 32000       ;screen size
        ;mov     cx, 0FA00      ; to F9FF
        ;mov     cx, 555        ;screen size
        ;mov     cx, 0140       ;screen size
        ;mov     cx, 6A         ; line length
        les		di, screen      ;les - (reg16, mem32). loads mem32 into reg16 and the ES register
sloop:      ;this loop is decrementing CX for us for free!
        mov     es:[di], 02h    ;move an 02hex into wherever offset of di points
        inc		di
        loop    sloop           ;loops while decrementing CX for us
        mov     ah, 08h         ;after loop
        int     21h             ;interrupt DOS, 'wait for keypress'
        mov     ah, 00h
        mov     al, oldmode
        int     10h
        mov     ax, 4c00h
        int     21h     ; waiting for key
_TEXT   ENDS            ; program ends
        END     start
