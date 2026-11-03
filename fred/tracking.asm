; Local 40x40 map. A hardware sprite marks its centre in red.
        include "tracking_targets.inc"
        org 01C20h
tracking_active: db 0
tracking_position: dw 0
tracking_pending: db 0
tracking_shift: db 0

; Called after the original map has been drawn, including subsequent updates.
tracking_acquire:
        push de
        ld de,(06649h)
        ld (tracking_position),de
        ld a,(tracking_active)
        or a
        jr nz,tracking_acquire_done
        inc a
        ld (tracking_active),a
        call tracking_build_cache
        xor a
        ld (tracking_pending),a
        ld a,i
        push af
        di
        ; Sprite pattern table at 3800, attribute table at 1B00.
        ld hl,03800h
        call tracking_vaddr
        ld hl,tracking_pattern
        ld b,8
tracking_pattern_loop:
        ld a,(hl)
        out (098h),a
        inc hl
        djnz tracking_pattern_loop
        ld hl,01B00h
        call tracking_vaddr
        ld a,66                ; sprite top 67, dot centred at y=68
        out (098h),a
        nop
        nop
        nop
        ld a,227               ; dot centred at x=228
        out (098h),a
        nop
        nop
        nop
        xor a
        out (098h),a
        nop
        nop
        nop
        ld a,8                 ; MSX medium red
        out (098h),a
        nop
        nop
        nop
        ld a,0D0h
        out (098h),a           ; end of sprite list
        pop af
        jp po,tracking_acquire_done
        ei
tracking_acquire_done:
        pop de
        ret

tracking_tick:
        push af
        ld a,(tracking_active)
        or a
        jr z,tracking_tick_done
        push bc
        push de
        push hl
        push ix
        push iy
        ld hl,(06649h)
        ld de,(tracking_position)
        or a
        sbc hl,de
        jr z,tracking_unchanged
        ld hl,(06649h)
        ld (tracking_position),hl
        call tracking_draw
        ld a,1
        ld (tracking_pending),a
tracking_unchanged:
        pop iy
        pop ix
        pop hl
        pop de
        pop bc
tracking_tick_done:
        pop af
        ret

tracking_reset:
        push af
        push hl
        ld a,(tracking_active)
        or a
        jr z,tracking_reset_done
        xor a
        ld (tracking_active),a
        ld (tracking_pending),a
        ld a,i
        push af
        di
        ld hl,01B00h
        call tracking_vaddr
        ld a,0D0h
        out (098h),a
        pop af
        jp po,tracking_reset_done
        ei
tracking_reset_done:
        pop hl
        pop af
        ret

tracking_vaddr:
        ld a,l
        out (099h),a
        ld a,h
        or 040h
        out (099h),a
        ret

; Original map doubles each maze row vertically. Calculate it once and
; copy the five bitmap bytes to the second scanline instead of querying
; the same 20 world cells a second time.
tracking_draw:
        ld a,(06649h)
        add a,6
        and 7
        ld (tracking_shift),a
        ld hl,0301Ah
        ld de,(06649h)
        ld a,e
        sub 10
        ld e,a
        ld a,d
        sub 10
        ld d,a
        ld b,20
tracking_row:
        push bc
        push de
        push hl
        push de
        ex de,hl
        call 062D3h
        pop de
        call tracking_line
        ld de,5
        or a
        sbc hl,de
        push hl
        ld de,(tracking_screen)
        inc d
        call 062D3h
        ex de,hl
        pop hl
        ld bc,5
        ldir
        pop hl
        pop de
        pop bc
        inc d
        inc h
        inc h
        ld (tracking_screen),hl
        djnz tracking_row
        ld hl,0301Ah
        ld (tracking_screen),hl
        ret
tracking_screen: dw 0301Ah
tracking_pattern: db 0,0E0h,0E0h,0E0h,0,0,0,0

; Build a padded one-bit maze once after pickup. World topology is fixed
; for the level; its normal initialization precedes acquisition.
tracking_build_cache:
        push bc
        push hl
        push de
        ld hl,0E000h
        ld de,tracking_cache
        ld b,32
tracking_cache_row:
        xor a
        ld (de),a
        inc de
        ld (de),a
        inc de
        push bc
        ld c,4
tracking_cache_byte:
        ld b,8
        xor a
tracking_cache_bit:
        push af
        ld a,(hl)
        inc hl
        or a
        jr z,tracking_cache_solid
        cp 4
        jr c,tracking_cache_clear
tracking_cache_solid:
        pop af
        scf
        jr tracking_cache_append
tracking_cache_clear:
        pop af
        or a
tracking_cache_append:
        rla
        djnz tracking_cache_bit
        ld (de),a
        inc de
        dec c
        jr nz,tracking_cache_byte
        xor a
        ld (de),a
        inc de
        ld (de),a
        inc de
        pop bc
        djnz tracking_cache_row
        pop de
        pop hl
        pop bc
        ret

; Four bytes cover the 20-cell window at every horizontal bit offset.
tracking_line:
        push iy
        push hl
        pop iy
        ld a,d
        cp 32
        jr nc,tracking_line_empty
        ld l,d
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld h,tracking_cache/256
        ld a,e
        add a,16
        rrca
        rrca
        rrca
        and 7
        add a,l
        ld l,a
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        ld a,(tracking_shift)
        or a
        jr z,tracking_line_aligned
tracking_align:
        sla e
        rl d
        rl c
        rl b
        dec a
        jr nz,tracking_align
tracking_line_aligned:
        ld a,b
        call tracking_expand_byte
        ld a,c
        call tracking_expand_byte
        ld a,d
        rrca
        rrca
        rrca
        rrca
        call tracking_expand_nibble
        jr tracking_line_done
tracking_line_empty:
        ld b,5
        xor a
tracking_empty_loop:
        ld (iy+0),a
        inc iy
        djnz tracking_empty_loop
tracking_line_done:
        push iy
        pop hl
        pop iy
        ret
tracking_expand_byte:
        push af
        rrca
        rrca
        rrca
        rrca
        call tracking_expand_nibble
        pop af
tracking_expand_nibble:
        or 0F0h
        ld l,a
        ld h,tracking_expand/256
        ld a,(hl)
        ld (iy+0),a
        inc iy
        ret

; Called at the same VBlank used to publish the game name table. Only
; 200 pattern bytes, no colour changes and no additional VBlank waits.
tracking_commit:
        ld a,(tracking_pending)
        or a
        ret z
        xor a
        ld (tracking_pending),a
        ld ix,tracking_rows
        ld e,5
tracking_commit_row:
        ld l,(ix+2)
        ld h,(ix+3)
        call tracking_vaddr
        ld l,(ix+0)
        ld h,(ix+1)
        ld d,5
tracking_commit_tile:
        rept 8
        ld a,(hl)
        out (098h),a
        nop
        nop
        inc h
        endm
        ld a,h
        sub 8
        ld h,a
        inc l
        dec d
        jr nz,tracking_commit_tile
        ld bc,4
        add ix,bc
        dec e
        jr nz,tracking_commit_row
tracking_commit_end:
        ret
tracking_rows:
        dw 040DAh,00790h,040FAh,007D0h,0481Ah,00E10h
        dw 0483Ah,00E50h,0485Ah,00E90h

; Called instead of 6BB7 by the item placement loop. Reject positions
; already used by an earlier item, preserving the original terrain test.
tracking_unique_item:
        call 06BB7h
        ret nc
        push bc
        push de
        push hl
        ld a,(09202h)
        sub b
        jr z,tracking_unique_ok
        ld b,a
        ld a,e
        add a,a
        add a,a
        inc a
        ld e,a
        ld a,d
        call 06454h
        add a,3
        ld d,a
        ld hl,0D11Fh
tracking_unique_next:
        ld a,(hl)
        inc hl
        cp e
        jr nz,tracking_unique_skip
        ld a,(hl)
        cp d
        jr z,tracking_unique_no
tracking_unique_skip:
        push de
        ld de,10
        add hl,de
        pop de
        djnz tracking_unique_next
tracking_unique_ok:
        scf
        jr tracking_unique_return
tracking_unique_no:
        or a
tracking_unique_return:
        pop hl
        pop de
        pop bc
        ret
        include "fire.inc"
tracking_code_end:
        defs 01EF0h-$,0
tracking_expand:
        db 0,3,12,15,48,51,60,63,192,195,204,207,240,243,252,255
tracking_cache:
        ds 256
tracking_end:
