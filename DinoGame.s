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

; randomizer seeds
seed_0: .res 2
seed_2: .res 2

; Y position of the players
p1_min_y: .res 1

; Max Y position of the players
p1_max_y: .res 1

; Y velocity of the players ; $FF = jumping ; $01 = falling/not jumping
p1_dy: .res 1

jmp_speed: .res 1

; x coordinate of camera
camera_x: .res 1
current_nametable: .res 1
global_speed: .res 1
global_clock: .res 1
global_clock_big: .res 1
placeholder: .res 1

; time variables
time: .res 2
lasttime: .res 1

p1_duck: .res 1

; Obstacle x pos
obstacle1_x: .res 1
obstacle2_x: .res 1
obstacle3_x: .res 1

; Obstacle type (1 = small cactus, 2 = big cactus, 3 = bird)
obstacle1_type: .res 1
obstacle2_type: .res 1
obstacle3_type: .res 1


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
.byte 75, 75, 75, 75, 78, 75, 75, 75, 75, 78, 79, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 255

horizon_subline_one:
.byte 0, 0, 0, 0, 76, 0, 0, 77, 76, 0, 0, 0, 0, 0, 0, 80, 76, 77, 0, 0, 0, 0, 0, 0, 80, 81, 77, 0, 0, 0, 81, 76, 0, 255

horizon_line_two:
.byte 75, 75, 75, 75, 75, 75, 75, 75, 75, 78, 79, 75, 75, 75, 75, 75, 75, 75, 75, 75, 78, 75, 75, 75, 75, 78, 79, 75, 75, 75, 75, 75, 75

horizon_subline_two:
.byte 0, 0, 0, 0, 76, 0, 0, 77, 76, 0, 0, 0, 0, 0, 0, 80, 76, 77, 0, 0, 0, 0, 0, 0, 80, 81, 77, 0, 0, 0, 81, 76, 0, 255



game_title_text:
.byte 3, 8, 18, 15, 13, 5, 0, 4, 9, 14, 15, 0, 7, 1, 13, 5, 255

by_text:
.byte 2, 25, 255

matt_name_text:
.byte 13, 1, 20, 20, 8, 9, 1, 19, 0, 15, 15, 13, 19, 255

yenzo_name_text:
.byte 25, 5, 14, 26, 15, 0, 4, 5, 22, 15, 19, 255

hades_name_text:
.byte 8, 1, 4, 5, 19, 0, 19, 16, 5, 18, 1, 14, 19, 11, 1, 25, 1, 255

press_to_play_text:
.byte 16, 18, 5, 19, 19, 0, 1, 0, 20, 15, 0, 16, 12, 1, 25, 255

gameover_text:
.byte 7, 1, 13, 5, 0, 15, 22, 5, 18, 255



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

         lda camera_x
         clc
         adc global_speed
         sta camera_x

         bcc ending

        ; check if nametable needs switching
         lda current_nametable
         cmp #0

         bne firsttable
            lda #1
            sta current_nametable
            jmp ending

        firsttable:
            lda #0
            sta current_nametable
            jmp ending


        ending:
    rts
.endproc


;***************************************************************
; display game screen
;***************************************************************
.segment "CODE"
.proc display_start_game_screen

    vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32)
	assign_address_to_ram text_address, horizon_line_one
	jsr write_text

    vram_set_address (NAME_TABLE_0_ADDRESS + 21 * 32)
	assign_address_to_ram text_address, horizon_subline_one
	jsr write_text

    vram_set_address (NAME_TABLE_1_ADDRESS + 20 * 32)
	assign_address_to_ram text_address, horizon_line_two
	jsr write_text

    vram_set_address (NAME_TABLE_1_ADDRESS + 21 * 32)
	assign_address_to_ram text_address, horizon_subline_two
	jsr write_text

    

    ; Write our game title text
	vram_set_address (NAME_TABLE_0_ADDRESS +  32 + 2)
	assign_address_to_ram text_address, game_title_text
	jsr write_text

    ; Write by text
	vram_set_address (NAME_TABLE_0_ADDRESS + 2 * 32 + 2)
	assign_address_to_ram text_address, by_text
	jsr write_text

    
    ; Write yenzo name
	vram_set_address (NAME_TABLE_0_ADDRESS + 3 * 32 + 2)
	assign_address_to_ram text_address, yenzo_name_text
	jsr write_text

    ; Write matt name
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 2)
	assign_address_to_ram text_address, matt_name_text
	jsr write_text


    ; Write hades name
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 2)
	assign_address_to_ram text_address, hades_name_text
	jsr write_text


    ; Write press a to play
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 2)
	assign_address_to_ram text_address, press_to_play_text
	jsr write_text

    rts
.endproc

;***************************************************************
; display death screen
;***************************************************************
.segment "CODE"
.proc display_gameover_screen

    ;draw dead dino
    ;oam = left foot
    ;Set sprite tile
    lda #104
    sta oam + 1

    ;oam + 4 = right foot
    ; Set sprite tile
    lda #105
    sta oam + 4 + 1

    ;oam + 8 = tail
    ; Set sprite tile
    lda #102
    sta oam + 8 + 1

    ;oam + 12 = middle body
    ; Set sprite tile
    lda #103
    sta oam + 12 + 1

    ;oam + 16 = empty left of head
    ; Set sprite tile
    lda #0
    sta oam + 16 + 1

    ;oam + 20 = left head
    ; Set sprite tile
    lda #110
    sta oam + 20 + 1

    ;oam + 24 = empty right of feet
    ; Set sprite tile
    lda #0
    sta oam + 24 + 1

    ;oam + 28 = hands
    ; Set sprite tile
    lda #111
    sta oam + 28 + 1

    ;oam + 32 = right head
    ; Set sprite tile
    lda #101
    sta oam + 32 + 1

    ;oam + 36 = bottom ducking head
    ; Set sprite tile
    lda #0
    sta oam + 36 + 1

    ;oam + 40 = top ducking head
    ; Set sprite tile
    lda #0
    sta oam + 40 + 1


    ;for the sake of simplicity, just stop scrolling and reset the background
    lda #0
    sta global_speed
    lda #0
    sta camera_x
    lda #$00
    sta current_nametable


    ; Write game over text
	vram_set_address (NAME_TABLE_0_ADDRESS +  6 * 32 + 2 + 9)
	assign_address_to_ram text_address, gameover_text
	jsr write_text


    ; Write press a to play
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 2 + 6)
	assign_address_to_ram text_address, press_to_play_text
	jsr write_text

    rts
.endproc

;***************************************************************
; clear start screen text
;***************************************************************
.segment "CODE"
.proc clear_gamestart_texts

    ; clear our game title text
	vram_set_address (NAME_TABLE_0_ADDRESS + 1 * 32)
	jsr clear_background_line


    ; clear by text
	vram_set_address (NAME_TABLE_0_ADDRESS + 2 * 32)
	jsr clear_background_line

    
    ; clear yenzo name
	vram_set_address (NAME_TABLE_0_ADDRESS + 3 * 32)
	jsr clear_background_line



    ; clear matt name
	vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32)
	jsr clear_background_line



    ; clear hades name
	vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32)
	jsr clear_background_line


    ; clear instruction 
	vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32)
	jsr clear_background_line



    rts


.endproc


;***************************************************************
; clear gameover screen text
;***************************************************************
.segment "CODE"
.proc clear_gameover_texts


    ; game over text
	vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32)
	jsr clear_background_line

    ; oress a text
	vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32)
	jsr clear_background_line

    rts


.endproc


;***************************************************************
; update score
;***************************************************************
.segment "CODE"
.proc update_score

    ; 27 is 0 in the charset
    ; 36 is 9 in the charset

    lda global_speed
    sta placeholder

    loop:
    ;right most score char plus the index for the used tile
    ldx #188 + 1

    subloop:
    ;if it is not a nine yet, simply increment this number
    ldy oam, X
    cpy #36
    bne incrementchar
    ;if it is a nine, set it to zero
    lda #27
    sta oam, X
    ;shift the accumulator to work with the next score character by subtracting four
    txa
    sec
    sbc #4
    tax
    ;go check if the new score character is a zero or not
    jmp subloop

    ;increment the tile used to the next value
    incrementchar:
    inc oam, X

    ldx placeholder
    dex
    stx placeholder
    cpx #0
    bne loop

    rts

.endproc

;***************************************************************
; update score
;***************************************************************
.segment "CODE"
.proc record_new_highscore

    ;compare sprite tiles - if there is ever an inequality, that decides which number is bigger
    ;eight numbers to iterate over
    ;current score stored from 160
    ;biggest score stored from 220
    ldy #0

    ldx #160 + 1

    loop:
        lda oam + 60, X
        cmp oam, X
        beq checknext
        bmi store

        jmp end
            
        checknext:
            ;increment the x and then compare next two numbers
            inx
            inx
            inx
            inx

            iny 
            cpy #9
            bmi  loop


    store:

        ldy #0

        ldx #160 + 1

            storeloop:

                lda oam, X
                sta oam + 60, X
                
                inx
                inx
                inx
                inx

                iny 
                cpy #9
                bmi  storeloop



    end:


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


;***************************************************************
; init_variables: initialises various values in zero page memory
;***************************************************************
.segment "CODE"
.proc init_variables
    ; Set the jump speed
    lda #3
    sta jmp_speed

    ; MIN JUMP HEIGHTS
    lda #162
    sta p1_min_y


    ; JUMP VELOCITIES
    lda #1
    sta p1_dy

    ; DUCK BOOLS
    lda #0
    sta p1_duck

    ; MAX JUMP HEIGHTS
    lda #96
    sta p1_max_y


    ; Set the sprite attributes
    ; oam = left foot
    ; oam + 4 = right foot
    ; oam + 8 = tail
    ; oam + 12 = middle body
    ; oam + 16 = empty left of head
    ; oam + 20 = left head
    ; oam + 24 = empty right of feet
    ; oam + 28 = hands
    ; oam + 32 = right head
    ; oam + 36 = bottom ducking head
    ; oam + 40 = top ducking head
    ; oam + 88 = obstacle 1
; P1__________________________________________________________
    lda p1_min_y
    ; Set sprite y      oam = left foot
    sta oam
    ; Set sprite tile
    lda #104
    sta oam + 1
    ; Set sprite attributes
    lda #0
    sta oam + 2
    ; Set sprite x
    lda #48
    sta oam + 3

    lda p1_min_y
    ; Set sprite y      oam + 4 = right foot
    sta oam + 4
    ; Set sprite tile
    lda #105
    sta oam + 4 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 4 + 2
    ; Set sprite x
    lda #56
    sta oam + 4 + 3

    lda p1_min_y
    sec
    sbc #8
    ; Set sprite y      oam + 8 = tail
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
    ; Set sprite y      oam + 12 = middle body
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
    ; Set sprite y      oam + 16 = empty left of head
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
    ; Set sprite y      oam + 20 = left head
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
    ; Set sprite y      oam + 24 = empty right of feet
    sta oam + 24
    ; Set sprite tile
    lda #0
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
    ; Set sprite y      oam + 28 = hands
    sta oam + 28
    ; Set sprite tile
    lda #106
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
    ; Set sprite y      oam + 32 = right head
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
    ; Set sprite y      oam + 36 = bottom ducking head
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
    ; Set sprite y      oam + 40 = top ducking head
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
    ;P1__________________________________________________________

; highscore__________________________________________________________
    ;h
    lda #8
    ; Set sprite y
    sta oam + 192
    ; Set sprite tile
    lda #8
    sta oam + 192 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 192 + 2
    ; Set sprite x
    lda #22 * 8
    sta oam + 192 + 3

    ;i
    lda #8
    ; Set sprite y
    sta oam + 196
    ; Set sprite tile
    lda #9
    sta oam + 196 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 196 + 2
    ; Set sprite x
    lda #23 * 8
    sta oam + 196 + 3

    ;s
    lda #8
    ; Set sprite y
    sta oam + 200
    ; Set sprite tile
    lda #19
    sta oam + 200 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 200 + 2
    ; Set sprite x
    lda #24 * 8
    sta oam + 200 + 3

    ;c
    lda #8
    ; Set sprite y
    sta oam + 204
    ; Set sprite tile
    lda #3
    sta oam + 204 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 204 + 2
    ; Set sprite x
    lda #25 * 8
    sta oam + 204 + 3


    ;0
    lda #8
    ; Set sprite y
    sta oam + 208
    ; Set sprite tile
    lda #15
    sta oam + 208 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 208 + 2
    ; Set sprite x
    lda #26 * 8
    sta oam + 208 + 3

    ;r
    lda #8
    ; Set sprite y
    sta oam + 212
    ; Set sprite tile
    lda #18
    sta oam + 212 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 212 + 2
    ; Set sprite x
    lda #27 * 8
    sta oam + 212 + 3

    ;e
    lda #8
    ; Set sprite y
    sta oam + 216
    ; Set sprite tile
    lda #5
    sta oam + 216 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 216 + 2
    ; Set sprite x
    lda #28 * 8
    sta oam + 216 + 3

    ;BEST HIGHSCORE IN THIS SESSION
    ;0 one
    lda #18
    ; Set sprite y
    sta oam + 220
    ; Set sprite tile
    lda #27
    sta oam + 220 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 220 + 2
    ; Set sprite x
    lda #21 * 8
    sta oam + 220 + 3
    
    ;0 two
    lda #18
    ; Set sprite y
    sta oam + 224
    ; Set sprite tile
    lda #27
    sta oam + 224 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 224 + 2
    ; Set sprite x
    lda #22 * 8
    sta oam + 224 + 3

    ;0 three
    lda #18
    ; Set sprite y
    sta oam + 228
    ; Set sprite tile
    lda #27
    sta oam + 228 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 228 + 2
    ; Set sprite x
    lda #23 * 8
    sta oam + 228 + 3

    ;0 four
    lda #18
    ; Set sprite y
    sta oam + 232
    ; Set sprite tile
    lda #27
    sta oam + 232 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 232 + 2
    ; Set sprite x
    lda #24 * 8
    sta oam + 232 + 3

    ;0 five
    lda #18
    ; Set sprite y
    sta oam + 236
    ; Set sprite tile
    lda #27
    sta oam + 236 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 236 + 2
    ; Set sprite x
    lda #25 * 8
    sta oam + 236 + 3

    ;0 six
    lda #18
    ; Set sprite y
    sta oam + 240
    ; Set sprite tile
    lda #27
    sta oam + 240 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 240 + 2
    ; Set sprite x
    lda #26 * 8
    sta oam + 240 + 3

    ;0 seven
    lda #18
    ; Set sprite y
    sta oam + 244
    ; Set sprite tile
    lda #27
    sta oam + 244 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 244 + 2
    ; Set sprite x
    lda #27 * 8
    sta oam + 244 + 3

    ;0 eight
    lda #18
    ; Set sprite y
    sta oam + 248
    ; Set sprite tile
    lda #27
    sta oam + 248 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 248 + 2
    ; Set sprite x
    lda #28 * 8
    sta oam + 248 + 3

    ; current score for this run
    ;0 one
    lda #28
    ; Set sprite y
    sta oam + 160
    ; Set sprite tile
    lda #27
    sta oam + 160 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 160 + 2
    ; Set sprite x
    lda #21 * 8
    sta oam + 160 + 3
    
    ;0 two
    lda #28
    ; Set sprite y
    sta oam + 164
    ; Set sprite tile
    lda #27
    sta oam + 164 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 164 + 2
    ; Set sprite x
    lda #22 * 8
    sta oam + 164 + 3

    ;0 three
    lda #28
    ; Set sprite y
    sta oam + 168
    ; Set sprite tile
    lda #27
    sta oam + 168 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 168 + 2
    ; Set sprite x
    lda #23 * 8
    sta oam + 168 + 3

    ;0 four
    lda #28
    ; Set sprite y
    sta oam + 172
    ; Set sprite tile
    lda #27
    sta oam + 172 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 172 + 2
    ; Set sprite x
    lda #24 * 8
    sta oam + 172 + 3

    ;0 five
    lda #28
    ; Set sprite y
    sta oam + 176
    ; Set sprite tile
    lda #27
    sta oam + 176 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 176 + 2
    ; Set sprite x
    lda #25 * 8
    sta oam + 176 + 3

    ;0 six
    lda #28
    ; Set sprite y
    sta oam + 180
    ; Set sprite tile
    lda #27
    sta oam + 180 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 180 + 2
    ; Set sprite x
    lda #26 * 8
    sta oam + 180 + 3

    ;0 seven
    lda #28
    ; Set sprite y
    sta oam + 184
    ; Set sprite tile
    lda #27
    sta oam + 184 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 184 + 2
    ; Set sprite x
    lda #27 * 8
    sta oam + 184 + 3

    ;0 eight
    lda #28
    ; Set sprite y
    sta oam + 188
    ; Set sprite tile
    lda #27
    sta oam + 188 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 188 + 2
    ; Set sprite x
    lda #28 * 8
    sta oam + 188 + 3
    ; highscore__________________________________________________________

; misc__________________________________________________________

    ; set initial x scroll value as zero
    lda #0
    sta camera_x
    lda #$00
    sta current_nametable
    lda #0
    sta global_speed

    ; OBSTACLE X POS
    lda #255
    sta obstacle1_x
    sta obstacle2_x
    sta obstacle3_x

    ; OBSTACLE TYPE
    lda #1
    sta obstacle1_type
    sta obstacle2_type
    sta obstacle3_type

    ; p1_min_y - 8 = low bird flying height
    ; p1_min_y - 16 = middle bird flying height
    ; p1_min_y - 24 = top bird flying height

    ; Obstacle y pos on ground
    lda p1_min_y
    sta oam + 88
    ; Set sprite tile
    lda #1
    sta oam + 88 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 88 + 2
    ; Obstacle x pos
    lda obstacle1_x
    sta oam + 88 + 3

    ; Obstacle y pos on ground
    lda p1_min_y
    sta oam + 92
    ; Set sprite tile
    lda #0
    sta oam + 92 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 92 + 2
    ; Obstacle x pos
    lda obstacle2_x
    sta oam + 92 + 3

    ; Obstacle y pos on ground
    lda p1_min_y
    sta oam + 96
    ; Set sprite tile
    lda #0
    sta oam + 96 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 96 + 2
    ; Obstacle x pos
    lda obstacle3_x
    sta oam + 96 + 3

    ; misc__________________________________________________________


    rts
.endproc

;***************************************************************
; init_variables: initialises various values in zero page memory
;***************************************************************
.segment "CODE"
.proc reset_game
    ; Set the jump speed
    lda #3
    sta jmp_speed

    ; MIN JUMP HEIGHTS
    lda #162
    sta p1_min_y

    lda #2
    sta global_speed
    lda #0
    sta global_clock
    sta global_clock_big

    ; JUMP VELOCITIES
    lda #1
    sta p1_dy

    ; DUCK BOOLS
    lda #0
    sta p1_duck

    ; MAX JUMP HEIGHTS
    lda #96
    sta p1_max_y


    ; Set the sprite attributes
    ; oam = left foot
    ; oam + 4 = right foot
    ; oam + 8 = tail
    ; oam + 12 = middle body
    ; oam + 16 = empty left of head
    ; oam + 20 = left head
    ; oam + 24 = empty right of feet
    ; oam + 28 = hands
    ; oam + 32 = right head
    ; oam + 36 = bottom ducking head
    ; oam + 40 = top ducking head
    ; oam + 88 = obstacle 1
; P1__________________________________________________________
    lda p1_min_y
    ; Set sprite y      oam = left foot
    sta oam
    ; Set sprite tile
    lda #104
    sta oam + 1
    ; Set sprite attributes
    lda #0
    sta oam + 2
    ; Set sprite x
    lda #48
    sta oam + 3

    lda p1_min_y
    ; Set sprite y      oam + 4 = right foot
    sta oam + 4
    ; Set sprite tile
    lda #105
    sta oam + 4 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 4 + 2
    ; Set sprite x
    lda #56
    sta oam + 4 + 3

    lda p1_min_y
    sec
    sbc #8
    ; Set sprite y      oam + 8 = tail
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
    ; Set sprite y      oam + 12 = middle body
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
    ; Set sprite y      oam + 16 = empty left of head
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
    ; Set sprite y      oam + 20 = left head
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
    ; Set sprite y      oam + 24 = empty right of feet
    sta oam + 24
    ; Set sprite tile
    lda #0
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
    ; Set sprite y      oam + 28 = hands
    sta oam + 28
    ; Set sprite tile
    lda #106
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
    ; Set sprite y      oam + 32 = right head
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
    ; Set sprite y      oam + 36 = bottom ducking head
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
    ; Set sprite y      oam + 40 = top ducking head
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
    ;P1__________________________________________________________

; highscore__________________________________________________________
   
    ; current score for this run
    ;0 one
    lda #28
    ; Set sprite y
    sta oam + 160
    ; Set sprite tile
    lda #27
    sta oam + 160 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 160 + 2
    ; Set sprite x
    lda #21 * 8
    sta oam + 160 + 3
    
    ;0 two
    lda #28
    ; Set sprite y
    sta oam + 164
    ; Set sprite tile
    lda #27
    sta oam + 164 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 164 + 2
    ; Set sprite x
    lda #22 * 8
    sta oam + 164 + 3

    ;0 three
    lda #28
    ; Set sprite y
    sta oam + 168
    ; Set sprite tile
    lda #27
    sta oam + 168 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 168 + 2
    ; Set sprite x
    lda #23 * 8
    sta oam + 168 + 3

    ;0 four
    lda #28
    ; Set sprite y
    sta oam + 172
    ; Set sprite tile
    lda #27
    sta oam + 172 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 172 + 2
    ; Set sprite x
    lda #24 * 8
    sta oam + 172 + 3

    ;0 five
    lda #28
    ; Set sprite y
    sta oam + 176
    ; Set sprite tile
    lda #27
    sta oam + 176 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 176 + 2
    ; Set sprite x
    lda #25 * 8
    sta oam + 176 + 3

    ;0 six
    lda #28
    ; Set sprite y
    sta oam + 180
    ; Set sprite tile
    lda #27
    sta oam + 180 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 180 + 2
    ; Set sprite x
    lda #26 * 8
    sta oam + 180 + 3

    ;0 seven
    lda #28
    ; Set sprite y
    sta oam + 184
    ; Set sprite tile
    lda #27
    sta oam + 184 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 184 + 2
    ; Set sprite x
    lda #27 * 8
    sta oam + 184 + 3

    ;0 eight
    lda #28
    ; Set sprite y
    sta oam + 188
    ; Set sprite tile
    lda #27
    sta oam + 188 + 1
    ; Set sprite attributes
    lda #0
    sta oam + 188 + 2
    ; Set sprite x
    lda #28 * 8
    sta oam + 188 + 3
    ; highscore__________________________________________________________

; misc__________________________________________________________

    ; set initial x scroll value as zero
    lda #0
    sta camera_x
    lda #$00
    sta current_nametable
    lda #0
    sta global_speed

    ; OBSTACLE X POS
    lda #255
    sta obstacle1_x
    sta obstacle2_x
    sta obstacle3_x
    
    ; Obstacle x pos
    lda obstacle1_x
    sta oam + 88 + 3

   
    ; Obstacle x pos
    lda obstacle2_x
    sta oam + 92 + 3

    ; Obstacle x pos
    lda obstacle3_x
    sta oam + 96 + 3

    ; misc__________________________________________________________


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

    jsr display_start_game_screen


    jsr ppu_update

    titleloop:
    lda nmi_ready
    cmp #0
    bne titleloop

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

    ;clear text
    jsr clear_gamestart_texts

    ;start scrolling
    lda #2
    sta global_speed
    jsr horizontal_scrollling

    ;set nmi ready
    lda #1
    sta nmi_ready




mainloop:

    lda nmi_ready
    cmp #0
    bne mainloop

    lda time
    cmp lasttime
    beq mainloop
    sta lasttime

    jsr update_score


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
    ; Fall
    lda #1
    sta p1_dy

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
    ; Calculate next object x pos
    lda obstacle1_x
    sec 
    sbc global_speed
    sta obstacle1_x

    lda obstacle2_x
    sec
    sbc global_speed
    sta obstacle2_x

    lda obstacle3_x
    sec
    sbc global_speed
    sta obstacle3_x

    ; Obstacle x pos
    lda obstacle1_x
    sta oam + 88 + 3

    lda obstacle2_x
    sta oam + 92 + 3

    lda obstacle3_x
    sta oam + 96 + 3

    ; If player1 x pos is smaller than obstacle x pos + width
    lda obstacle1_x
    clc
    adc #16 ; Width of 2 sprites
    bcc :+
    ; If carry is set, the obstacle is too close to the right side of the screen, we just use its x pos
    lda obstacle1_x
:   ; If carry is not set, the obstacle is not too close to the right side of the screen, we use its x pos + width
    cmp oam + 3
    bcc NOT_COLLIDED

    ; If obstacle x pos is smaller than player1 x pos + width
    lda p1_duck
    cmp #0
    beq :+
    ; Ducking
    lda oam + 3
    clc
    adc #32
    jmp :++
: ; Not ducking
    lda oam + 3
    clc
    adc #24
: ; Resume
    cmp obstacle1_x
    bcc NOT_COLLIDED

    ; If player1 y pos is bigger than obstacle y pos + height
    lda oam + 88
    sec
    sbc #8 ; 1 sprite height
    cmp oam
    bcs NOT_COLLIDED

    ; If player1 y pos + height is bigger than obstacle y pos
    lda p1_duck
    cmp #0
    beq :+
    ; Ducking
    lda oam
    sec
    sbc #16 ; height while ducking
    jmp :++
: ; Not ducking
    lda oam
    sec
    sbc #24 ; height while standing
: ; Resume
    cmp oam + 88
    bcs NOT_COLLIDED

COLLIDED:
    jmp playerdied

NOT_COLLIDED:
    ; Animation update
    lda global_clock
    and #8
    bne :++

    ; Yes 8
    lda p1_duck
    cmp #1
    bne :+

    ; Ducking
    ; Change left foot tile
    lda #114
    sta oam + 1
    ; Change right foot tile
    lda #115
    sta oam + 4 + 1
    jmp :++++

:   ; Not ducking
    ; Change left foot tile
    lda #104
    sta oam + 1
    ; Change right foot tile
    lda #107
    sta oam + 4 + 1
    jmp :+++

:   ; Not 8
    lda p1_duck
    cmp #1
    bne :+

    ; Ducking
    ; Change left foot tile
    lda #120
    sta oam + 1
    ; Change right foot tile
    lda #121
    sta oam + 4 + 1
    jmp :++

:   ; Not ducking
    ; Change left foot tile
    lda #108
    sta oam + 1
    ; Change right foot tile
    lda #109
    sta oam + 4 + 1

:   ; Done

    ; Clock incremented
    inc global_clock
    ; If clock is smaller than 245
    ldx global_clock
    cpx #245
    bcc :+
    ; If clock is bigger than 245, increment global_speed
    inc global_clock_big
    ; Reset clock
    lda #0
    sta global_clock
    ldx global_clock_big
    cpx #3
    bcc :+
    inc global_speed
:
    lda #1
    sta nmi_ready
    jmp mainloop


playerdied:

    lda #1
    sta nmi_ready
    ; clear gameover texts when nmi is ready
    waittodieloop:
    lda nmi_ready
    cmp #0
    bne waittodieloop

    jsr record_new_highscore
    jsr display_gameover_screen
    jsr horizontal_scrollling

   
    lda #1
    sta nmi_ready


gameoverloop:
    jsr gamepad_poll
    lda gamepad
    and #PAD_A|PAD_B|PAD_START|PAD_SELECT
    beq gameoverloop


    ; clear gameover texts when nmi is ready
    waittorestartloop:
    lda nmi_ready
    cmp #0
    bne waittorestartloop

    ;prepare game for playing 
    jsr reset_game
    jsr clear_gameover_texts
    ;start scrolling
    lda #2
    sta global_speed
    jsr horizontal_scrollling


    jmp mainloop



.endproc

;**************************************************************
; Ducking code and sprite change
;**************************************************************
.segment "CODE"
.proc player_duck
    ; Set sprite tile       ; bottom ducking head
    lda #119
    sta oam + 36 + 1

    ; Set sprite tile       ; top ducking head
    lda #117
    sta oam + 40 + 1

    ; Set sprite tile       ; hands
    lda #116
    sta oam + 28 + 1

    ; Set sprite tile       ; empty right of feet
    lda #118
    sta oam + 24 + 1

    ; Set sprite tile       ; middle body
    lda #113
    sta oam + 12 + 1

    ; Set sprite tile       ; right foot
    lda #121
    sta oam + 4 + 1

    ; Set sprite tile       ; left foot
    lda #120
    sta oam + 1

    ; Set sprite tile       ; tail
    lda #112
    sta oam + 8 + 1

    ; Set sprite tile       ; empty left of head
    lda #0
    sta oam + 16 + 1

    ; Set sprite tile       ; left head
    lda #0
    sta oam + 20 + 1
    
    ; Set sprite tile       ; right head
    lda #0
    sta oam + 32 + 1

    lda #1
    sta p1_duck
    rts
.endproc

.segment "CODE"
.proc player_unduck
    lda p1_duck
    cmp #0
    beq RETURN

    ; Set sprite tile       ; bottom ducking head
    lda #0
    sta oam + 36 + 1
    
    ; Set sprite tile       ; top ducking head
    lda #0
    sta oam + 40 + 1

    ; Set sprite tile       ; hands
    lda #106
    sta oam + 28 + 1

    ; Set sprite tile       ; empty right of feet
    lda #0
    sta oam + 24 + 1

    ; Set sprite tile       ; middle body
    lda #103
    sta oam + 12 + 1

    ; Set sprite tile       ; right foot
    lda #105
    sta oam + 4 + 1

    ; Set sprite tile       ; left foot
    lda #104
    sta oam + 1

    ; Set sprite tile       ; tail
    lda #102
    sta oam + 8 + 1
    
    ; Set sprite tile       ; empty left of head
    lda #0
    sta oam + 16 + 1
    
    ; Set sprite tile       ; left head
    lda #100
    sta oam + 20 + 1
    
    ; Set sprite tile       ; right head
    lda #101
    sta oam + 32 + 1
    
    lda #0
    sta p1_duck
    
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