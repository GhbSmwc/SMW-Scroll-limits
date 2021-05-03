;Note: Don't patch this if you've installed scrolling-related patches like:
;-Center Scroll
;-Vertical Camera Panning
;Since they both have code that set the scroll limits.

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
	;Horizontal level
		org $00F73C
		autoclean JML HorizontalLevelLimits
	;Both horiz and vert's vertical scrolling
		org $00F893
		autoclean JML VerticalScrollingLimits
;Main code
	freecode
	
	HorizontalLevelLimits:	;>JML from $00F73C
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
			CMP !Freeram_ScrollLimitsLeftBorder	;\left boundary
			BPL ..CODE_00F746			;|
			LDA !Freeram_ScrollLimitsLeftBorder	;/
			
			..CODE_00F746
			STA $1A					;>Set screen X position
			LDA !Freeram_ScrollLimitsLeftBorder	;\Deal with right boundary
			CLC					;|
			ADC !Freeram_ScrollLimitsAreaWidth	;|
			CMP $1A					;|!Freeram_ScrollLimitsLeftBorder + !Freeram_ScrollLimitsAreaWidth = Right_boundary
			BPL ..CODE_00F75A			;| if Right_boundary >= ScreenXPos (or ScreenXPos < Right_boundary), skip
			STA $1A					;/>Limit rightwards position.
			
			..CODE_00F75A:
		.Done
			JML $00F79D
	VerticalScrollingLimits:	;>JML from $00F893
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
				CMP !Freeram_ScrollLimitsTopBorder	;\Top limit
				BPL ..InBound
				..PastTheTop
					LDA !Freeram_ScrollLimitsTopBorder
				..InBound
					STA $1C				;/
				LDA !Freeram_ScrollLimitsTopBorder	;\Bottom limit
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