; Immediate first shot, then 35 video ticks before repeat, 25 thereafter.
; Release sampling between game frames keeps quick separate presses responsive.
fire_latch: db 0
fire_delay: db 0
fire_gate:
        or a                    ; AND result of the actual redefined key
        jr nz,fire_release
        ld a,(fire_latch)
        or a
        jr nz,fire_held
        inc a
        ld (fire_latch),a
        ld a,35
        jr fire_attempt
fire_held:
        ld a,(fire_delay)
        or a
        ret nz
        ld a,25
fire_attempt:
        ld (fire_delay),a
        jp 09203h
fire_release:
        xor a
        ld (fire_latch),a
        ret

fire_poll:
        ld a,(fire_game_active)
        or a
        jr z,fire_release
        ld a,(fire_selector_saved)
        push af
        in a,(0AAh)
        push af
        ld a,(0789Eh)           ; row selected by the original redefine code
        call fire_kbd
        ld b,a
        ld a,(078A2h)           ; redefined key mask
        and b
        jr z,fire_poll_held
        call fire_release
        jr fire_poll_restore
fire_poll_held:
        ld a,(fire_delay)
        or a
        jr z,fire_poll_restore
        dec a
        ld (fire_delay),a
fire_poll_restore:
        pop af
        out (0AAh),a            ; preserve any interrupted keyboard scan
        pop af
        ld (fire_selector_saved),a
        ret
