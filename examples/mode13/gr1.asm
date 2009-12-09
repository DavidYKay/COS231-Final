; Made by InternetNightmare <InternetNightmare_X@yahoo.com> 2004-01-16 Edit: 2004-08-30
; Grafikos Programavimas I dalis: Mode 13h
; English: Graphics Part I: Mode 13h

; For NASM or A86 compilers remove lines marked with '(TASM)'

;model small ; Small model (TASM)

;codeseg ; Code segment (TASM)

START:  ; The beginning 
mov ah,0
mov al,13h
int 10h
mov ax,0A000h
mov es,ax
mov ax,67
mov bx,112
mov cx,320
mul cx
add ax,bx
mov di,ax
mov dl,7
mov es:[di],dl
wl:             ; mark wl
mov ah,0        ; 0 - keyboard BIOS function to get keyboard scancode
int 16h         ; keyboard interrupt
jz wl           ; if 0 (no button pressed) jump to wl
mov ah,0  ; Restore
mov al,3  ; textmode
int 10h   ; for DOS
END START ; The End (TASM)
