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
;Main code
	freecode
	
	HorizontalLevelLimits:	;>JML from $00F73C
		;A: 16-bit

CODE_00F73C:        A5 02         LDA $02                   ;\Distance from the scroll lines to mario
CODE_00F73E:        18            CLC                       ;|going from the left edge of the screen...
CODE_00F73F:        65 1A         ADC RAM_ScreenBndryXLo    ;/
CODE_00F741:        10 03         BPL CODE_00F746           ;>if not past the left edge, good.


		LDA !Freeram_ScrollLimitsFlag
		AND.w #$00FF
		BEQ .Vanilla
		CMP #$0001
		BEQ .ScrollToInBounds
		
		.LockTheCamera
		
		.ScrollToInBounds
			;check if the CAM has reached in-bounds
			
			;if not, scroll the cam towards it
		.Vanilla
			LDA $02
			CLC
			ADC $1A
			BPL ..CODE_00F746
			LDA.W #$0000              ;\Prevent screen from scrolling past left edge of level.
			
			..CODE_00F746
			STA RAM_ScreenBndryXLo    ;/(this is how Mario moves the screen horizontally, horizontal levels only)
			LDA $5E                   ;\Prevent screen from scrolling past the
			DEC A                     ;|last screen in a horizontal level.
			XBA                       ;|
			AND.W #$FF00              ;|
			BPL ..CODE_00F754         ;|
			LDA.W #$0080              ;|
			
			..CODE_00F754
			CMP RAM_ScreenBndryXLo    ;|
			BPL CODE_00F75A           ;|
			STA RAM_ScreenBndryXLo    ;|
			
			..CODE_00F75A:
			
			..Done
			JML $00F79D