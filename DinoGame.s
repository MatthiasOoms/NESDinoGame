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
INES_MIRROR = 1
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
gamepad: .res 1

is_game_in_main: .res 1

; randomizer seeds
seed_0: .res 2
seed_2: .res 2

; Y position of the players
p1_min_y: .res 1
p2_min_y: .res 1

; Max Y position of the players
p1_max_y: .res 1
p2_max_y: .res 1

; Y velocity of the players ; $FF = jumping ; $01 = falling/not jumping
p1_dy: .res 1
p2_dy: .res 1

jmp_speed: .res 1

; x coordinate of camera
camera_x: .res 1
current_nametable: .res 1

; time variables
time: .res 2
lasttime: .res 1

p1_duck: .res 1
p2_duck: .res 1

;*****************************************************************
; Sprite OAM Data area - copied to VRAM in NMI routine
;*****************************************************************
.segment "OAM"
oam: .res 256

;*****************************************************************
; Include NES Function Library
;*****************************************************************
.include "neslib.s"

;*****************************************************************
; Our default palette table has 16 entries for tiles
; and 16 entries for sprites
;*****************************************************************
.segment "RODATA"
default_palette:
.byte $30,$00,$00,$00
.byte $30,$00,$00,$00
.byte $30,$00,$00,$00
.byte $30,$00,$00,$00
.byte $30,$00,$00,$00
.byte $30,$00,$00,$00
.byte $30,$00,$00,$00
.byte $30,$00,$00,$00


horizon_line_one:
.byte 75, 75, 75, 75, 78, 75, 75, 75, 75, 78, 79, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75

horizon_line_two:
.byte 75, 75, 75, 75, 75, 75, 75, 75, 75, 78, 79, 75, 75, 75, 75, 75, 75, 75, 75, 75, 78, 75, 75, 75, 75, 78, 79, 75, 75, 75, 75, 75, 75

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

    ; increment time tick counter
    inc time
    bne :+
            inc time+1
    :

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

        vram_set_address ($3F00)

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
        lda is_game_in_main
        cmp #1
        beq start_scrolling

        pla
        tay
        pla
        tax
        pla
        rti

    start_scrolling:
    
        jsr horizontal_scrollling 
        pla
        tay
        pla
        tax
        pla
        rti
.endproc

;***************************************************************
; scroll background horizontally
;***************************************************************
.segment "CODE"
.proc horizontal_scrollling


    ; reset address latch
         lda PPU_STATUS

         ; Set the high bit of X and Y scroll.
         lda ppu_ctl0
         ora current_nametable
         sta PPU_CONTROL

         ; Set the low 8 bits of X and Y scroll.
         lda PPU_STATUS
         lda camera_x
         sta PPU_VRAM_ADDRESS1
         lda #00
         sta PPU_VRAM_ADDRESS1

         ldx camera_x
         inx
         stx camera_x

    	
         cpx 255
         bne ending

         ldx 0
         stx camera_x

         ldx current_nametable
         cpx #$00
         bne firsttable
            ldx #$01
            stx current_nametable
            jmp ending

        firsttable:
            ldx #$00
            stx current_nametable
            jmp ending


        ending:


    rts
.endproc



;***************************************************************
; draw horizon line
;***************************************************************
.segment "CODE"
.proc draw_horizon_one

    ;reset address latch
    lda PPU_STATUS

    ;iterate over the horizon line
    ldx #0
    loop:
        lda horizon_line_one, x
        sta PPU_VRAM_IO
        inx
        cpx #32
        beq :+ 
        jmp loop

    :
    rts
.endproc

.segment "CODE"
.proc draw_horizon_two

    ;reset address latch
    lda PPU_STATUS

    ;iterate over the horizon line
    ldx #0
    loop:
        lda horizon_line_two, x
        sta PPU_VRAM_IO
        inx
        cpx #32
        beq :+ 
        jmp loop

    :
    rts
.endproc


;***************************************************************
; display game screen
;***************************************************************
.segment "CODE"
.proc display_game_screen

    vram_set_address (NAME_TABLE_0_ADDRESS + 12 * 32)
    jsr draw_horizon_one

    vram_set_address (NAME_TABLE_0_ADDRESS + 28 * 32)
    jsr draw_horizon_one

    vram_set_address (NAME_TABLE_1_ADDRESS + 12 * 32)
    jsr draw_horizon_two

    vram_set_address (NAME_TABLE_1_ADDRESS + 28 * 32)
    jsr draw_horizon_two




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


;***************************************************************
; init_variables: initialises various values in zero page memory
;***************************************************************
.segment "CODE"
.proc init_variables
    ; set bool of is in main
    lda #0
    sta is_game_in_main

    ; Set the jump speed
    lda #3
    sta jmp_speed

    ; MIN JUMP HEIGHTS
    lda #100
    sta p1_min_y
    lda #228
    sta p2_min_y

    ; JUMP VELOCITIES
    lda #1
    sta p1_dy
    sta p2_dy

    ; DUCK BOOLS
    lda #0
    sta p1_duck
    sta p2_duck

    ; MAX JUMP HEIGHTS
    lda #32
    sta p1_max_y
    lda #158
    sta p2_max_y

    ; Set the sprite attributes
    ; P1__________________________________________________________
    lda p1_min_y
    ; Set sprite y
    sta oam
    ; Set sprite tile
    lda #105
    sta oam + 1
    ; Set sprite attributes
    lda #0
    sta oam + 2
    ; Set sprite x
    lda #48
    sta oam + 3

    lda p1_min_y
    lda p1_min_y
    ; Set sprite y
    sta oam + 4
    ; Set sprite tile
    lda #106
    sta oam + 4 + 1
    ; Set sprite attributes
    lda #$00000011
    sta oam + 4 + 2
    ; Set sprite x
    lda #56
    lda #56
    sta oam + 4 + 3

    lda p1_min_y
    sec
    sbc #8
    lda p1_min_y
    sec
    sbc #8
    ; Set sprite y
    sta oam + 8
    ; Set sprite tile
    lda #102
    sta oam + 8 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 8 + 2
    ; Set sprite x
    lda #48
    sta oam + 8 + 3

    lda p1_min_y
    sec
    sbc #8
    ; Set sprite y
    sta oam + 12
    ; Set sprite tile
    lda #103
    sta oam + 12 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 12 + 2
    ; Set sprite x
    lda #56
    sta oam + 12 + 3

    lda p1_min_y
    sec
    sbc #16
    ; Set sprite y
    sta oam + 16
    ; Set sprite tile
    lda #255
    sta oam + 16 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 16 + 2
    ; Set sprite x
    lda #48
    sta oam + 16 + 3

    lda p1_min_y
    sec
    sbc #16
    ; Set sprite y
    sta oam + 20
    ; Set sprite tile
    lda #100
    sta oam + 20 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 20 + 2
    ; Set sprite x
    lda #56
    sta oam + 20 + 3

    lda p1_min_y
    ; Set sprite y
    sta oam + 24
    ; Set sprite tile
    lda #255
    sta oam + 24 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 24 + 2
    ; Set sprite x
    lda #64
    sta oam + 24 + 3

    lda p1_min_y
    sec
    sbc #8
    ; Set sprite y
    sta oam + 28
    ; Set sprite tile
    lda #104
    sta oam + 28 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 28 + 2
    ; Set sprite x
    lda #64
    sta oam + 28 + 3

    lda p1_min_y
    sec
    sbc #16
    ; Set sprite y
    sta oam + 32
    ; Set sprite tile
    lda #101
    sta oam + 32 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 32 + 2
    ; Set sprite x
    lda #64
    sta oam + 32 + 3

    lda p1_min_y
    ; Set sprite y
    sta oam + 36
    ; Set sprite tile
    lda #119
    sta oam + 36 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 36 + 2
    ; Set sprite x
    lda #72
    sta oam + 36 + 3

    lda p1_min_y
    sec
    sbc #8
    ; Set sprite y
    sta oam + 40
    ; Set sprite tile
    lda #117
    sta oam + 40 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 40 + 2
    ; Set sprite x
    lda #72
    sta oam + 40 + 3
    ;P1__________________________________________________________

    ; P2__________________________________________________________
    lda p2_min_y
    ; Set sprite y
    sta oam + 44
    ; Set sprite tile
    lda #105
    sta oam + 44 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 44 + 2
    ; Set sprite x
    lda #48
    sta oam + 44 + 3

    lda p2_min_y
    ; Set sprite y
    sta oam + 48
    ; Set sprite tile
    lda #106
    sta oam + 48 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 48 + 2
    ; Set sprite x
    lda #56
    sta oam + 48 + 3

    lda p2_min_y
    sec
    sbc #8
    ; Set sprite y
    sta oam + 52
    ; Set sprite tile
    lda #102
    sta oam + 52 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 52 + 2
    ; Set sprite x
    lda #48
    sta oam + 52 + 3

    lda p2_min_y
    sec
    sbc #8
    ; Set sprite y
    sta oam + 56
    ; Set sprite tile
    lda #103
    sta oam + 56 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 56 + 2
    ; Set sprite x
    lda #56
    sta oam + 56 + 3

    lda p2_min_y
    sec
    sbc #16
    ; Set sprite y
    sta oam + 60
    ; Set sprite tile
    lda #255
    sta oam + 60 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 60 + 2
    ; Set sprite x
    lda #48
    sta oam + 60 + 3

    lda p2_min_y
    sec
    sbc #16
    ; Set sprite y
    sta oam + 64
    ; Set sprite tile
    lda #100
    sta oam + 64 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 64 + 2
    ; Set sprite x
    lda #56
    sta oam + 64 + 3

    lda p2_min_y
    ; Set sprite y
    sta oam + 68
    ; Set sprite tile
    lda #255
    sta oam + 68 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 68 + 2
    ; Set sprite x
    lda #64
    sta oam + 68 + 3

    lda p2_min_y
    sec
    sbc #8
    ; Set sprite y
    sta oam + 72
    ; Set sprite tile
    lda #104
    sta oam + 72 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 72 + 2
    ; Set sprite x
    lda #64
    sta oam + 72 + 3

    lda p2_min_y
    sec
    sbc #16
    ; Set sprite y
    sta oam + 76
    ; Set sprite tile
    lda #101
    sta oam + 76 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 76 + 2
    ; Set sprite x
    lda #64
    sta oam + 76 + 3

    lda p2_min_y
    ; Set sprite y
    sta oam + 80
    ; Set sprite tile
    lda #119
    sta oam + 80 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 80 + 2
    ; Set sprite x
    lda #72
    sta oam + 80 + 3

    lda p2_min_y
    sec
    sbc #8
    ; Set sprite y
    sta oam + 84
    ; Set sprite tile
    lda #117
    sta oam + 84 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 84 + 2
    ; Set sprite x
    lda #72
    sta oam + 84 + 3
    ;P2__________________________________________________________

    ; set initial x scroll value as zero
    ldx #0
    stx camera_x
    ldx #$00
    stx current_nametable

    

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



jsr init_variables

jsr display_game_screen

jsr ppu_update

jsr horizontal_scrollling

titleloop:
    jsr gamepad_poll
    lda gamepad
    and #PAD_A|PAD_B|PAD_START|PAD_SELECT
    beq titleloop

    lda time
    sta seed_0
    lda time+1
    sta seed_0+1
    jsr randomize
    sbc time+1
    sta seed_2
    jsr randomize
    sbc time
    sta seed_2+1

    lda #1
    sta is_game_in_main

mainloop:

    lda nmi_ready
    cmp #0
    bne mainloop

    lda time
    cmp lasttime
    beq mainloop
    sta lasttime

    ; Only allow input if the player is on the ground
    lda oam
    cmp p1_min_y
    bcc NOT_INPUT

    jsr gamepad_poll
    lda gamepad
    and #PAD_U
    ; Is up pressed?
    beq GAMEPAD_NOT_UP
    ; Jump
    lda #$FF
    sta p1_dy
    
GAMEPAD_NOT_UP:
    lda gamepad
    and #PAD_D
    ; Is down pressed?
    beq GAMEPAD_NOT_DOWN
    ; duck and change sprite location
    jsr player_duck

    jmp NOT_INPUT

GAMEPAD_NOT_DOWN:
    jsr player_unduck

NOT_INPUT:
    ; If dy is 1, add 1 = move down
    ; If dy is 255, subtract 1 = move up    
    lda p1_dy
    cmp #$FF
    beq MOVE_UP
    cmp #1
    beq MOVE_DOWN

MOVE_DOWN:
    lda oam
    ; Is the y position min?
    cmp p1_min_y
    ; If oam is at min or smaller, don't add
    bcs FLIP_DY

    ; Add 4 to the y position
    lda oam
    clc
    adc jmp_speed
    sta oam
    lda oam + 4
    clc
    adc jmp_speed
    sta oam + 4
    lda oam + 8
    clc
    adc jmp_speed
    sta oam + 8
    lda oam + 12
    clc
    adc jmp_speed
    sta oam + 12
    lda oam + 16
    clc
    adc jmp_speed
    sta oam + 16
    lda oam + 20
    clc
    adc jmp_speed
    sta oam + 20
    lda oam + 24
    clc
    adc jmp_speed
    sta oam + 24
    lda oam + 28
    clc
    adc jmp_speed
    sta oam + 28
    lda oam + 32
    clc
    adc jmp_speed
    sta oam + 32
    lda oam + 36
    clc
    adc jmp_speed
    sta oam + 36
    lda oam + 40
    clc
    adc jmp_speed
    sta oam + 40
    jmp CONTINUE

FLIP_DY:
    ; Flip the player direction
    clc
    lda #1
    sta p1_dy
    jmp CONTINUE

MOVE_UP:
    lda oam
    ; Is the y position max or bigger?
    clc
    cmp p1_max_y
    ; If oam is at max, don't subtract
    bcc FLIP_DY

    ; Subtract 4 from the y position
    lda oam
    sec
    sbc jmp_speed
    sta oam
    lda oam + 4
    sec
    sbc jmp_speed
    sta oam + 4
    lda oam + 8
    sec
    sbc jmp_speed
    sta oam + 8
    lda oam + 12
    sec
    sbc jmp_speed
    sta oam + 12
    lda oam + 16
    sec
    sbc jmp_speed
    sta oam + 16
    lda oam + 20
    sec
    sbc jmp_speed
    sta oam + 20
    lda oam + 24
    sec
    sbc jmp_speed
    sta oam + 24
    lda oam + 28
    sec
    sbc jmp_speed
    sta oam + 28
    lda oam + 32
    sec
    sbc jmp_speed
    sta oam + 32
    lda oam + 36
    sec
    sbc jmp_speed
    sta oam + 36
    lda oam + 40
    sec
    sbc jmp_speed
    sta oam + 40
    jmp CONTINUE

CONTINUE:
    lda #1
    sta nmi_ready
    ;jsr horizontal_scrollling
    jmp mainloop
.endproc

;**************************************************************
; Ducking code and sprite change
;**************************************************************
.segment "CODE"
.proc player_duck
    ; nose tiles
    lda p1_min_y
    ; Set sprite y
    sta oam + 36
    ; Set sprite tile
    lda #1
    sta oam + 36 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 36 + 2
    ; Set sprite x
    lda #72
    sta oam + 36 + 3

    lda p1_min_y
    sec
    sbc #8
    ; Set sprite y
    sta oam + 40
    ; Set sprite tile
    lda #1
    sta oam + 40 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 40 + 2
    ; Set sprite x
    lda #72
    sta oam + 40 + 3
    
    ; top head removes
    lda p1_min_y
    sec
    sbc #16
    ; Set sprite y
    sta oam + 16
    ; Set sprite tile
    lda #0
    sta oam + 16 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 16 + 2
    ; Set sprite x
    lda #48
    sta oam + 16 + 3

    lda p1_min_y
    sec
    sbc #16
    ; Set sprite y
    sta oam + 20
    ; Set sprite tile
    lda #0
    sta oam + 20 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 20 + 2
    ; Set sprite x
    lda #56
    sta oam + 20 + 3
    
    lda p1_min_y
    sec
    sbc #16
    ; Set sprite y
    sta oam + 32
    ; Set sprite tile
    lda #0
    sta oam + 32 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 32 + 2
    ; Set sprite x
    lda #64
    sta oam + 32 + 3

    lda #1
    sta p1_duck
    rts
.endproc

.segment "CODE"
.proc player_unduck
    lda p1_duck
    cmp #0
    beq RETURN

    ; nose tiles
    lda p1_min_y
    ; Set sprite y
    sta oam + 36
    ; Set sprite tile
    lda #0
    sta oam + 36 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 36 + 2
    ; Set sprite x
    lda #72
    sta oam + 36 + 3

    lda p1_min_y
    sec
    sbc #8
    ; Set sprite y
    sta oam + 40
    ; Set sprite tile
    lda #0
    sta oam + 40 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 40 + 2
    ; Set sprite x
    lda #72
    sta oam + 40 + 3
    
    ; top head removes
    lda p1_min_y
    sec
    sbc #16
    ; Set sprite y
    sta oam + 16
    ; Set sprite tile
    lda #1
    sta oam + 16 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 16 + 2
    ; Set sprite x
    lda #48
    sta oam + 16 + 3

    lda p1_min_y
    sec
    sbc #16
    ; Set sprite y
    sta oam + 20
    ; Set sprite tile
    lda #1
    sta oam + 20 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 20 + 2
    ; Set sprite x
    lda #56
    sta oam + 20 + 3
    
    lda p1_min_y
    sec
    sbc #16
    ; Set sprite y
    sta oam + 32
    ; Set sprite tile
    lda #1
    sta oam + 32 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 32 + 2
    ; Set sprite x
    lda #64
    sta oam + 32 + 3

    lda #0
    sta p1_duck
    rts

RETURN:
    rts
.endproc

;**************************************************************
; randomizer code
;**************************************************************
.segment "CODE"
.proc randomize
    lda seed_0
    lsr
    rol seed_0+1
    BCC @noeor
    eor #$B4
@noeor:
    sta seed_0
    eor seed_0+1
    rts
.endproc

.segment "CODE"
.proc rand
    jsr rand64k
    jsr rand32k
    lda seed_0+1
    eor seed_2+1
    tay
    lda seed_0
    eor seed_2
    rts
.endproc

.segment "CODE"
.proc rand64k
    lda seed_0+1
    asl
    asl 
    eor seed_0+1
    asl
    eor seed_0+1
    asl
    asl
    eor seed_0+1
    asl
    rol seed_0
    rol seed_0+1
    rts
.endproc

.segment "CODE"
.proc rand32k
    lda seed_2+1
    asl
    eor seed_2+1
    asl
    asl
    ror seed_2
    rol seed_2+1
    rts
.endproc