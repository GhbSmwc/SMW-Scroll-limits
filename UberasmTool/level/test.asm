incsrc "../ScrollLimitsDefines/Defines.asm"

load:
	;LDA #$00
	;STA !Freeram_FlipScreenAreaIdentifier		;\Don't trigger scrolling effect
	;STA !Freeram_FlipScreenAreaIdentifierPrev	;/
	;LDA #$01					;\Apply scroll barriers
	;STA !Freeram_ScrollLimitsFlag			;/
	;STA !Freeram_DisableBarrier			;>Disable screen barriers preventing Mario from going off the edges.
	;REP #$20
	;;You may have to trial and error fiddling this so that layer 1 or 2
	;;not to snap during the level fading after loading. An easy method,
	;;is by using a debugger, and look at the values of $1A-$20 AFTER the
	;;snapping occurs to get its position, and use that number here to set
	;;it so that it doesn't appear to jump on its XY position.
	;	LDA #$0000 : STA $1A : STA $1462|!addr		;>Layer 1 X position
	;	LDA #$00C0 : STA $1C : STA $1464|!addr		;>Layer 1 Y position
	;	;LDA #$00C0 : STA $1E : STA $1466|!addr		;>Layer 2 X position
	;	LDA #$0060 : STA $20 : STA $1468|!addr		;>Layer 2 Y position
	;	STZ $1417|!addr					;>Fix layer 2 being 1 tile lower than it should
	;LDA #$0000 : STA !Freeram_ScrollLimitsBoxXPosition : STA $1A : STA $1462
	;LDA #($0000*16) : STA !Freeram_ScrollLimitsBoxYPosition
	;LDA #$0080 : STA !Freeram_ScrollLimitsAreaWidth
	;LDA #($000C-$0000)*16 : STA !Freeram_ScrollLimitsAreaHeight
	;SEP #$20
	
	LDA #$01
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
	JSL LibraryScrollLimits_IdentifyWhichBorder
	JSL LibraryScrollLimits_SetScrollBorder
	LDA !Freeram_FlipScreenAreaIdentifier
	STA !Freeram_FlipScreenAreaIdentifierPrev
	JSL LibraryScrollLimits_ForceScreenWithinLimits
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
;Scroll limit box attributes, each index is each screen area.
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