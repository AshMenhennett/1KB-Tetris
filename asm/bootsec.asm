; NASM breakpoint
; xchg bx, bx
[bits 16]
[org 0x7c00]

jmp word 0x0000:boot

boot:
	; init text mode
	; bitmaps fonts are too large! we must use stock text mode
	mov al, 0x3
	mov ah, 0x0
	int 0x10
	
	; hide cursor
	mov ch, 0x20
	mov ah, 0x1
 	int 0x10

	; graphic - 0xA000
	; text - 0xB800
	lea ax, [title]
	push ax
	push 0x6 ; count
	push 0x2 ; color
	push 0x25 ; position x
	push 0x0 ; position y
	call _draw_string
	
	jmp $

; print string
; arg1 - string address
; arg2 - character count
; arg3 - character color
; arg4 - position x
; arg5 - position y
_draw_string:
	push bp
	mov bp, sp
	
	; string address
	mov si, [bp + 12]

	; character count
	mov cx, [bp + 10]
	
 	; calc start position in mem
	mov ax, [bp + 4]
	imul ax, 0x50 ; 80 characters width
	add ax, [bp + 6]
	imul ax, 2
	mov bx, ax

	; character color
	mov dx, [bp + 8]

	; move to video memory
	mov ax, 0xB800	
	mov es, ax
	._draw_character:
		lodsb
		mov byte [es:bx], al
		mov byte [es:bx + 1], dl	
		add bx, 0x2
		loop ._draw_character

 	mov esp, ebp
  	pop ebp
	ret

title: db 'TETRIS'

times 510 - ($-$$) db 0
dw 0xAA55
