; Effects from the per-game-frame sequencer are timed by VBlank interrupts.
; Menu/transition tunes continue through the original blocking adapter.
async_beeper:
        push af
        ld a,(game_active)
        or a
        jr nz,effect_start
        pop af
        jp 0386Eh
effect_start:
        push bc
        push de
        push hl
        di
        xor a
        ld (sound_ticks),a
        push hl
        srl h
        rr l
        srl h
        rr l
        ld bc,8
        add hl,bc
        xor a
        out (0A0h),a
        ld a,l
        out (0A1h),a
        ld a,1
        out (0A0h),a
        ld a,h
        and 15
        out (0A1h),a
        pop hl
        ; Duration in 50 Hz ticks: (HL+30)*DE / 8750, rounded upwards.
        ld bc,30
        add hl,bc
        ld b,h
        ld c,l
        ld hl,0
        ld a,16
effect_multiply:
        add hl,hl
        rl e
        rl d
        jr nc,effect_no_add
        add hl,bc
        jr nc,effect_no_add
        inc de
effect_no_add:
        dec a
        jr nz,effect_multiply
        ld a,1
effect_divide:
        push af
        ld bc,8750
        or a
        sbc hl,bc
        ld bc,0
        ex de,hl
        sbc hl,bc
        ex de,hl
        jr c,effect_duration_ready
        pop af
        inc a
        jr nz,effect_divide
        ld a,255
        jr effect_schedule
effect_duration_ready:
        pop af
effect_schedule:
        ld (sound_ticks),a
        ld a,7
        out (0A0h),a
        ld a,03Eh
        out (0A1h),a
        ld a,8
        out (0A0h),a
        ld a,12
        out (0A1h),a
        pop hl
        pop de
        pop bc
        pop af
        ei
        ret
sound_tick:
        ld a,(sound_ticks)
        or a
        ret z
        dec a
        ld (sound_ticks),a
        ret nz
        ld a,8
        out (0A0h),a
        xor a
        out (0A1h),a
        ret
sound_ticks: db 0
