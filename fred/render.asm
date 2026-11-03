; Renderer equivalente a 6391h: 22 filas x 24 tiles, x=1..24, y=8..183.
; Hueco FF de la ROM Spectrum, separado del PSG (386E..38B2) y fuente 3D00.
        org 03900h
fast_render:
        ld hl,(0638Fh)
        ld bc,4021h
        ld a,22
        ld (rows_left),a
        ld a,58h
        ld (attribute_page+1),a
render_row:
render_tile:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ; Los tres bits altos del descriptor son el color; los otros 13
        ; seleccionan ocho bytes desde 9400h, con la misma aritmetica modular.
        ld a,d
        rlca
        rlca
        rlca
        and 7
        or 40h
attribute_page:
        ld h,58h
        ld l,c
        ld (hl),a
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,9400h
        add hl,de
        ld d,b
        ld e,c
        rept 8
        ld a,(hl)
        ld (de),a
        inc hl
        inc d
        endm
        pop hl
        inc bc
        ld a,c
        and 1Fh
        cp 25
        jr nz,render_tile
        ld de,16              ; 64 bytes por fila de mapa, 48 usados
        add hl,de
        ld a,c
        add a,8
        ld c,a
        jr nc,render_next
        ld a,b
        add a,8
        ld b,a
        ld a,(attribute_page+1)
        inc a
        ld (attribute_page+1),a
render_next:
        ld a,(rows_left)
        dec a
        ld (rows_left),a
        jr nz,render_row
        ret
rows_left: db 0
render_end:
