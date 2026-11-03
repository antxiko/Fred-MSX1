; Fred MSX1: descomprime las tres paginas del snapshot.
; Se ejecuta en RAM de la pagina 0; la capa de ejecucion se copia a C000.
        include "stage_syms.inc"
        org 0
F_start: jp boot
F_RAMV: dw 0
F_CARTV: dw 0
slot_save: db 0
unpack_end: dw 0

boot:   di
        ld sp,3FF0h
        ; pagina 1 RAM, pagina 2 cartucho banco 2: 4000-7FFF
        ld a,2
        ld (7000h),a
        ld c,1
        ld de,(F_RAMV)
        call set_page
        ld c,2
        ld de,(F_CARTV)
        call set_page
        ld hl,8000h
        ld de,4000h
        ld bc,8000h
        ld (unpack_end),bc
        call unpack

        ; pagina 1 cartucho banco 3, pagina 2 RAM: 8000-BFFF
        ld c,1
        ld de,(F_CARTV)
        call set_page
        ld a,3
        ld (6000h),a
        ld c,2
        ld de,(F_RAMV)
        call set_page
        ld hl,4000h
        ld de,8000h
        ld bc,0C000h
        ld (unpack_end),bc
        call unpack

        ; pagina 1 cartucho banco 0, pagina 2 banco 2: C000-FFFF
        ld c,1
        ld de,(F_CARTV)
        call set_page
        xor a
        ld (6000h),a
        ld c,2
        ld de,(F_CARTV)
        call set_page
        ld a,2
        ld (7000h),a
        ld hl,8000h+CHUNK1_LEN
        ld de,0C000h
        ld bc,0
        ld (unpack_end),bc
        call unpack

        ld c,2
        ld de,(F_RAMV)
        call set_page
        ld hl,RUNTIME_CART
        ld de,0B900h
        ld bc,RUNTIME_LEN
        ldir
        jp 0B900h

; Token 0..127: 1..128 bytes literales. Token 128..255: 3..130 repeticiones.
unpack: ld a,(hl)
        inc hl
        bit 7,a
        jr nz,up_run
        inc a
        ld c,a
        ld b,0
        ; FFFF is the secondary-slot register on expanded machines.
        ; Never restore the snapshot's final byte over that register.
        push hl
        ld h,d
        ld l,e
        add hl,bc
        ld a,h
        or l
        pop hl
        jr nz,up_literal
        dec bc
        ld a,b
        or c
        jr z,up_last
        ldir
up_last:
        inc hl
        inc de
        jr up_check
up_literal:
        ldir
        jr up_check
up_run: and 7Fh
        add a,3
        ld b,a
        ld a,(hl)
        ld c,a
        inc hl
up_loop:
        ld a,d
        and e
        inc a
        jr z,up_skip_last
        ld a,c
        ld (de),a
up_skip_last:
        inc de
        djnz up_loop
up_check:
        push hl
        ld hl,(unpack_end)
        or a
        sbc hl,de
        pop hl
        jr nz,unpack
        ret

; C=pagina 1/2, DE=slot (D primario, E subslot o FF).
set_page:
        ld a,e
        cp 0FFh
        jr z,sp_prim
        in a,(0A8h)
        ld (slot_save),a
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
        ld a,(slot_save)
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
