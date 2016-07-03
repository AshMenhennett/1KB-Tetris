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
	call draw_brick

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
%define BACKGROUND_WORD	0x082E

alloc_board:
	; clear memory with zeros
	mov cx, BOARD_SIZE
	xor si, si
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
		
		; move to next line if bx % BOARD_WIDTH == 0
		push bx
		mov ax, si
		mov bx, BOARD_WIDTH	
		xor dx, dx	
		div bx
		cmp dx, 0x0
		pop bx

		jnz print
		add bx, %[(SCREEN_WIDTH - BOARD_WIDTH) * 2]

		print:
			push si
				imul si, 0x2
				mov byte al, [fs:si]
				mov byte dl, [fs:si + 1]
			pop si

			call _draw_character

			; increment line
			add bx, 0x2
			inc si
			loop draw_board.loop
	ret

; draw single brick
draw_brick:
	push bp
	mov bp, sp

	; template: bp - 0x2
	sub sp, 0x2

	; get brick row index
	lea bx, [bricks]
	mov ax, [brick_index]
	imul ax, 0x8
	add bx, ax
	
	; get brick rotation template
	mov si, [brick_rot]
	imul si, 0x2
	mov ax, [ds:bx + si]
	mov [bp - 0x2], ax

	; move brick template bits to right side
	; shr ax, 0x10

	; get brick position relative to board
	; todo: remove movzx, push - replace it with single mnemonic
	mov bx, [brick_pos]
	movzx dx, bl
	push dx
	movzx dx, bh
	push dx
	push SCREEN_WIDTH
	call _coord_to_offset
	
	; translate to board position
	add bx, %[BOARD_POS * 2]
	
	; render brick template from ax
	; loop 16 times because word
	mov cx, 0x10
	xor si, si
	.loop:
		; write new line if 4th
		cmp si, 0x0
		jz .print

		push bx
			mov ax, si
			mov bx, 0x4
			xor dx, dx
			div bx
		pop bx
		cmp dx, 0x0

		jne .print
		add bx, %[(SCREEN_WIDTH - 0x4) * 2]
		.print:
			; extract bits
			mov ax, [bp - 0x2]
			shr ax, 0x1
			mov [bp - 0x2], ax
			and ax, 0x1
			jz .continue

			; character
			push si
				; word size is 2B, video memory has word pixels format
				imul si, 0x2

				; empty character
				mov byte [es:bx + si], '#'

				; background color
				mov dl, [brick_col]
				mov byte [es:bx + si + 1], dl
			pop si
		.continue:
			inc si
			loop .loop
	
 	mov sp, bp
  	pop bp
	ret

; change coordinate to offset
; arg1 - position x
; arg2 - position y
; arg3 - width of array(not height)
; return bx
_coord_to_offset:
	push bp
	mov bp, sp
	
 	; calc start position in mem
	push ax
	mov ax, [bp + 6]	; position y
	imul ax,  [bp + 4] 	; 40 characters width
	add ax, [bp + 8]        ; position x
	imul ax, 2		; mul offset
	mov bx, ax
	pop ax

 	mov sp, bp
  	pop bp
	ret 0x6

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
	push word [bp + 6]
	push word [bp + 4]
	push SCREEN_WIDTH
	call _coord_to_offset

	; character color
	mov dx, [bp + 8]

	.loop:
		lodsb
		call _draw_character
		add bx, 0x2
		loop .loop

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
title:	db 'TETRIS'

; bricks
; 1110 0010 1000 1100
; 0010 0110 1110 1000
; 0000 0000 0000 1000
; 0000 0000 0000 0000

; 1. 1110001000000000 = 0xE200
; 2. 0010011000000000 = 0x2600
; 3. 1000111000000000 = 0x8E00
; 4. 0000100010001100 = 0xC880
bricks:
	; L
	dw 0x2E0, 0x620, 0xE80, 0x88C

; gameplay variables
brick_index: 	dw 0x0		; 0 - 4
brick_rot: 	dw 0x0		; 0 - 4
brick_pos:	dw 0x0205	; x: 03 y: 00
brick_col:	db 0x9
	
times 510 - ($-$$) db 0
dw 0xAA55
