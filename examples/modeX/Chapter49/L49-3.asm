; Mode X (320x240, 256 colors) display memory to display memory copy
; routine. Left edge of source rectangle modulo 4 must equal left edge
; of destination rectangle modulo 4. Works on all VGAs. Uses approach
; of reading 4 pixels at a time from the source into the latches, then
; writing the latches to the destination. Copies up to but not
; including the column at SourceEndX and the row at SourceEndY. No
; clipping is performed. Results are not guaranteed if the source and
; destination overlap.
; Tested with TASM 4.0 by Jim Mischel 12/16/94.
; C near-callable as:
;
;    void CopyScreenToScreenX(int SourceStartX, int SourceStartY,
;       int SourceEndX, int SourceEndY, int DestStartX,
;       int DestStartY, unsigned int SourcePageBase,
;       unsigned int DestPageBase, int SourceBitmapWidth,
;       int DestBitmapWidth);

SC_INDEX equ    03c4h   ;Sequence Controller Index register port
MAP_MASK equ    02h     ;index in SC of Map Mask register
GC_INDEX equ    03ceh   ;Graphics Controller Index register port
BIT_MASK equ    08h     ;index in GC of Bit Mask register
SCREEN_SEG equ  0a000h  ;segment of display memory in Mode X

parms   struc
        dw      2 dup (?) ;pushed BP and return address
SourceStartX dw ?       ;X coordinate of upper left corner of source
SourceStartY dw ?       ;Y coordinate of upper left corner of source
SourceEndX   dw ?       ;X coordinate of lower right corner of source
                        ; (the row at SourceEndX is not copied)
SourceEndY   dw ?       ;Y coordinate of lower right corner of source
                        ; (the column at SourceEndY is not copied)
DestStartX   dw ?       ;X coordinate of upper left corner of dest
DestStartY   dw ?       ;Y coordinate of upper left corner of dest
SourcePageBase dw ?     ;base offset in display memory of page in
                        ; which source resides
DestPageBase dw ?       ;base offset in display memory of page in
                        ; which dest resides
SourceBitmapWidth dw ?  ;# of pixels across source bitmap
                        ; (must be a multiple of 4)
DestBitmapWidth   dw ?  ;# of pixels across dest bitmap
                        ; (must be a multiple of 4)
parms   ends

SourceNextScanOffset equ -2   	;local storage for distance from end of
                              	; one source scan line to start of next
DestNextScanOffset   equ -4	;local storage for distance from end of
                              	; one dest scan line to start of next
RectAddrWidth 	    equ -6	;local storage for address width of rectangle
Height   	    equ -8	;local storage for height of rectangle
STACK_FRAME_SIZE     equ  8

        .model  small
        .data
; Plane masks for clipping left and right edges of rectangle.
LeftClipPlaneMask       db      00fh,00eh,00ch,008h
RightClipPlaneMask      db      00fh,001h,003h,007h
        .code
        public  _CopyScreenToScreenX
_CopyScreenToScreenX proc    near
        push    bp      			;preserve caller's stack frame
        mov     bp,sp   			;point to local stack frame
        sub     sp,STACK_FRAME_SIZE 	;allocate space for local vars
        push    si      			;preserve caller's register variables
        push    di
        push    ds

        cld
        mov     dx,GC_INDEX     		;set the bit mask to select all bits
        mov     ax,00000h+BIT_MASK 	; from the latches and none from
        out     dx,ax           		; the CPU, so that we can write the
	                        		; latch contents directly to memory
        mov     ax,SCREEN_SEG   		;point ES to display memory
        mov     es,ax
        mov     ax,[bp+DestBitmapWidth]
        shr     ax,1            		;convert to width in addresses
        shr     ax,1
        mul     [bp+DestStartY] 		;top dest rect scan line
        mov     di,[bp+DestStartX]
        shr     di,1    			;X/4 = offset of first dest rect pixel in
        shr     di,1    			; scan line
        add     di,ax   			;offset of first dest rect pixel in page
        add     di,[bp+DestPageBase] 	;offset of first dest rect pixel
                        			; in display memory
        mov     ax,[bp+SourceBitmapWidth]
        shr     ax,1            		;convert to width in addresses
        shr     ax,1
        mul     [bp+SourceStartY]		;top source rect scan line
        mov     si,[bp+SourceStartX]
        mov     bx,si
        shr     si,1    			;X/4 = offset of first source rect pixel in
        shr     si,1    			; scan line
        add     si,ax   			;offset of first source rect pixel in page
        add     si,[bp+SourcePageBase] 	;offset of first source rect
                        			; pixel in display memory
        and     bx,0003h                 	;look up left edge plane mask
        mov     ah,LeftClipPlaneMask[bx] 	; to clip
        mov     bx,[bp+SourceEndX]
        and     bx,0003h                  ;look up right edge plane
        mov     al,RightClipPlaneMask[bx] ; mask to clip
        mov     bx,ax            		;put the masks in BX
        
        mov     cx,[bp+SourceEndX]   	;calculate # of addresses across
        mov     ax,[bp+SourceStartX] 	; rect
        cmp     cx,ax
        jle     CopyDone        		;skip if 0 or negative width
        dec     cx
        and     ax,not 011b
        sub     cx,ax
        shr     cx,1
        shr     cx,1    			;# of addresses across rectangle to copy - 1
        jnz     MasksSet 		;there's more than one address to draw
        and     bh,bl   			;there's only one address, so combine the left
                        			; and right edge clip masks
MasksSet:
        mov     ax,[bp+SourceEndY]
        sub     ax,[bp+SourceStartY]  	;AX = height of rectangle
        jle     CopyDone        		;skip if 0 or negative height
        mov     [bp+Height],ax
        mov     ax,[bp+DestBitmapWidth]
        shr     ax,1            		;convert to width in addresses
        shr     ax,1
        sub     ax,cx   			;distance from end of one dest scan line to
        dec     ax      			; start of next
        mov     [bp+DestNextScanOffset],ax
        mov     ax,[bp+SourceBitmapWidth]
        shr     ax,1            		;convert to width in addresses
        shr     ax,1
        sub     ax,cx   			;distance from end of one source scan line to
        dec     ax      			; start of next
        mov     [bp+SourceNextScanOffset],ax
        mov     [bp+RectAddrWidth],cx 	;remember width in addresses - 1
;-----------------------BUG FIX
mov     dx,SC_INDEX
        mov     al,MAP_MASK
        out     dx,al           		;point SC Index reg to Map Mask
        inc     dx              		;point to SC Data reg
;-----------------------BUG FIX
        mov     ax,es   			;DS=ES=screen segment for MOVS
        mov     ds,ax
CopyRowsLoop:
        mov     cx,[bp+RectAddrWidth] 	;width across - 1
        mov     al,bh   			;put left-edge clip mask in AL
        out     dx,al   			;set the left-edge plane (clip) mask
        movsb           			;copy the left edge (pixels go through
                        			; latches)
        dec     cx      			;count off left edge address
        js      CopyLoopBottom 		;that's the only address
        jz      DoRightEdge 		;there are only two addresses
        mov     al,00fh 			;middle addresses are drawn 4 pixels at a pop
        out     dx,al   			;set the middle pixel mask to no clip
        rep     movsb   			;draw the middle addresses four pixels apiece
                        			; (pixels copied through latches)
DoRightEdge:
        mov     al,bl   			;put right-edge clip mask in AL
        out     dx,al   			;set the right-edge plane (clip) mask
        movsb           			;draw the right edge (pixels copied through
                        			; latches)
CopyLoopBottom:
        add     si,[bp+SourceNextScanOffset] ;point to the start of
        add     di,[bp+DestNextScanOffset]   ; next source & dest lines
        dec     word ptr [bp+Height] 	;count down scan lines
        jnz     CopyRowsLoop
CopyDone:
        mov     dx,GC_INDEX+1 		;restore the bit mask to its default,
        mov     al,0ffh         		; which selects all bits from the CPU
        out     dx,al           		; and none from the latches (the GC
                                		; Index still points to Bit Mask)
        pop     ds
        pop     di      			;restore caller's register variables
        pop     si
        mov     sp,bp   			;discard storage for local variables
        pop     bp      			;restore caller's stack frame
        ret
_CopyScreenToScreenX endp
        end

