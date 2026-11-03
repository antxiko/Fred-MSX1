vdp_regs: db 02h,0E2h,06h,0FFh,03h,36h,07h,0F1h
vdp_init:
        ld hl,vdp_regs
        ld b,8
        ld c,80h
vi1:    ld a,(hl)
        out (VDPC),a
        ld a,c
        out (VDPC),a
        inc hl
        inc c
        djnz vi1
        ld hl,0                 ; VRAM a cero
        call vaddr
        ld bc,4000h
vi2:    xor a
        out (VDPD),a
        dec bc
        ld a,b
        or c
        jr nz,vi2
        ld hl,1800h             ; tabla de nombres 0..255 x3
        call vaddr
        ld b,3
vi3:    xor a
vi4:    out (VDPD),a
        nop
        nop
        inc a
        jr nz,vi4
        djnz vi3
        ld hl,1B00h             ; sin sprites
        call vaddr
        ld a,0D0h
        out (VDPD),a
        ld hl,shadow            ; fuerza el primer volcado de color
        ld de,shadow+1
        ld bc,767
        ld (hl),0FFh
        ldir
        ret

; HL = direccion VRAM de escritura (llamar con interrupciones cerradas)
vaddr:  ld a,l
        out (VDPC),a
        ld a,h
        or 40h
        out (VDPC),a
        ret

