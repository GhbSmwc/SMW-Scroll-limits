;Note: Don't patch this if you've installed scrolling-related patches like:
;-Center Scroll
;-Vertical Camera Panning
;Since they both have code that set the scroll limits. You must edit those
;patches on the code that handles the scrolling limits to use the RAM
;defined:
;-!Freeram_ScrollLimitsFlag
;-!Freeram_ScrollLimitsAreaHeight
;-!Freeram_ScrollLimitsAreaWidth
;-!Freeram_ScrollLimitsBoxXPosition
;-!Freeram_ScrollLimitsBoxYPosition
;
;This patch MERELY edits the scroll limits, other stuff such as
;the “flip-screen” effect (megaman, metroid, etc.) are handled
;under uberasm tool.


;Note: The scrolling flags ($1411 for horizontal and $1412 for vertical), when set to disable ($00), the
;bounds code are not executed, meaning they do not bound the screen, since the code to position the screen
;offset from the player also have a bound handler.


;Sa-1 check
	!dp = $0000
	!addr = $0000
	!bank = $800000
	!sa1 = 0
	!gsu = 0
	
	if read1($00FFD6) == $15
		sfxrom
		!dp = $6000
		!addr = !dp
		!bank = $000000
		!gsu = 1
	elseif read1($00FFD5) == $23
		sa1rom
		!dp = $3000
		!addr = $6000
		!bank = $000000
		!sa1 = 1
	endif
;Get defines
	incsrc "ScrollLimitsDefines/Defines.asm"
;Hijacks
;	;Make uberasm tool to truely be able to set $9D to nonzero value and without
;	;messing up the HDMA
;		org $00C5CE			;\fix hdma issues (like message box) when setting
;		autoclean JSL FixHDMA		;/$7E0071 to #$0B ($00cde8 constantly sets $9D to $00 when $71 is $00.).
;		NOP #4
	;^Note to self: $13FB is a better alternative to setting $71 to #$0B since the latter can cause issues like player dropping
	;carried sprites during a flip screen transition. How this works: it performs the code in this order:
	;(1) Check if player is frozen at $00C4FB
	;(2) Check player animation state at $00C593 if $13FB is zero. Assuming the player is "normal", $71 == $00, it jumps to $00CC68
	;(3) JSR at $00CCC3, goes to $00CDDD, and eventually clears $9D, every frame, at $00CDE8
	;Horizontal level
		org $00F73C
		autoclean JML HorizontalLevelHorizontalLimits
	;Vertical level
		org $00F789
		autoclean JML VerticalLevelHorizontalScroll
	;Both horiz and vert's vertical scrolling
		org $00F893
		autoclean JML VerticalScrollingLimits
;Main code
	freecode
;	FixHDMA: ;>JSL from $00C5CE
;		LDA $0D9B|!addr
;		CMP #$C1
;		BNE .NormalLevel
;	
;		.BowserFight
;			;Restore code
;			STZ.W $0D9F|!addr		;>no HDMA!
;			LDA.B #$01			;\
;			STA.W $1B88|!addr		;/ message box is expanding
;	
;		.NormalLevel
;			RTL
	HorizontalLevelHorizontalLimits:	;>JML from $00F73C
		;A: 16-bit
		LDA !Freeram_ScrollLimitsFlag
		AND.w #$00FF
		BNE .CustomLimits
		.Vanilla
			LDA $02
			CLC
			ADC $1A
			;CMP #$0000			;\
			BPL ..CODE_00F746		;|left boundary
			LDA.W #$0000			;/
			
			..CODE_00F746
			STA $1A				;>Set screen X position
			LDA $5E				;\Deal with right boundary
			DEC A				;|
			XBA				;|
			AND.W #$FF00			;|
			BPL ..CODE_00F754		;|
			LDA.W #$0080			;|
			
			..CODE_00F754
			CMP $1A				;|
			BPL ..CODE_00F75A		;|
			STA $1A				;/
			
			..CODE_00F75A:
			BRA .Done
		.CustomLimits
			LDA $02
			CLC
			ADC $1A
			CMP !Freeram_ScrollLimitsBoxXPosition	;\left boundary
			BPL ..CODE_00F746			;|
			LDA !Freeram_ScrollLimitsBoxXPosition	;/
			
			..CODE_00F746
			STA $1A					;>Set screen X position
			LDA !Freeram_ScrollLimitsBoxXPosition	;\Deal with right boundary
			CLC					;|
			ADC !Freeram_ScrollLimitsAreaWidth	;|
			CMP $1A					;|!Freeram_ScrollLimitsBoxXPosition + !Freeram_ScrollLimitsAreaWidth = Right_boundary
			BPL ..CODE_00F75A			;| if Right_boundary >= ScreenXPos (or ScreenXPos < Right_boundary), skip
			STA $1A					;/>Limit rightwards position.
			
			..CODE_00F75A:
		.Done
			JML $00F79D
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	VerticalLevelHorizontalScroll:		;>JML from $00F789
		LDA !Freeram_ScrollLimitsFlag
		AND #$00FF
		BNE .CustomLimits
	.Vanilla
		LDA $02
		CLC
		ADC $1A
		BPL .CODE_00F793
		LDA #$0000
		
		.CODE_00F793
		CMP #$0101
		BMI .CODE_00F79B
		
		LDA #$0100
		.CODE_00F79B
		STA $1A
		BRA .Done
	.CustomLimits
		LDA $02
		CLC
		ADC $1A
		..LeftBorderCheck
			CMP !Freeram_ScrollLimitsBoxXPosition
			BPL ...NotExceedingLeft
			...ExceedingLeft
			LDA !Freeram_ScrollLimitsBoxXPosition
			...NotExceedingLeft
			STA $1A
		..RightBorderCheck
			LDA !Freeram_ScrollLimitsBoxXPosition
			CLC
			ADC !Freeram_ScrollLimitsAreaWidth
			CMP $1A
			BPL ...NotExceedingRight		;>If border to the right of screen or screen to the left, it is fine.
			STA $1A
			...NotExceedingRight
		.Done
			JML $00F79D
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	VerticalScrollingLimits:	;>JML from $00F893
			;A: 16-bit
			PHA
			LDA !Freeram_ScrollLimitsFlag
			AND #$00FF
			BNE .CustomLimits
			
			.Vanilla
				PLA
				ADC $1C
				CMP.w $00F6AD,y
				BPL ..CODE_00F89D
				LDA.w $00F6AD,y
				
				..CODE_00F89D
				STA $1C
				LDA $04
				CMP $1C
				BPL ..Return00F8AA
				STA $1C
				SEP #$20
				STZ $13F1|!addr
				REP #$20		;>Just in case
				..Return00F8AA
				JML $00F8AA
			.CustomLimits
				PLA
				ADC $1C
				CMP !Freeram_ScrollLimitsBoxYPosition	;\Top limit
				BPL ..InBound
				..PastTheTop
					LDA !Freeram_ScrollLimitsBoxYPosition
				..InBound
					STA $1C				;/
				LDA !Freeram_ScrollLimitsBoxYPosition	;\Bottom limit
				CLC					;|
				ADC !Freeram_ScrollLimitsAreaHeight	;|
				CMP $1C					;|
				BPL .Done				;|
				STA $1C					;/
				SEP #$20
				STZ $13F1|!addr
				REP #$20		;>Just in case
			.Done
				JML $00F8AA