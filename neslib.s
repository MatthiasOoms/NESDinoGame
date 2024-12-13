;******************************************************************
; neslib.s: NES Function Library
;******************************************************************

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


;PPU control register masks used for setting the PPU control registers: 

;nametable locations
NT_2000 = $00
NT_2400 = $01
NT_2800 = $02
NT_2C00 = $03

VRAM_DOWN = $04 ; increment VRAM pointer by row

OBJ_0000 = $00 
OBJ_1000 = $08
OBJ_8X16 = $20

BG_0000 = $00 ; 
BG_1000 = $10

VBLANK_NMI = $80 ; enable NMI

BG_OFF = $00 ; turn background off
BG_CLIP = $08 ; clip background
BG_ON = $0A ; turn background on

OBJ_OFF = $00 ; turn objects off
OBJ_CLIP = $10 ; clip objects
OBJ_ON = $14 ; turn objects on


;useful nametable addresses
NAME_TABLE_0_ADDRESS = $2000
ATTRIBUTE_TABLE_0_ADDRESS = $23C0
NAME_TABLE_1_ADDRESS = $2400
ATTRIBUTE_TABLE_1_ADDRESS = $27C0


.segment "ZEROPAGE"

nmi_ready:		.res 1 ; set to 1 to push a PPU frame update, 
					   ;        2 to turn rendering off next NMI
ppu_ctl0:		.res 1 ; PPU Control Register 2 Value
ppu_ctl1:		.res 1 ; PPU Control Register 2 Value


.include "macros.s"


;*****************************************************************
; wait_frame: waits until the next NMI 
;*****************************************************************
.segment "CODE"
.proc wait_frame
	inc nmi_ready
    @loop:
	    lda nmi_ready
	    bne @loop
	    rts
.endproc

;*****************************************************************
; ppu_update: waits until next NMI and turns rendering on (if not already)
;*****************************************************************
.segment "CODE"
.proc ppu_update
    lda ppu_ctl0
    ora #VBLANK_NMI
    sta ppu_ctl0
    ora #OBJ_ON|BG_ON

    sta PPU_CONTROL
    lda ppu_ctl1
    ora #OBJ_ON|BG_ON
    sta ppu_ctl1
    jsr wait_frame
    rts
.endproc

;*****************************************************************
; ppu_off: waits until next NMI and turns rendering off
; (now safe to write PPU directly via PPU_VRAM_IO)
;*****************************************************************
.segment "CODE"
.proc ppu_off
    jsr wait_frame
    lda ppu_ctl0
    and #%01111111
    sta ppu_ctl0
    sta PPU_CONTROL
    lda ppu_ctl1
    and #%11100001
    sta ppu_ctl1
    sta PPU_MASK
    rts
.endproc

;*****************************************************************
; clear nametable at 2000
;*****************************************************************
.segment "CODE"
.proc clear_nametable
    lda PPU_STATUS
    vram_set_address (NAME_TABLE_0_ADDRESS)

    lda #255
    ldy #30

    rowloop:
        ldx #32
        columnloop:
            sta PPU_VRAM_IO
            dex
            bne columnloop
        dey
        bne rowloop
    

    lda #0
    ldx #64
    loop:
        sta PPU_VRAM_IO
        dex
        bne loop

    lda PPU_STATUS
    vram_set_address (NAME_TABLE_1_ADDRESS)

    lda #255
    ldy #30

    rowloop1:
        ldx #32
        columnloop1:
            sta PPU_VRAM_IO
            dex
            bne columnloop1
        dey
        bne rowloop1
    

    lda #0
    ldx #64
    loop1:
        sta PPU_VRAM_IO
        dex
        bne loop1


    rts
.endproc



;*****************************************************************
; write_text . display text on screen
; text_address - address of text, set beforehand
; set ppu address before calling this function
;*****************************************************************

.segment "ZEROPAGE"

text_address:	.res 2

.segment "CODE"
.proc write_text
	ldy #0
loop:
	lda (text_address), y 
    cmp #255
	beq exit ; exit if equal to 255
	sta PPU_VRAM_IO
	iny
	jmp loop
exit:
	rts
.endproc


;*****************************************************************
; make this part of background blank
; set ppu address before calling this function
;*****************************************************************


.segment "CODE"
.proc clear_background_line
    
    lda #0
	ldy #32
loop:
	beq exit ; exit if equal to 0
	sta PPU_VRAM_IO
	dey
	jmp loop
exit:
	rts
.endproc
