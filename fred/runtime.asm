; Capa Fred MSX1. B900-BBE9; BC00 en adelante pertenece al juego.
; Paleta 3980-39FF, sombra compartida 3A00-3CFF, descarte 38C0-38E7.
        include "stage_symbols.inc"
        include "tile_targets.inc"
VDPD    equ 098h
VDPC    equ 099h
PPIA    equ 0A8h
PPIB    equ 0A9h
PPIC    equ 0AAh
        org 0B900h
R_start:
        di
        ld hl,(F_RAMV)
        ld (R_RAMV),hl
        ld hl,(F_CARTV)
        ld (R_CARTV),hl
        ; Restaurar los 16 KB completos de la ROM 48K en la pagina 0.
        ld c,1
        ld de,(R_CARTV)
        call set_page
        ld a,1
        ld (6000h),a
        ld hl,4000h
        ld de,0
        ld bc,4000h
        ldir
        ; RST 00h es el lector de matriz MSX; RST 08h de error ROM se conserva.
        ld a,0C3h
        ld (0000h),a
        ld hl,kbd
        ld (0001h),hl
        ld a,0C3h
        ld (0038h),a
        ld hl,isr
        ld (0039h),hl
        ld a,0C3h              ; BEEPER -> tono PSG con duracion original
        ld (03B5h),a
        ld hl,0386Eh
        ld (03B6h),hl
        ld c,1
        ld de,(R_RAMV)
        call set_page
        ld c,2
        ld de,(R_RAMV)
        call set_page
        call vdp_init
        ld iy,05C3Ah
        ld ix,06400h
        ld a,03Fh
        ld i,a
        im 1
        call 07C78h             ; teclado como control inicial
        ld sp,0DEA8h
        ei
        jp 0765Ah

R_RAMV: dw 0
R_CARTV: dw 0
runtime_slot_save: db 0
frame_count: db 0
last_key: db 0
selector_saved: db 0
game_active: db 0

title_hook:
        xor a
        ld (game_active),a
        jp tile_title

frame_hook:
        ld a,1
        ld (game_active),a
        call tracking_tick
        di
        call dump
        ei
        jp 077F1h

rebind_key:
        call wait_key_up
        call 07D6Ah
        push de
        call wait_key_up
        pop de
        ret

wait_key_up:
        xor a                   ; todas las filas del teclado Spectrum
        call kbd
        and 01Fh
        cp 01Fh
        jr nz,wait_key_up
        ret

isr:    push af
        in a,(VDPC)
        push bc
        push de
        push hl
        call sound_tick
        call fire_poll
        ld a,(game_active)
        or a
        jr nz,irq_done
        ld a,(frame_count)
        inc a
        cp 6
        jr c,irq_skip
        xor a
        ld (frame_count),a
        call dump
        jr irq_done
irq_skip:
        ld (frame_count),a
irq_done:
        pop hl
        pop de
        pop bc
        pop af
        ei
        reti

; A = selector activo bajo de las filas Spectrum.
kbd:    push bc
        push de
        push hl
        ld (selector_saved),a
        ld c,a
        ld d,0FFh
        ld hl,keymap
        ld b,8
kb_row:
        rrc c
        jr c,kb_next
        push bc
        ld e,1
        ld b,5
kb_col:
        ld a,(hl)
        cp 0FFh
        jr z,kb_col_next
        push bc
        ld b,a
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        ld c,a
        in a,(PPIC)
        and 0F0h
        or c
        out (PPIC),a
        in a,(PPIB)
        ld c,a
        ld a,b
        and 07h
        inc a
        ld b,a
        ld a,c
kb_shift:
        rrca
        djnz kb_shift
        pop bc
        jr c,kb_col_next
        ld a,e
        cpl
        and d
        ld d,a
kb_col_next:
        inc hl
        sla e
        djnz kb_col
        pop bc
        jr kb_row_end
kb_next:
        inc hl
        inc hl
        inc hl
        inc hl
        inc hl
kb_row_end:
        djnz kb_row
        ; Cursores y espacio como alias de R/E/Q/W/T de Fred.
        ld a,(selector_saved)
        bit 2,a
        jr nz,kb_result
        push bc
        in a,(PPIC)
        and 0F0h
        or 08h
        out (PPIC),a
        in a,(PPIB)
        bit 5,a                 ; arriba -> R
        jr nz,kb_no_up
        res 3,d
kb_no_up:
        bit 6,a                 ; abajo -> E
        jr nz,kb_no_down
        res 2,d
kb_no_down:
        bit 4,a                 ; izquierda -> Q
        jr nz,kb_no_left
        res 0,d
kb_no_left:
        bit 7,a                 ; derecha -> W
        jr nz,kb_no_right
        res 1,d
kb_no_right:
        bit 0,a                 ; espacio -> T / disparo
        jr nz,kb_no_fire
        res 4,d
kb_no_fire:
        pop bc
kb_result:
        ld a,d
        or 0E0h
        ld (last_key),a
        pop hl
        pop de
        pop bc
        ret

        include "runtime_slots.inc"
        include "vdp.inc"
        include "dump.inc"
        include "tables.inc"
attr2col equ 03980h
shadow equ 03A00h
R_END:
