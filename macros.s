
;******************************************************************************
; Set the ram address pointer (destination) to the specified address
;******************************************************************************
.macro assign_address_to_ram destination, address

   lda #<address
   sta destination + 0
   lda #>address
   sta destination + 1

.endmacro


;******************************************************************************
; Set the vram address pointer to the specified address
;******************************************************************************
.macro vram_set_address newaddress

   lda PPU_STATUS
   lda #>newaddress
   sta PPU_VRAM_ADDRESS2
   lda #<newaddress
   sta PPU_VRAM_ADDRESS2

.endmacro

;******************************************************************************
; clear the vram address pointer
;******************************************************************************
.macro vram_clear_address

   lda #0
   sta PPU_VRAM_ADDRESS2
   sta PPU_VRAM_ADDRESS2

.endmacro
