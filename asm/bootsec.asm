; NASM breakpoint
; xchg bx, bx
[bits 16]
[org 0x7c00]

; constants
%define GRAPHICAL_MODE	0x0
%define SCREEN_WIDTH 	0x28

%define BOARD_ADDRESS	0x7E00
%define BOARD_WIDTH	17
%define BOARD_HEIGHT	20
%define BOARD_SIZE	BOARD_WIDTH * BOARD_HEIGHT * 2 ; word, store 2 bytes[color, character]

jmp word 0x0000:boot

boot:
	lea ax, [BOARD_ADDRESS]
	mov fs, ax
	
	; init text mode
	; bitmaps fonts are too large! we must use stock text mode
	mov al, GRAPHICAL_MODE
	mov ah, 0x0
	int 0x10
	
	; hide cursor
	mov ch, 0x20
	mov ah, 0x1
 	int 0x10
	
	call _set_render_dest

	; graphic - 0xA000
	; text - 0xB800
	lea ax, [title]
	push ax
	push 0x6 ; count
	push 0x2 ; color
	push 0x11 ; position x
	push 0x1 ; position y
	call _draw_string

	; game methods
	call alloc_board
	call draw_board
	
	; loop
	jmp $

; set es video memory
_set_render_dest:
	mov ax, 0xB800	
	mov es, ax
	ret

; alloc board somewhere in RAM
; storing this in code costs 200B
; fill border with characters

%define BORDER_WORD	0x0F2B
%define BACKGROUND_WORD	0x022E

alloc_board:
	push bp
	mov bp, sp
	
	; clear memory with zeros
	mov cx, BOARD_SIZE
	xor si, si
	xor bx, bx
	.alloc_byte:
		; left border
		mov ax, si
		mov bx, BOARD_WIDTH
		xor dx, dx
		div bx
		cmp dx, 0x0
		je .border
		
		; right border
		mov ax, BOARD_WIDTH
		imul ax, 0x2
		sub ax, cx
		mov bx, BOARD_WIDTH
		xor dx, dx
		div bx
		cmp dx, 0x0
		je .border

		cmp si, 33
		je .border

		; bottom border
		cmp si, %[BOARD_SIZE / 2 - BOARD_WIDTH]
		jg .border

		jmp .background

		.border: 
			mov ax, BORDER_WORD
			jmp .fill
		.background:
			mov ax, BACKGROUND_WORD
			jmp .fill
		.fill:
			; fill memory
			mov bx, si
			imul bx, 0x2 ; 2 byte width
			mov [fs:bx], ax

			inc si
			loop alloc_board.alloc_byte

 	mov sp, bp
  	pop bp
	ret

; draw game board
%define BOARD_POS	0x79
		
draw_board:
	; total characters count
	mov cx, %[BOARD_SIZE / 2]

	; screen pos
	mov bx, %[BOARD_POS * 2]

	; byte number
	xor si, si
	.loop:	
		cmp si, 0x0
		je print

		push bx
		mov ax, si
		mov bx, BOARD_WIDTH	
		xor dx, dx	
		div bx
		cmp dx, 0x0
		pop bx
		jnz print

		add bx, %[SCREEN_WIDTH * 2]
		sub bx, %[BOARD_WIDTH * 2]

		print:
			push si
				imul si, 0x2
				mov byte al, [fs:si]
				mov byte dl, [fs:si + 1]
			pop si

			call _draw_character
			; xchg bx, bx
			add bx, 0x2
			inc si
			loop draw_board.loop
	ret

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
	imul ax, SCREEN_WIDTH ; 40 characters width
	add ax, [bp + 6]
	imul ax, 2
	mov bx, ax

	; character color
	mov dx, [bp + 8]

	._draw_character:
		lodsb
		call _draw_character
		add bx, 0x2
		loop ._draw_character

 	mov sp, bp
  	pop bp
	ret 0xA

; print character
; bx - offset
; al - character
; dl - color
_draw_character:
	mov byte [es:bx], al
	mov byte [es:bx + 1], dl	
	ret

; custom variables
title: db 'TETRIS'

times 510 - ($-$$) db 0
dw 0xAA55
