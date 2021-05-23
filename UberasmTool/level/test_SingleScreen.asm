;Note: The screen isn't a perfect square, but a 8:7 ratio (256x224), however, each zone is 256x256,
;so each zone will have a small vertical scrolling of 2 16x16 blocks, much like ALTTP.

incsrc "../ScrollLimitsDefines/Defines.asm"
load:
	LDA #$02						;>Nonzero value
	STA !Freeram_DisableBarrier				;>Disable barrier (without it, you cannot trigger scrolling effect on left/right side of screen)
	STA !Freeram_ScrollLimitsFlag				;>Enable scroll limits.
	STZ $1411|!addr						;\Just in case
	STZ $1412|!addr						;/
	JSL SingleScreen
	STZ $1A							;\Screen to be aligned to a grid of subscreens.
	STZ $1462|!addr						;/
	JSL LibraryScrollLimits_ForceScreenWithinLimits		;>Place screen to be alined with area
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
	
	JSL LibraryScrollLimits_CheckIfMarioIsOutsideZone
	BCC .NoTransition
	.Transition
		JSL SingleScreen					;>Update the borders position
		LDA #$03
		STA !Freeram_ScrollLimitsFlag
		STZ $1411|!addr					;\Prevent potential insta-scroll (found out that it runs in this order: This uberasm level code, SMW scrolling
		STZ $1412|!addr					;/code at $00F6DB, and then uberasm tool's gamemode 14).
	.NoTransition
	RTL
SingleScreen:
	REP #$20
	LDA $94							;\Mario's X position center of his body
	CLC							;|
	ADC #$0008						;/
	AND #$FF00						;>Round down to what horizontal position, in screen borders
	STA !Freeram_ScrollLimitsBoxXPosition			;>Set border to be around Mario.
	LDA $96							;\Do the same thing but Y position and vertically.
	CLC							;|However the vertical distance is a full screen height plus 2 16x16 blocks
	ADC #$0018						;|as the screen is 224 ($E0) pixels tall.
	AND #$FF00						;|
	STA !Freeram_ScrollLimitsBoxYPosition			;/
	LDA #$0000						;\No horizontal scrolling freely since the zone is 256 pixels wide
	STA !Freeram_ScrollLimitsAreaWidth			;/
	LDA #$0020						;\A little bit of vertical scrolling so that the area is 256 pixels tall.
	STA !Freeram_ScrollLimitsAreaHeight			;/
	SEP #$20
	RTL