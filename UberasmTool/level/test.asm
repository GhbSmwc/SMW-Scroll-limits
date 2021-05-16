incsrc "../ScrollLimitsDefines/Defines.asm"

load:
	LDA #$02
	STA !Freeram_DisableBarrier
	STA !Freeram_ScrollLimitsFlag
	LDA.b #ScreenBoundsXPositions : STA $00
	LDA.b #ScreenBoundsXPositions>>8 : STA $01
	LDA.b #ScreenBoundsXPositions>>16 : STA $02
	LDA.b #ScreenBoundsYPositions : STA $03
	LDA.b #ScreenBoundsYPositions>>8 : STA $04
	LDA.b #ScreenBoundsYPositions>>16 : STA $05
	LDA.b #ScreenBoundsWidths : STA $06
	LDA.b #ScreenBoundsWidths>>8 : STA $07
	LDA.b #ScreenBoundsWidths>>16 : STA $08
	LDA.b #ScreenBoundsHeights : STA $09
	LDA.b #ScreenBoundsHeights>>8 : STA $0A
	LDA.b #ScreenBoundsHeights>>16 : STA $0B
	LDA.b #(ScreenBoundsYPositions-ScreenBoundsXPositions)-2 : STA $0C : STZ $0D
	STZ $1411|!addr					;\Just in case
	STZ $1412|!addr					;/
	JSL LibraryScrollLimits_IdentifyWhichBorder
	LDA #$03
	STA $0C
	JSL LibraryScrollLimits_SetScrollBorder
	JSL LibraryScrollLimits_ForceScreenWithinLimits
	REP #$20
	;Stuff you may have to fiddle around so that the background does not glitch or suddenly move when the level fully loads.
	;Using $1A-$21 does not work, so use $1462-$1469 instead.
		;Layer 2 X position. Number of LSR is the scrolling rate:
		;No code = None
		;None = constant
		;LSR #1 = variable
			LDA $1462|!addr
			LSR
			STA $1466|!addr
		;Layer 2 Y position, similar to above but also uses $1417 to offset. Note that since each level entrances may have their own layer 2 Y offset,
		;you may have to add a check here to determine which offset to use.
			LDA $1464|!addr
			LSR
			CLC
			ADC $1417|!addr
			STA $1468|!addr
	SEP #$20
	RTL
main:
	LDA.b #ScreenBoundsXPositions : STA $00
	LDA.b #ScreenBoundsXPositions>>8 : STA $01
	LDA.b #ScreenBoundsXPositions>>16 : STA $02
	LDA.b #ScreenBoundsYPositions : STA $03
	LDA.b #ScreenBoundsYPositions>>8 : STA $04
	LDA.b #ScreenBoundsYPositions>>16 : STA $05
	LDA.b #ScreenBoundsWidths : STA $06
	LDA.b #ScreenBoundsWidths>>8 : STA $07
	LDA.b #ScreenBoundsWidths>>16 : STA $08
	LDA.b #ScreenBoundsHeights : STA $09
	LDA.b #ScreenBoundsHeights>>8 : STA $0A
	LDA.b #ScreenBoundsHeights>>16 : STA $0B
	LDA.b #(ScreenBoundsYPositions-ScreenBoundsXPositions)-2 : STA $0C : STZ $0D
	JSL LibraryScrollLimits_IdentifyWhichBorder
	LDA #$03 : STA $0C
	JSL LibraryScrollLimits_SetScrollBorder
	RTL
;Scroll limit box attributes, each index is each screen area (the order also corresponds).
;Make sure the number of values all matches!
;
;Easy formula to calculate where the screen should be at:
; LM_CoordinateOfTopLeft_TopOrLeftmost_Screen*16
; Where:
;  -LM_CoordinateOfTopLeft_TopOrLeftmost_Screen means the top left of the screen at the leftmost
;   position possible, in block-coordinates (not pixel), either X or Y position
;Top-left positions
	ScreenBoundsXPositions:
		dw $0000*16		;>$00
		dw $0018*16		;>$01
		dw $0028*16		;>$02
		dw $0028*16		;>$03
		dw $003C*16		;>$04
		dw $004C*16		;>$05
		dw $005C*16		;>$06
		dw $005C*16		;>$07
		dw $007C*16		;>$08
		dw $009D*16		;>$09
	ScreenBoundsYPositions:
		dw $0000*16		;>$00
		dw $0015*16		;>$01
		dw $000B*16		;>$02
		dw $001C*16		;>$03
		dw $0000*16		;>$04
		dw $000C*16		;>$05
		dw $000C*16		;>$06
		dw $001A*16		;>$07
		dw $0000*16		;>$08
		dw $0000*16		;>$09
;Widths and heights. Easy formula if you want positions for both the top-lefts and bottom-rights.
; (LM_CoordinateOfTopLeft_BottomOrRightmost_Screen-LM_CoordinateOfTopLeft_TopOrLeftmost_Screen)*16
; Where:
;  -LM_CoordinateOfTopLeft_TopOrLeftmost_Screen means the top left of the screen at the leftmost
;   position possible, in block-coordinates (not pixel), either X or Y position
;  -LM_CoordinateOfTopLeft_BottomOrRightmost_Screen means the top-left of the screen at the rightmost
;   position possible, in block-coordinates (not pixel), either X or Y position
;
	ScreenBoundsWidths:
		dw ($0008-$0000)*16	;>$00
		dw ($0018-$0018)*16	;>$01
		dw ($0028-$0028)*16	;>$02
		dw ($0046-$0028)*16	;>$03
		dw ($003C-$003C)*16	;>$04
		dw ($004C-$004C)*16	;>$05
		dw ($006C-$005C)*16	;>$06
		dw ($0063-$005C)*16	;>$07
		dw ($008D-$007C)*16	;>$08
		dw ($00AD-$009D)*16	;>$09
	ScreenBoundsHeights:
		dw ($000C-$0000)*16	;>$00
		dw ($0015-$0015)*16	;>$01
		dw ($000B-$000B)*16	;>$02
		dw ($001C-$001C)*16	;>$03
		dw ($000E-$0000)*16	;>$04
		dw ($000C-$000C)*16	;>$05
		dw ($000C-$000C)*16	;>$06
		dw ($001A-$001A)*16	;>$07
		dw ($001B-$0000)*16	;>$08
		dw ($001B-$0000)*16	;>$09