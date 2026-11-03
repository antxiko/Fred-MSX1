; Sustituto del BEEPER de la ROM Spectrum. Se coloca en el hueco 386E-3CFF.
; HL conserva el periodo Spectrum y DE el numero de ciclos del sonido.
; El BEEPER original en 03B8 mantiene la duracion y los efectos de registro.
PSGA equ 0A0h
PSGD equ 0A1h
        org 0386Eh
sound_beeper:
        push af
        push bc
        push de
        push hl
        ; Periodo AY aproximado: (HL+30)*0.256, redondeado a HL/4+8.
        srl h
        rr l
        srl h
        rr l
        ld de,8
        add hl,de
        ld a,0
        out (PSGA),a
        ld a,l
        out (PSGD),a
        ld a,1
        out (PSGA),a
        ld a,h
        and 0Fh
        out (PSGD),a
        ld a,7
        out (PSGA),a
        ld a,03Eh             ; solo tono del canal A
        out (PSGD),a
        ld a,8
        out (PSGA),a
        ld a,0Ch
        out (PSGD),a
        pop hl
        pop de
        pop bc
        pop af
        di
        ld a,l                ; tres bytes originales sustituidos por JP
        srl l
        call 03B9h            ; continua en el segundo SRL L original
        push af
        ld a,8
        out (PSGA),a
        xor a
        out (PSGD),a
        pop af
        ret
