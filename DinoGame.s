; Define PPU Registers
PPU_CONTROL = $2000
PPU_MASK = $2001
PPU_STATUS = $2002
PPU_SPRRAM_ADDRESS = $2003
PPU_SPRRAM_IO = $2004
PPU_VRAM_ADDRESS1 = $2005
PPU_VRAM_ADDRESS2 = $2006
PPU_VRAM_IO = $2007
SPRITE_DMA = $4014
; Define APU Registers
APU_DM_CONTROL = $4010
APU_CLOCK = $4015
; Joystick/Controller values
JOYPAD1 = $4016
JOYPAD2 = $4017
; Gamepad bit values
PAD_A = $01
PAD_B = $02
PAD_SELECT = $04
PAD_START = $08
PAD_U = $10
PAD_D = $20
PAD_L = $40
PAD_R = $80

.segment "HEADER"
INES_MAPPER = 0
INES_MIRROR = 0
INES_SRAM = 0
.byte 'N', 'E', 'S', $1A ; ID
.byte $02
.byte $01
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4)
.byte (INES_MAPPER & %11110000)
.byte $0, $0, $0, $0, $0, $0, $0, $0

.segment "VECTORS"
.word nmi
.word reset
.word irq

;*****************************************************************
; 6502 Zero Page Memory (256 bytes)
;*****************************************************************
.segment "ZEROPAGE"
nmi_ready: .res 1
gamepad: .res 1

p1_y: .res 1
p2_y: .res 1
p3_y: .res 1
p4_y: .res 1

p1_max_y: .res 1
p2_max_y: .res 1
p3_max_y: .res 1
p4_max_y: .res 1

;*****************************************************************
; Sprite OAM Data area - copied to VRAM in NMI routine
;*****************************************************************
.segment "OAM"
oam: .res 256

;*****************************************************************
; Our default palette table has 16 entries for tiles
; and 16 entries for sprites
;*****************************************************************
.segment "RODATA"
default_palette:
.byte $0F,$15,$26,$37
.byte $0F,$09,$19,$29
.byte $0F,$01,$11,$21
.byte $0F,$00,$10,$30
.byte $0F,$18,$28,$38
.byte $0F,$14,$24,$34
.byte $0F,$1B,$2B,$3B
.byte $0F,$12,$22,$32
welcome_txt:
.byte 'W','E','L','C', 'O', 'M', 'E', 0

;*****************************************************************
; Import both the background and sprite character sets
;*****************************************************************
.segment "TILES"
.incbin "DinoGame.chr"

;*****************************************************************
; Remainder of normal RAM area
;*****************************************************************
.segment "BSS"
palette: .res 32

;*****************************************************************
; IRQ Clock Interrupt Routine
;*****************************************************************
.segment "CODE"
irq:
rti

;*****************************************************************
; Main application entry point for startup/reset
;*****************************************************************
.segment "CODE"
.proc reset
    sei
    lda #0
    sta PPU_CONTROL
    sta PPU_MASK
    sta APU_DM_CONTROL
    lda #$40
    sta JOYPAD2

    ; Disable decimal mode
    cld
    ldx #$FF
    txs

    ; Wait for vblank
    bit PPU_STATUS
wait_vblank:
    bit PPU_STATUS
    bpl wait_vblank

    ; Clear RAM
    lda #0
    ldx #0
clear_ram:
    sta $0000,x
    sta $0100,x
    sta $0200,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne clear_ram

    ; Position the sprites offscreen
    lda #255
    ldx #0
    clear_oam:
    sta oam,x
    inx
    inx
    inx
    inx
    bne clear_oam

    ; Wait for the second vblank
wait_vblank2:
    bit PPU_STATUS
    bpl wait_vblank2

    ; enable the NMI for graphical and jump to our main program updates
    lda #%10001000
    sta PPU_CONTROL
    jmp main
.endproc

.segment "CODE"
.proc nmi
    ; save registers
    pha
    txa
    pha
    tya
    pha

    ; Do we need to render
    lda nmi_ready
    bne :+
    jmp ppu_update_end
:
    cmp #2
    bne cont_render
    lda #%00000000
    sta PPU_MASK
    ldx #0
    stx nmi_ready
    jmp ppu_update_end

cont_render:
    ;Transfers sprite OAM data using DMA
    ldx #0
    stx PPU_SPRRAM_ADDRESS
    lda #>oam
    sta SPRITE_DMA

    ; Transfers the current palette to PPU
    lda #%10001000
    sta PPU_CONTROL
    lda PPU_STATUS
    lda #$3F
    sta PPU_VRAM_ADDRESS2
    stx PPU_VRAM_ADDRESS2
    ldx #0
loop:
        lda palette, x
        sta PPU_VRAM_IO
        inx
        cpx #32
        bcc loop
        lda #%00011110
    sta PPU_MASK
    ldx #0
    stx nmi_ready
ppu_update_end:
    pla
    tay
    pla
    tax
    pla
    rti
.endproc

.segment "CODE"
; ppu_update: waits until next NMI and turns rendering on (if not already)
.proc ppu_update
    lda #1
    sta nmi_ready
loop:
        lda nmi_ready
        bne loop
        rts
.endproc

.segment "CODE"
; ppu_off: waits until next NMI and turns rendering off
; (now safe to write PPU directly via PPU_VRAM_IO)
.proc ppu_off
    lda #2
    sta nmi_ready
loop:
        lda nmi_ready
        bne loop
        rts
.endproc

.segment "CODE"
.proc clear_nametable
    lda PPU_STATUS
    lda #$20
    sta PPU_VRAM_ADDRESS2
    lda #$00
    sta PPU_VRAM_ADDRESS2
    lda #0
    ldy #30
rowloop:
        ldx #32
columnloop:
        sta PPU_VRAM_IO
        dex
        bne columnloop
        dey
        bne rowloop
        ldx #64
loop:
        sta PPU_VRAM_IO
        dex
        bne loop
        rts
.endproc

;***************************************************************
; gamepad_poll: this reads the gamepad state into the variable
; labeled "gamepad".
; This only reads the first gamepad, and also if DPCM samples
; are played they can conflict with gamepad reading,
; which may give incorrect results.
;***************************************************************
.segment "CODE"
.proc gamepad_poll
    lda #1
    sta JOYPAD1
    lda #0
    sta JOYPAD1
    ldx #8
loop:
        pha
        lda JOYPAD1
        and #%00000011
        cmp #%00000001
        pla
        ror
        dex
        bne loop
        sta gamepad
    rts
.endproc

;**************************************************************
; Main application logic section includes the game loop
;**************************************************************
.segment "CODE"
.proc main
    ldx #0
paletteloop:
        lda default_palette, x
        sta palette, x
        inx
        cpx #32
        bcc paletteloop
        jsr clear_nametable
        lda PPU_STATUS
    lda #$20
    sta PPU_VRAM_ADDRESS2
    lda #$8A
    sta PPU_VRAM_ADDRESS2
    ldx #0
textloop:
        lda welcome_txt, x
        sta PPU_VRAM_IO
        inx
        cmp #0
        beq :+
        jmp textloop
:
    ; JUMP HEIGHTS
    lda #39
    sta p1_y
    lda #103
    sta p2_y
    lda #167
    sta p3_y
    lda #230
    sta p4_y

    ; MAX JUMP HEIGHTS
    lda #8
    sta p1_max_y
    lda #72
    sta p2_max_y
    lda #136
    sta p3_max_y
    lda #200
    sta p4_max_y

    ; Set the sprite attributes
    lda p1_y
    ; Set sprite y
    sta oam
    ; Set sprite tile
    lda #1
    sta oam + 1
    ; Set sprite attributes
    lda #0
    sta oam + 2
    ; Set sprite x
    lda #48
    sta oam + 3

    lda p2_y
    ; Set sprite y
    sta oam + 4
    ; Set sprite tile
    lda #1
    sta oam + 4 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 4 + 2
    ; Set sprite x
    lda #48
    sta oam + 4 + 3

    lda p3_y
    ; Set sprite y
    sta oam + 8
    ; Set sprite tile
    lda #1
    sta oam + 8 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 8 + 2
    ; Set sprite x
    lda #48
    sta oam + 8 + 3

    lda p4_y
    ; Set sprite y
    sta oam + 12
    ; Set sprite tile
    lda #1
    sta oam + 12 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 12 + 2
    ; Set sprite x
    lda #48
    sta oam + 12 + 3

    jsr ppu_update

mainloop:
    lda nmi_ready
    cmp #0
    bne mainloop

    jsr gamepad_poll
    lda gamepad
    and #PAD_U
    ; Is left pressed?
    beq NOT_GAMEPAD_UP
    ; Yes, get the current y position of our sprite
    lda oam
    ; Is the y position 0?
    cmp p1_max_y
    beq NOT_GAMEPAD_UP
    sec
    ; Subtract 1 from the y position
    sbc #1
    ; Set the new y position of our sprite
    sta oam
NOT_GAMEPAD_UP:
    lda gamepad
    and #PAD_D
    beq NOT_INPUT
    ; Get the current y position of our sprite
    lda oam
    ; Is the y position 248?
    cmp p1_y
    beq NOT_INPUT
    clc
    ; Add 1 to the y position
    adc #1
    ; Set the new y position of our sprite
    sta oam
NOT_INPUT:
    lda #1
    sta nmi_ready
    jmp mainloop
.endproc