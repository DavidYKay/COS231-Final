.DOSSEG

; Huge array example for MS-DOS
; Data is declared statically; every 10000th element is loaded into dl

    .model huge
    .stack

huge_data1 segment para public 'fardata'  ; segment size is 64K
    huge_array1 db  65535 dup( 1 )        ; can't dup 65536 elements
                db  1     dup( 1 )        ;   since max word is 65535
huge_data1 ends

huge_data2 segment para public 'fardata'
    huge_array2 db  34464 dup( 2 )        ; remainder of 100000 bytes
huge_data2 ends

    .code

Start:
    mov ax, huge_data1
    mov es, ax
    mov bx, offset huge_array1        ; start at element 1
    mov cx, 10                        ; do this 10 times
    sub dx, dx
again:
    mov dl, es:[bx]           ; es:[bx] is the array element
    add bx, 10000             ; skip 10000 elements
    jnc testcx                ; test for wrap of offset
    mov ax, es                ; add 4096 to seg if offset wrapped
    add ax, 4096
    mov es, ax
testcx:
    loop again

    mov ax, 4c00h             ; terminate program
    int 21h


        END     start
