; Native SCREEN 2 renderer. Fred does not call the replaced FP routines.
; Code 2400-2EFF; slot keys 2F00-313F/3200-343F; descriptors 3440-385F.
; HUD source table 2080-216F; dirty spans 2300-232B; UDGs 2330-23D7.
; Three direct lookup tables D400-DCFF; HUD shadow E420-EC8F.
; CPU 1B00-1C1F: one collision flag bit per direct-lookup bucket.
; 3A00-3CFF: map name shadow, HUD dirty flags (legacy: attribute shadow).
; Each bank reserves 168/192/168 pattern slots for the map. The remaining
; 88/64/88 slots belong to the HUD. Cache misses upload a pattern+colour;
; Front patterns are pinned. Names go to the hidden table; R2 flips in
; VBlank. DD00-DDFF holds per-bank pins, then the queued HUD updates.
; Only an exhausted old/new pattern union uses a blanked bank rebuild.
; Map graphics 9400-ABFF are immutable. Other source addresses are reloaded.
        org 02400h
        include "tiles_runtime.inc"
tile_enter:
        push ix
        push iy
        exx
        push bc
        push de
        push hl
        exx
        di
        ld a,1
        ld (game_active),a
        ei
        ld a,(tile_mode)
        or a
        jr nz,tile_ready
        call screen_off
        ld a,1
        ld (tile_mode),a
        ld (hud_force),a
        ld (hud_dirty),a
        ld (hud_dirty+1),a
        ld (hud_dirty+2),a
        ld hl,03440h
        ld de,03441h
        ld bc,1055
        ld (hl),0FFh
        ldir
        ld hl,03A00h
        ld de,03A01h
        ld bc,767
        ld (hl),0FFh
        ldir
tile_ready:
        ld hl,02300h
        ld (dirty_ptr),hl
        xor a
        ld (map_dirty),a
        ld hl,(0638Fh)
        ld de,(previous_map)
        or a
        sbc hl,de
        ld (view_delta),hl
        ld a,h
        or l
        ld (frame_force),a
        jr nz,replace_back_table
        ld a,(mirror_pending)
        or a
        call nz,mirror_rows
        jr back_table_ready
replace_back_table:
        ld a,1
        ld (map_dirty),a
back_table_ready:
        xor a
        ld (mirror_pending),a
        ld hl,(0638Fh)
        ld (previous_map),hl
        ld (map_ptr),hl
        ld de,03440h
        xor a
        ld (bank),a
tile_bank:
        push de
        call bank_setup
        pop de
        ld hl,(map_ptr)
        ld (bank_start),hl
        ld (bank_shadow),de
        ld a,(bank)
        or a
        ld a,1
        jr nz,bank_first
        ld a,33
bank_first:
        ld (first_cell),a
        ld a,(tile_mode)
        cp 2
        ld a,0
        jr z,bank_no_force
        inc a
bank_no_force:
        or a
        push de
        call nz,clear_lookup
        pop de
        ld a,(tile_mode)
        cp 2
        ld a,1
        jr nz,bank_force_set
        ld a,(frame_force)
bank_force_set:
        ld (bank_force),a
        ld a,(bank_force)
        or a
        jr nz,bank_needs_render
        ld hl,(bank_start)
        ld de,(bank_shadow)
        ld a,(row_count)
        ld (rows),a
bank_precheck:
        call row_equal
        jr nz,bank_needs_render
        push de
        ld de,16
        add hl,de
        pop de
        push hl
        ld hl,(dirty_ptr)
        ld (hl),0FFh
        inc hl
        inc hl
        ld (dirty_ptr),hl
        pop hl
        ld a,(rows)
        dec a
        ld (rows),a
        jr nz,bank_precheck
        jp bank_done
bank_needs_render:
        ; Precheck may have advanced the dirty-row pointer; restore it.
        ld a,(bank)
        or a
        ld hl,02300h
        jr z,bank_dirty_ptr
        ld hl,0230Eh
        dec a
        jr z,bank_dirty_ptr
        ld hl,0231Eh
bank_dirty_ptr:
        ld (dirty_ptr),hl
        call pin_front
        call shift_view
bank_restart:
        ld hl,(bank_start)
        ld de,(bank_shadow)
        ld a,(first_cell)
        ld iyl,a
        ld a,(row_count)
        ld (rows),a
map_row:
        ld a,0FFh
        ld (row_first),a
        push hl
        push de
        ld a,(bank_force)
        ld b,a
        ld a,(shifted)
        or b
        jr nz,row_changed
        call row_equal
        jr nz,row_changed
        pop bc
        pop bc
        ld a,iyl
        add a,24
        ld iyl,a
        jp row_done
row_changed:
        pop de
        pop hl
        ld iyh,24
map_cell:
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(bank_force)
        or a
        jr nz,map_force
        ld a,(de)
        inc de
        cp c
        jr nz,map_low_changed
        ld a,(de)
        inc de
        cp b
        jr nz,map_changed
        ld a,b
        and 01Fh
        cp 3
        jp c,map_next
        jr map_changed
map_low_changed:
        inc de
map_changed:
        dec de
        dec de
map_force:
        ld a,c
        ld (de),a
        inc de
        ld a,b
        ld (de),a
        inc de
        push bc
        exx
        pop de
        call resolve_name
        call map_name
        exx
map_next:
        inc iyl
        dec iyh
        jp nz,map_cell
row_done:
        push hl
        push de
        call flush_row
        pop de
        pop hl
        push de
        ld de,16
        add hl,de
        pop de
        ld a,iyl
        add a,8
        ld iyl,a
        ld a,(rows)
        dec a
        ld (rows),a
        jp nz,map_row
bank_done:
        ld (map_ptr),hl
        ld a,(bank)
        inc a
        ld (bank),a
        cp 3
        jp nz,tile_bank
        ld a,2
        ld (tile_mode),a
        exx
        pop hl
        pop de
        pop bc
        exx
        pop iy
        pop ix
        ei
        ret
resolve_name:
        ld a,d
        and 01Fh
        cp 3
        jp nc,resolve_miss
        ; Immutable graphics with identical bytes share one source index.
        ; The canonical low byte is local to each 256-pattern page; D keeps
        ; the source page and colour. Dynamic sources never use this table.
        add a,018h
        ld h,a
        ld l,e
        ld e,(hl)
        ld a,d
        and 01Fh
lookup_page:
        add a,0D4h
        ld h,a
        call descriptor_hash
        ld l,a
        ld (lookup_address),hl
        ld a,(hl)
        or a
        jp z,resolve_miss
        dec a
        ld c,a
        ld b,0
        ld hl,(cache_base)
        add hl,bc
        ld a,(hl)
        cp e
        jr nz,resolve_collision_check
        ld a,h
        sub 3
        ld h,a
        ld a,(hl)
        cp d
        ld a,c
        ret z
        ld a,h
        add a,3
        ld h,a
resolve_collision_check:
        ; Only this bucket's collision history can hide a pinned copy.
        ; A collision elsewhere must not turn every stale hint into a scan.
        xor a
        call collision_flag
        or a
        jr nz,resolve_conflict
        push de
        ld e,(hl)
        ld a,h
        sub 3
        ld h,a
        ld d,(hl)
        ld a,d
        and 01Fh
        cp 3
        jr nc,resolve_stale
        ld b,a
        ld a,(lookup_high)
        add a,b
        ld h,a
        call descriptor_hash
        ld l,a
        ld bc,(lookup_address)
        or a
        sbc hl,bc
        jr nz,resolve_stale
        pop de
        ld a,1
        call collision_flag
        jr resolve_conflict
resolve_stale:
        pop de
        jp resolve_miss
; Black tiles use the other half of the low-byte index. This separates
; black backgrounds 0000-0013 from ropes C000-C013 without colliding with
; the common wall ranges A03C-A077. Other collisions use the full key.
; The direct table is a hint, not the complete cache. Colour variants can
; hash to the same entry. Recover an existing pinned descriptor before
; allocating another copy (old and newly prepared names both pin slots).
resolve_conflict:
        ld hl,(cache_base)
        ld a,(capacity)
        ld b,a
        ld c,0
resolve_probe:
        ld a,(hl)
        cp e
        jr nz,resolve_probe_next
        push hl
        ld a,h
        sub 3
        ld h,a
        ld a,(hl)
        cp d
        pop hl
        jr nz,resolve_probe_next
        push hl
        ld h,0DDh
        ld l,c
        ld a,(hl)
        pop hl
        or a
        jr nz,resolve_reuse
resolve_probe_next:
        inc hl
        inc c
        djnz resolve_probe
        jr resolve_miss
resolve_reuse:
        ld a,d
        and 01Fh
        ld b,a
        ld a,(lookup_high)
        add a,b
        ld h,a
        call descriptor_hash
        ld l,a
        ld a,c
        inc a
        ld (hl),a
        dec a
        ret
; CPU RAM 1B00-1C1F: collision bits, separate from VRAM names.
; A=0 tests a bucket, A=1 marks it. Preserve the descriptor and slot pointer.
collision_flag:
        push bc
        push de
        push hl
        ld b,a
        ld hl,(lookup_address)
        ld a,l
        and 7
        ld c,a
        call collision_address
        ld a,080h
collision_mask:
        rlca
        dec c
        jp p,collision_mask
        ld c,a
        ld a,b
        or a
        jr z,collision_read
        ld a,(hl)
        or c
        ld (hl),a
collision_read:
        ld a,(hl)
        and c
        pop hl
        pop de
        pop bc
        ret
collision_address:
        rept 3
        srl h
        rr l
        endm
        ld de,0080h              ; (D400h >> 3) + 80h = 1B00h
        add hl,de
        ret
descriptor_hash:
        ld a,d
        and 0E0h
        cp 040h                 ; red damage Fred must not evict yellow hint
        jr z,descriptor_hash_ready
        sub 1
        sbc a,a
        and 080h                ; retain separate black-background bucket
descriptor_hash_ready:
        xor e
        ret
resolve_miss:
        ld (descriptor),de
        call allocate_slot
        ld (slot),a
        ld l,a
        ld h,0
        ld bc,(cache_base)
        add hl,bc
        ld (hl),e
        ld a,h
        sub 3
        ld h,a
        ld (hl),d
        ld a,d
        and 01Fh
        cp 3
        jr nc,resolve_upload
        ld h,a
        call descriptor_hash
        ld l,a
        ld a,(lookup_high)
        add a,h
        ld h,a
        ld a,(slot)
        inc a
        ld (hl),a
resolve_upload:
        call upload_tile
        ld a,(slot)
        ret
clear_lookup:
        ; 96 flag bytes per bank: one bit per direct lookup bucket.
        ld a,(lookup_high)
        ld h,a
        ld l,0
        call collision_address
        ld b,96
        xor a
clear_collision_flags:
        ld (hl),a
        inc hl
        djnz clear_collision_flags
        ld a,(lookup_high)
        ld h,a
        ld l,0
        ld d,h
        ld e,1
        ld bc,767
        ld (hl),0
        ldir
        ret

bank_setup:
        ld a,(bank)
        ld hl,03200h
        ld de,192
        or a
        jr z,bank_cache_set
        add hl,de
        dec a
        jr z,bank_cache_set
        add hl,de
bank_cache_set:
        ld (cache_base),hl

        ld a,(bank)
        ld b,a
        ld a,0D4h
        dec b
        jp m,lookup_set
        ld a,0D7h
        jr z,lookup_set
        ld a,0DAh
lookup_set:
        ld (lookup_high),a
        ld (lookup_page+1),a
        ld a,(bank)
        ld b,a
        ld a,(back_high)
        add a,b
        ld (name_high),a
        ld a,b
        add a,03Ah
        ld (shadow_high),a
        ld a,(bank)
        rlca
        rlca
        rlca
        ld (pattern_high),a
        ld a,(bank)
        cp 1
        ld a,168
        ld b,7
        jr nz,bank_capacity
        ld a,192
        inc b
bank_capacity:
        ld (capacity),a
        ld a,b
        ld (row_count),a
        ret

map_name:
        ld l,a
        ld h,0DDh
        ld (hl),1
        ld b,a
        ld a,iyl
        ld l,a
        ld a,(shadow_high)
        ld h,a
        ld a,b
        cp (hl)
        ret z
        ld (hl),a
        ld a,1
        ld (map_dirty),a
        ld a,(row_first)
        cp 0FFh
        jr nz,map_name_last
        ld a,iyl
        ld (row_first),a
map_name_last:
        ld a,iyl
        ld (row_last),a
        ret
put_name:
        ld b,a
        ld a,(cell)
        ld l,a
        ld a,(shadow_high)
        ld h,a
        ld a,b
        ld (hl),a
        ld a,(name_high)
        ld h,a
        call tile_vaddr
        ld a,b
        out (098h),a
        ld a,h
        xor 4
        ld h,a
        call tile_vaddr
        ld a,b
        out (098h),a
        ld hl,(name_writes)
        inc hl
        ld (name_writes),hl
        ret

slot_address:
        ld a,(slot)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(pattern_high)
        or h
        ld h,a
        ret
upload_tile:
        call slot_address
        call tile_vaddr
        ld hl,(descriptor)
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,09400h
        add hl,bc
        ld b,8
upload_bytes:
        ld a,(hl)
        out (098h),a
        inc hl
        djnz upload_bytes
        ld hl,(descriptor)
        ld a,h
        rlca
        rlca
        rlca
        and 7
        or 0C0h
        ld l,a
        ld h,039h
        ld a,(hl)
        ld (colour),a
        call write_colour
        ld hl,(pattern_writes)
        inc hl
        ld (pattern_writes),hl
        ret
write_colour:
        call slot_address
        set 5,h
        call tile_vaddr
        ld a,(colour)
        ld b,8
colour_bytes:
        out (098h),a
        nop
        nop
        djnz colour_bytes
        ret
tile_vaddr:
        ld a,i
        push af
        di
        ld a,l
        out (099h),a
        ld a,h
        or 040h
        out (099h),a
        pop af
        jp po,vaddr_return
        ei
vaddr_return:
        ret

; Only dirty HUD cells are compared; unchanged banks are skipped entirely.
; HUD writers mark cells on actual RAM changes. We also compare the final
; bytes, because printing may erase and then restore an identical character.
tile_present:
        ld a,(tile_mode)
        or a
        jp z,dump_legacy
        xor a
        ld (queue_count),a
        call hud_prepare
        jp present_commit
hud_prepare:
        ld a,(hud_dirty)
        ld hl,hud_dirty+1
        or (hl)
        inc hl
        or (hl)
        ret z
        push iy
        ld de,0E420h
        ld hl,hud_cells
        xor a
        ld (bank),a
hud_bank:
        push hl
        push de
        call bank_setup
        pop de
        pop hl
        push hl
        push de
        ld a,(bank)
        ld e,a
        ld d,0
        ld hl,hud_dirty
        add hl,de
        ld a,(hl)
        ld (hl),0
        pop de
        pop hl
        or a
        jr nz,hud_bank_dirty
        ld a,(capacity)
        neg
        ld c,a
        ld b,0
        add hl,bc
        ex de,hl
        ld bc,792
        ld a,(bank)
        cp 1
        jr nz,hud_skip_length
        ld bc,576
hud_skip_length:
        add hl,bc
        ex de,hl
        jp hud_next_bank
hud_bank_dirty:
        ld a,(capacity)
        ld iyl,a
        neg
        ld iyh,a
hud_cell:
        ld c,(hl)
        inc hl
        push hl
        ld a,(shadow_high)
        ld h,a
        ld l,c
        ld a,(hl)
        or a
        jr nz,hud_cell_dirty
        ex de,hl
        ld bc,9
        add hl,bc
        ex de,hl
        jp hud_name_ready
hud_cell_dirty:
        ld (hl),0
        ld a,(pattern_high)
        add a,040h
        ld h,a
        ld l,c
        ld (hud_source),hl
        ld a,c
        ld (cell),a
        ld a,(hud_force)
        ld c,a
        rept 8
        ld a,(de)
        cp (hl)
        jr z,$+6
        ld a,(hl)
        ld (de),a
        ld c,1
        inc de
        inc h
        endm
        ld a,(bank)
        add a,058h
        ld h,a
        ld a,(de)
        cp (hl)
        jr z,hud_attr_equal
        ld a,(hl)
        ld (de),a
        ld c,1
hud_attr_equal:
        inc de
        ld a,(hl)
        or 080h
        ld l,a
        ld h,039h
        ld a,(hl)
        ld (colour),a
        ld a,c
        or a
        jr z,hud_clean
        push de
        ld a,iyl
        ld (slot),a
        ld a,(screen_blank)
        or a
        jr nz,hud_direct
        call queue_hud
        jr hud_uploaded
hud_direct:
        call slot_address
        call tile_vaddr
        ld hl,(hud_source)
        ld b,8
hud_upload:
        ld a,(hl)
        out (098h),a
        inc h
        djnz hud_upload
        call write_colour
        ld hl,(hud_writes)
        inc hl
        ld (hud_writes),hl
hud_uploaded:
        pop de
hud_clean:
        ld a,(hud_force)
        or a
        jr z,hud_name_ready
        push de
        ld a,iyl
        call put_name
        ld a,(shadow_high)
        ld h,a
        ld a,(cell)
        ld l,a
        ld (hl),0
        pop de
hud_name_ready:
        inc iyl
        pop hl
        dec iyh
        jp nz,hud_cell
hud_next_bank:
        ld a,(bank)
        inc a
        ld (bank),a
        cp 3
        jp nz,hud_bank
        xor a
        ld (hud_force),a
        pop iy
        ret

; The original non-game renderer still handles menus, end screens and text.
tile_legacy:
        ld a,i
        push af
        di
        call tile_leave
        call 03900h
        call dump_legacy
        pop af
        jp po,legacy_return
        ei
legacy_return:
        ret
prepare_game_screen:
        call tracking_reset
        ld a,1
        ld (game_active),a       ; stop legacy ISR dumps before drawing frame
        call screen_off
        jp 062F4h               ; original level attribute initialization
tile_exit_frame:
        call exit_prepare
        jp tile_present
; The legacy table is visible only after all its patterns/colours exist.
legacy_ready:
        ld a,(screen_blank)
        or a
        ret z
        call wait_vblank
        ld a,0E2h
        out (099h),a
        ld a,081h
        out (099h),a
        xor a
        ld (screen_blank),a
        ret
tile_title:
        call tile_leave
        jp 060B0h
tile_leave:
        call tracking_reset
        ld a,i
        push af
        di
        ld a,(tile_mode)
        or a
        jr z,leave_done
        call screen_off
        xor a
        ld (tile_mode),a
        ld (game_active),a
        ld a,6
        out (099h),a
        ld a,082h
        out (099h),a
        ld a,018h
        ld (front_high),a
        ld a,01Ch
        ld (back_high),a
        ld hl,01800h
        call tile_vaddr
        ld c,3
leave_bank:
        xor a
leave_name:
        out (098h),a
        nop
        nop
        inc a
        jr nz,leave_name
        dec c
        jr nz,leave_bank
        ld hl,03A00h
        ld de,03A01h
        ld bc,767
        ld (hl),0FFh
        ldir
leave_done:
        pop af
        jp po,leave_return
        ei
leave_return:
        ret

; All game-time HUD writers converge here. Equal writes do not dirty a bank.
; Preserve the original accumulator and flags, including inverse/OVER print.
hud_store_hl:
        push af
        cp (hl)
        jr z,hud_store_done
        ld (hl),a
        ld a,(tile_mode)
        or a
        jr z,hud_store_done
        ld a,h
        cp 058h
        jr nc,hud_attr_bank
        and 018h
        rrca
        rrca
        rrca
        jr hud_mark_bank
hud_attr_bank:
        and 3
hud_mark_bank:
        push hl
        add a,03Ah
        ld h,a
        ld (hl),1
        pop hl
        sub 03Ah
        or a
        jr z,hud_mark_zero
        dec a
        jr z,hud_mark_one
        ld a,1
        ld (hud_dirty+2),a
        jr hud_store_done
hud_mark_zero:
        ld a,1
        ld (hud_dirty),a
        jr hud_store_done
hud_mark_one:
        ld a,1
        ld (hud_dirty+1),a
hud_store_done:
        pop af
        ret
hud_rom_pixel:
        ld a,(de)
        and b
        xor (hl)
        xor c
        ex de,hl
        call hud_store_hl
        ex de,hl
        ret
; Map pickup draws 40 scanlines at x=26..30, y=48..87 directly into
; the Spectrum bitmap. Publish its 25 HUD cells through the VBlank queue.
hud_minimap:
        call 0AEC8h
minimap_mark:
        push af
        push bc
        push hl
        call tracking_acquire
        ld hl,03ADAh
        ld b,5
minimap_dirty_row:
        ld c,5
minimap_dirty_cell:
        ld (hl),1
        inc hl
        dec c
        jr nz,minimap_dirty_cell
        ld a,l
        add a,27
        ld l,a
        jr nc,minimap_dirty_next
        inc h
minimap_dirty_next:
        djnz minimap_dirty_row
        ld a,1
        ld (hud_dirty),a
        ld (hud_dirty+1),a
        pop hl
        pop bc
        pop af
        ret
hud_small_left:
        call hud_store_hl
        inc hl
        ld a,c
        ret
hud_small_right:
        call hud_store_hl
        dec hl
        inc de
        ret
hud_rom_attribute:
        include "rom_attribute.inc"
        jp hud_store_hl
hud_health:
        ld b,3
        ld hl,059BAh
        ld e,0
health_row:
        ld c,5
        push hl
health_cell:
        ld a,(08CBFh)
        cp e
        push af
        ld a,027h
        jr c,health_store
        jr z,health_store
        ld a,017h
health_store:
        call hud_store_hl
        pop af
        inc hl
        inc e
        dec c
        jr nz,health_cell
        pop hl
        push de
        ld de,32
        add hl,de
        pop de
        djnz health_row
        ret

; Compare four descriptors per iteration, with a separate path for changes.
row_equal:
        ld b,6
row_compare:
        rept 4
        ld a,(de)
        cp (hl)
        ret nz
        inc de
        inc hl
        ld a,(de)
        cp (hl)
        ret nz
        and 01Fh
        cp 3
        jr nc,row_dynamic
        inc de
        inc hl
        endm
        djnz row_compare
        xor a
        ret
row_dynamic:
        or 1
        ret

clear_pins:
        xor a
        ld (allocation_cursor),a
        ld hl,0DD00h
        ld de,0DD01h
        ld bc,255
        ld (hl),a
        ldir
        ret
pin_front:
        call clear_pins
        ld a,(tile_mode)
        cp 2
        ret nz
        ld a,(shadow_high)
        ld h,a
        ld a,(first_cell)
        ld l,a
        ld d,0DDh
        ld a,(row_count)
        ld b,a
pin_row:
        ld c,24
pin_cell:
        ld a,(hl)
        inc hl
        ld e,a
        ld a,1
        ld (de),a
        dec c
        jr nz,pin_cell
        ld a,l
        add a,8
        ld l,a
        djnz pin_row
        ret
allocate_slot:
        ld a,(allocation_cursor)
        ld l,a
        ld h,0DDh
allocate_try:
        ld a,(capacity)
        cp l
        jr z,allocation_full
        ld a,(hl)
        inc l
        or a
        jr nz,allocate_try
        dec l
        ld (hl),1
        ld a,l
        inc a
        ld (allocation_cursor),a
        dec a
        ret
allocation_full:
        ld a,1
        ld (map_dirty),a
        ; Exceptional union of old/new patterns exceeds available slots.
        ; Hide at VBlank, rebuild this bank, and reveal the complete frame.
        call screen_off
        ld hl,(fallback_count)
        inc hl
        ld (fallback_count),hl
        call clear_pins
        call clear_lookup
        ld a,(bank)
        or a
        ld hl,02300h
        jr z,restart_dirty_ptr
        ld hl,0230Eh
        dec a
        jr z,restart_dirty_ptr
        ld hl,0231Eh
restart_dirty_ptr:
        ld (dirty_ptr),hl
        ld a,1
        ld (bank_force),a
        pop hl
        pop hl
        exx
        jp bank_restart

flush_row:
        ld a,(frame_force)
        ld b,a
        ld a,(bank_force)
        or b
        jr z,flush_dirty_extent
        ld a,iyl
        sub 24
        ld (row_first),a
        add a,23
        ld (row_last),a
flush_dirty_extent:
        ld hl,(dirty_ptr)
        ld a,(row_first)
        ld (hl),a
        inc hl
        ld a,(row_last)
        ld (hl),a
        inc hl
        ld (dirty_ptr),hl
flush_span:
        ld a,(row_first)
        cp 0FFh
        ret z
        ld l,a
        ld e,a
        ld a,(name_high)
        ld h,a
        call tile_vaddr
        ld a,(row_last)
        sub e
        inc a
        ld b,a
        ld e,a
        ld d,0
        push hl
        ld hl,(name_writes)
        add hl,de
        ld (name_writes),hl
        pop hl
        ld a,(shadow_high)
        ld h,a
        ld c,098h
span_byte:
        outi
        nop
        nop
        nop
        jp nz,span_byte
        ret
mirror_rows:
        ld hl,02300h
        ld bc,01601h
mirror_row:
        ld a,(hl)
        ld (row_first),a
        inc hl
        ld a,(hl)
        ld (row_last),a
        inc hl
        push hl
        push bc
        ld a,c
        rrca
        rrca
        rrca
        and 3
        ld b,a
        add a,03Ah
        ld (shadow_high),a
        ld a,(back_high)
        add a,b
        ld (name_high),a
        call flush_span
        pop bc
        pop hl
        inc c
        djnz mirror_row
        ret

; Queue entries: shadow source address, VRAM pattern address. DD00-DDFF is
; reused after the map has finished pinning patterns. Max 64 dirty HUD cells.
queue_hud:
        ld a,(queue_count)
        cp 64
        jr nz,queue_space
        push de
        push ix
        push iy
        call drain_hud
        pop iy
        pop ix
        pop de
queue_space:
        ld a,(queue_count)
        inc a
        ld (queue_count),a
        dec a
        add a,a
        add a,a
        ld l,a
        ld h,0DDh
        push hl
        ex de,hl
        ld bc,9
        or a
        sbc hl,bc
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        push hl
        call slot_address
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

drain_hud:
        ld a,(queue_count)
        or a
        ret z
        ld ix,0DD00h
        ld iyh,a
hud_batch:
        call wait_vblank
        ld iyl,8
hud_commit_cell:
        ld l,(ix+2)
        ld h,(ix+3)
        call tile_vaddr
        ld l,(ix+0)
        ld h,(ix+1)
        ld b,8
        ld c,098h
hud_commit_byte:
        outi
        nop
        nop
        nop
        jp nz,hud_commit_byte
        ld a,(hl)
        and 07Fh
        or 080h
        ld l,a
        ld h,039h
        ld a,(hl)
        push af
        ld l,(ix+2)
        ld h,(ix+3)
        set 5,h
        call tile_vaddr
        pop af
        ld b,8
hud_commit_colour:
        out (098h),a
        nop
        nop
        djnz hud_commit_colour
        ld de,4
        add ix,de
        ld hl,(hud_writes)
        inc hl
        ld (hud_writes),hl
        dec iyh
        jr z,hud_drained
        dec iyl
        jr nz,hud_commit_cell
        jr hud_batch
hud_drained:
        xor a
        ld (queue_count),a
        ret

present_commit:
        push ix
        push iy
        call drain_hud
        ld a,(map_dirty)
        ld b,a
        ld a,(screen_blank)
        or b
        ld b,a
        ld a,(tracking_pending)
        or b
        jr z,present_done
        call wait_vblank
        ld a,(map_dirty)
        or a
        jr z,present_enable
        ld a,(back_high)
        ld b,a
        ld a,(front_high)
        ld (back_high),a
        ld a,b
        ld (front_high),a
        rrca
        rrca
        out (099h),a
        ld a,082h
        out (099h),a
present_enable:
        ld a,(screen_blank)
        or a
        jr z,present_done
        ld a,0E2h
        out (099h),a
        ld a,081h
        out (099h),a
        xor a
        ld (screen_blank),a
present_done:
        call tracking_commit
        ld a,(map_dirty)
        or a
        jr z,present_no_mirror
        ld (mirror_pending),a
present_no_mirror:
        xor a
        ld (map_dirty),a
        pop iy
        pop ix
        ret

screen_off:
        ld a,(screen_blank)
        or a
        ret nz
        ld a,i
        push af
        di
        call wait_vblank
        ld a,0A2h
        out (099h),a
        ld a,081h
        out (099h),a
        ld a,1
        ld (screen_blank),a
        pop af
        jp po,screen_off_return
        ei
screen_off_return:
        ret
wait_vblank:
        in a,(099h)
wait_vblank_next:
        in a,(099h)
        and 080h
        jr z,wait_vblank_next
vblank_observed:
        ret

        include "scroll_shadow.inc"
        include "async_sound.inc"
tile_mode: db 0
hud_force: db 0
hud_dirty: ds 3
bank: db 0
previous_map: dw 0
frame_force: db 0
capacity: db 0
cache_base: dw 0
bank_start: dw 0
bank_shadow: dw 0
first_cell: db 0
bank_force: db 0
row_count: db 0
rows: db 0
columns: db 0
cell: db 0
slot: db 0
probes: db 0
row_first: db 0
row_last: db 0
lookup_high: db 0
lookup_address: dw 0
collision_ptr: dw 0
lookup_conflicts: ds 3
descriptor: dw 0
map_ptr: dw 0
name_high: db 0
shadow_high: db 0
pattern_high: db 0
colour: db 0
hud_count: db 0
hud_source: dw 0
name_writes: dw 0
pattern_writes: dw 0
hud_writes: dw 0
hud_cells equ 02080h
udg_workspace equ 02330h
dirty_ptr: dw 02300h
front_high: db 018h
back_high: db 01Ch
screen_blank: db 0
map_dirty: db 0
queue_count: db 0
allocation_cursor: db 0
fallback_count: dw 0
mirror_pending: db 0
; Exit skips frame_hook, leaving the final gameplay frame unpublished.
; Commit it before pin_front uses the name shadow as the visible table.
exit_prepare:
        call tile_present
        jp tile_enter

tile_end:





