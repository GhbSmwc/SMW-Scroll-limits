incsrc "../ScrollLimitsDefines/Defines.asm"

load:
	LDA #$02						;>Nonzero value
	STA !Freeram_DisableBarrier				;>Disable barrier (without it, you cannot trigger scrolling effect on left/right side of screen)
	STA !Freeram_ScrollLimitsFlag				;>Enable scroll limits.
	JSL WriteTableAddress					;>Obtain table address
	STZ $1411|!addr						;\Just in case
	STZ $1412|!addr						;/
	JSL LibraryScrollLimits_IdentifyWhichBorder			;>What border the player is in
	LDA #$03 : STA $0C						;>Transition mode, use only these values: $02 = Transition without freeze, $03 = transition with freeze.
	JSL LibraryScrollLimits_SetScrollBorder				;>Set border attributes
	JSL LibraryScrollLimits_ForceScreenWithinIdentifiedLimits	;>Make it so that the screen is within the zone the player is in.
	REP #$20
	;Stuff you may have to fiddle around so that the background does not glitch or suddenly move when the level fully loads.
	;
	;Using $1A-$21 does not effectively work on uberasm tool (it only moves the display), so use $1462-$1469 instead (the
	;takes $1462-$1469 and transfer them to $1A-$21). Reason why this happens is that $1A-$21 is the DISPLAYED position
	;(changing these values moves the screen, but several things act as if the screen didn't move), while $1462-$1469 is
	;the INTERACTIVE position (such as auto-scroll). You DO have to write to $1A-$21 *and* $1462-$1469 if you want to initialize
	;the screen position (handled by ForceScreenWithinLimits and ForceScreenWithinIdentifiedLimits routines).
	;
	;See the readme on about backgrounds. An easy method on finding the behavior of layer 2 positioning is by wait until layer 2 jumps,
	;then set a breakpoint at $00f79d and see how it is executed (using the debugger's "step" function). By mimicking that instruction
	;here, it should ensure layer 2 is positioned correctly before it becomes visible.
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
	JSL WriteTableAddress					;>Obtain table address
	JSL LibraryScrollLimits_IdentifyWhichBorder		;>Identify what border the player is in (will set !Freeram_FlipScreenAreaIdentifier to what zone the player is in).
	LDA #$03 : STA $0C					;>Transition mode, use only these values: $02 = Transition without freeze, $03 = transition with freeze.
	JSL LibraryScrollLimits_SetScrollBorder			;>Apply the changes of the border.
	RTL
WriteTableAddress:
	LDA.b #ScreenBoundsXPositions : STA $00			;\Border attributes, from the table
	LDA.b #ScreenBoundsXPositions>>8 : STA $01		;|
	LDA.b #ScreenBoundsXPositions>>16 : STA $02		;|
	LDA.b #ScreenBoundsYPositions : STA $03			;|
	LDA.b #ScreenBoundsYPositions>>8 : STA $04		;|
	LDA.b #ScreenBoundsYPositions>>16 : STA $05		;|
	LDA.b #ScreenBoundsWidths : STA $06			;|
	LDA.b #ScreenBoundsWidths>>8 : STA $07			;|
	LDA.b #ScreenBoundsWidths>>16 : STA $08			;|
	LDA.b #ScreenBoundsHeights : STA $09			;|
	LDA.b #ScreenBoundsHeights>>8 : STA $0A			;|
	LDA.b #ScreenBoundsHeights>>16 : STA $0B		;/
	LDA.b #(ScreenBoundsYPositions-ScreenBoundsXPositions)-2 : STA $0C : STZ $0D	;>Size of the table, minus 2
	RTL

;Scroll limit box attributes, each index is each screen area.
;Make sure the number of values in each table all matches!
;
;Notes:
;-If the screen can be at the bottommost of the level and with “Allow viewing full bottom row of tiles”
; checked, it can show a row of pixels at the bottom of the screen of garbage/unloaded tiles. Therefore to avoid this, use
; these formulas instead (it is the same, but after all calculations, it is subtracted by 1):
; If the height is set to 0 (no room for moving the screen vertically)
;  YPos = (LM_CoordinateOfTopLeft_TopOrLeftmost_Screen*16)-1
; If the height isn't 0:
;  Width = ((LM_CoordinateOfTopLeft_BottomOrRightmost_Screen-LM_CoordinateOfTopLeft_TopOrLeftmost_Screen)*16)-1
;-You can only have up to 256 scroll areas, numbered from 0-255.
;-Having large number of scroll areas can cause slowdown, as every frame this loop-search the entire table.
;--You can avoid this slowdown as well as avoid the 256-limit by having separate tables reusing area IDs
;  (an example is if the player is on the 2nd half of the level, use only the second set of table). This
;  effectively limits the search loop to a smaller set of values.
;-If 2+ areas overlap, and the player is in 2+ of them, whatever is last on the table that the player is in
; will take precedence.
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
		dw ($001C*16)-1		;>$03
		dw $0000*16		;>$04
		dw $000C*16		;>$05
		dw $000C*16		;>$06
		dw $001A*16		;>$07
		dw $0000*16		;>$08
		dw $0000*16		;>$09
;Widths and heights. Easy formula if you want positions for both the top-lefts and bottom-rights.
; WidthOrHeights = (LM_CoordinateOfTopLeft_BottomOrRightmost_Screen-LM_CoordinateOfTopLeft_TopOrLeftmost_Screen)*16
; Where:
;  -LM_CoordinateOfTopLeft_TopOrLeftmost_Screen: means the top left of the screen at the leftmost
;   position possible, in block-coordinates (not pixel), either X or Y position
;  -LM_CoordinateOfTopLeft_BottomOrRightmost_Screen: means the top-left of the screen at the rightmost
;   position possible, in block-coordinates (not pixel), either X or Y position
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