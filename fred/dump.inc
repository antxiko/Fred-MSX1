dump:   jp tile_present
dump_legacy:
        ld a,i
        push af
        di
        ld hl,0
        call vaddr
        pop af
        jp po,du0
        nop
du0:    ld hl,4000h
        ld c,3
du1:    ld b,0
du2:    ld a,(hl)
        out (VDPD),a
        inc h
        nop                  ; 26 T + esperas MSX entre escrituras
        ld a,(hl)
        out (VDPD),a
        inc h
        nop                  ; 26 T + esperas MSX entre escrituras
        ld a,(hl)
        out (VDPD),a
        inc h
        nop                  ; 26 T + esperas MSX entre escrituras
        ld a,(hl)
        out (VDPD),a
        inc h
        nop                  ; 26 T + esperas MSX entre escrituras
        ld a,(hl)
        out (VDPD),a
        inc h
        nop                  ; 26 T + esperas MSX entre escrituras
        ld a,(hl)
        out (VDPD),a
        inc h
        nop                  ; 26 T + esperas MSX entre escrituras
        ld a,(hl)
        out (VDPD),a
        inc h
        nop                  ; 26 T + esperas MSX entre escrituras
        ld a,(hl)
        out (VDPD),a
        ld a,h
        sub 7
        ld h,a
        inc l
        djnz du2
        ld a,h
        add a,8
        ld h,a
        dec c
        jr nz,du1
        ; color: 768 atributos contra la copia de sombra
        ld hl,5800h
        ld de,shadow
        ld bc,0
dc1:    ld a,(de)
        cp (hl)
        jr z,dc3
        ld a,(hl)
        ld (de),a
        push hl
        push de
        or 80h                 ; FLASH ignored; 128-entry palette at 3980h
        ld l,a
        ld h,attr2col/256
        ld e,(hl)               ; color MSX de este atributo
        ld h,b
        ld l,c
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        or 20h
        ld h,a                  ; 2000h + celda*8
        ld a,i
        push af
        di
        call vaddr
        pop af
        jp po,dc2
        nop
dc2:    ld a,e
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        pop de
        pop hl
dc3:    inc hl
        inc de
        inc bc
        ld a,b
        cp 3
        jr nz,dc1
        jp legacy_ready

