set_page:
        ld a,e
        cp 0FFh
        jr z,sp_prim
        in a,(0A8h)
        ld (runtime_slot_save),a
        and 3Fh
        ld b,a
        ld a,d
        rrca
        rrca
        or b
        out (0A8h),a
        ld a,(0FFFFh)
        cpl
        ld b,a
        ld a,c
        dec a
        ld a,e
        jr nz,sp_two
        rlca
        rlca
        ld l,a
        ld a,b
        and 0F3h
        jr sp_write
sp_two: rlca
        rlca
        rlca
        rlca
        ld l,a
        ld a,b
        and 0CFh
sp_write:
        or l
        ld (0FFFFh),a
        ld a,(runtime_slot_save)
        out (0A8h),a
sp_prim:
        in a,(0A8h)
        ld b,a
        ld a,c
        dec a
        ld a,d
        jr nz,sp_prim2
        rlca
        rlca
        ld l,a
        ld a,b
        and 0F3h
        jr sp_out
sp_prim2:
        rlca
        rlca
        rlca
        rlca
        ld l,a
        ld a,b
        and 0CFh
sp_out: or l
        out (0A8h),a
        ret
