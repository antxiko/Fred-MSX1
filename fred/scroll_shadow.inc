; Reuse resolved descriptors/names for small horizontal camera steps.
; pin_front has already protected the old visible patterns.
shift_view:
        xor a
        ld (shifted),a
        ld a,(tile_mode)
        cp 2
        ret nz
        ld hl,(view_delta)
        ld a,h
        or a
        jr z,shift_positive
        inc a
        ret nz
        xor a
        sub l
        jr shift_size
shift_positive:
        ld a,l
shift_size:
        or a
        ret z
        cp 7
        ret nc
        rrca
        ret c
        ld (shift_count),a
        ld a,1
        ld (shifted),a
        ld (map_dirty),a
        xor a
        ld (bank_force),a
        ld a,(row_count)
        ld (shift_rows),a
        ld hl,(bank_shadow)
        ld a,(shadow_high)
        ld d,a
        ld a,(first_cell)
        ld e,a
shift_next_row:
        ld a,(shift_count)
        ld (shift_steps),a
shift_step:
        ld a,(view_delta+1)
        or a
        call z,shift_left
        ld a,(view_delta+1)
        or a
        call nz,shift_right
        ld a,(shift_steps)
        dec a
        ld (shift_steps),a
        jr nz,shift_step
        ld bc,48
        add hl,bc
        ex de,hl
        ld bc,32
        add hl,bc
        ex de,hl
        ld a,(shift_rows)
        dec a
        ld (shift_rows),a
        jr nz,shift_next_row
        ret
shift_left:
        push hl
        push de
        push de
        ld d,h
        ld e,l
        inc hl
        inc hl
        ld bc,46
        ldir
        ld a,0FFh
        ld (de),a
        inc de
        ld (de),a
        pop hl
        ld d,h
        ld e,l
        inc hl
        ld bc,23
        ldir
        ld a,0FFh
        ld (de),a
        pop de
        pop hl
        ret
shift_right:
        push hl
        push de
        push de
        ld bc,47
        add hl,bc
        ld d,h
        ld e,l
        dec hl
        dec hl
        ld bc,46
        lddr
        ld a,0FFh
        ld (de),a
        dec de
        ld (de),a
        pop hl
        ld bc,22
        add hl,bc
        ld d,h
        ld e,l
        inc de
        ld bc,23
        lddr
        ld a,0FFh
        ld (de),a
        pop de
        pop hl
        ret
view_delta: dw 0
shifted: db 0
shift_count: db 0
shift_steps: db 0
shift_rows: db 0
