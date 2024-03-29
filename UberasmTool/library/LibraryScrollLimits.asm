;This is a subroutine file intended to be placed in uberasm tool's "library" folder,
;
;
incsrc "../ScrollLimitsDefines/Defines.asm"

;Subroutines include:
;-ScrollLimitMain
;-ClampDestinationPosition
;-CheckScreenReachDestination
;-DisplaceScreenSpeed
;-Aiming
;-IdentifyWhichBorder
;-SetScrollBorder
;-ForceScreenWithinLimits
;-ForceScreenWithinIdentifiedLimits
;-FailSafeScrollBorder
;-CheckIfMarioIsOutsideZone
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Do scrolling effect.
;;
;;To be called using gameode 14 under "main" (run every
;;frame) using this:
;; JSL LibraryScrollLimits_SetScrollBorder
;;Not recommended to call this twice for both gamemode 14
;;and level as this can cause the screen to move twice as fast
;;and potentially cause other issues.
;;
;;This itself only do the scrolling effects to move
;;the screen to its destination during a transition
;;(not just for flip-screen, but also a way to enable/disable
;;/move borders without screen jumping).
;;Input:
;;-!Freeram_ScrollLimitsFlag:
;; $00 = Do nothing
;; $01 = Same as above but custom borders enabled
;; $02 = Screen transition (without $9D freeze)
;; $03 = Screen transition (with $9D freeze)
;;Output:
;;-Carry: Clear if screen has not reached
;; destination, otherwise set (for 1 frame-execution).
;; Useful for codes to run for custom effects when
;; the transition finishes. Not to be confused with
;; "SetScrollBorder" which $0D is set at the beginning
;; frame of the transition.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ScrollLimitMain:
	LDA $13D4|!addr		;>Pause flag
	ORA $1426|!addr		;>Seems like either transferring from $1A-$1D to $1462-$1465 (or vice versa) gets suspended during a message box.
	BNE .Done
	
	.PlayerAnimationCheck ;This prevents the scrolling from happening if the player is performing certain actions that shouldn't cause the screen to transition.
		LDA $71
		BEQ ..Allow		;\Allow either "normal-state" Mario or during a freeze
		CMP #$0B		;|(when RAM $71 is $0B, code at $00cde8 is no longer executed)
		BEQ ..Allow		;/
		CMP #$01		;\Prevent triggering the flip screen effects during things like dying
		BCS .Done		;/entering pipes and so on.
	
	..Allow
	LDA !Freeram_ScrollLimitsFlag
	BEQ .Done
	CMP #$02
	BEQ .DragScreenToDestination
	CMP #$03
	BEQ .DragScreenToDestination
	
	.Done
		RTL
	.DragScreenToDestination
		.Drag
			..AdjustTarget
				;This essentially functions like a clamp function,
				;making sure the target is the closest to the current
				;screen as possible as to:
				;-Prevent screen jumping horizontally, especially when it
				; CAN be placed on Mario without being out of bounds.
				JSL ClampDestinationPosition			;>Get valid target position (place on mario, unless that is out of bounds, then place target in bounds closest)
				JSL CheckScreenReachDestination			;\Check if screen have gotten close enough to that target
				BCS .ReachedDestination				;/
			..MoveScreen
				...Freeze
					LDA !Freeram_ScrollLimitsFlag
					CMP #$03
					BNE ....ScrollWithoutFreeze
					
					....ScrollWithFreeze
						LDA #$0B
						;STA $71
						STA $9D					;>Freeze
						STA $13FB|!addr
					....ScrollWithoutFreeze
				
				STZ $1411|!addr					;\Disable scrolling
				STZ $1412|!addr					;/
				REP #$20
				LDA $1462|!addr					;\Setup aiming
				SEC						;|
				SBC !Freeram_FlipScreenXDestination		;|
				STA $00						;|
				LDA $1464|!addr					;|
				SEC						;|
				SBC !Freeram_FlipScreenYDestination		;|
				STA $02						;|
				SEP #$20
				LDA.b #!Setting_ScrollLimits_FlipScreenSpeed	;/
				JSL Aiming
				LDA $00						;\Get XY speed
				STA !Freeram_FlipScreenXYSpeedAndFraction	;|
				LDA $02						;|
				STA !Freeram_FlipScreenXYSpeedAndFraction+2	;/
				LDX #$00					;\Apply XY speed to make screen move
				JSL DisplaceScreenSpeed				;|
				LDX #$02					;|
				JSL DisplaceScreenSpeed				;/
				JSL CheckScreenReachDestination			;\After moving the screen, snap if reached destination
				BCS .ReachedDestination				;/as to prevent 1-frame going past target.
				CLC
				RTL
		.ReachedDestination
			..Unfreeze
				LDA !Freeram_ScrollLimitsFlag
				CMP #$03
				BNE ...NotSetToFrozen
				STZ $9D
				;STZ $71
				STZ $13FB|!addr
				...NotSetToFrozen
			LDA #$01				;\Reenable scrolling
			STA $1411|!addr				;|
			STA $1412|!addr				;/
			REP #$20
			LDA !Freeram_FlipScreenXDestination	;\Set screen position to destination
			STA $1462|!addr				;|in case off by few pixels.
			LDA !Freeram_FlipScreenYDestination	;|
			STA $1464|!addr				;/
			SEP #$20
			LDA #$01				;\Reset itself so that this (block of code to reset state) does not run every frame.
			STA !Freeram_ScrollLimitsFlag		;/
			SEC
			RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Adjust the target position to be centered with the player or be in-bounds
;;!Freeram_FlipScreenXDestination and !Freeram_FlipScreenYDestination to be
;;to be corrected.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ClampDestinationPosition:
	;Note to self
	; $142A = Static cam region (relative to camera's left edge (origin X position)), center.
	; $142C = Static cam region (relative to camera's left edge (origin X position)), left edge (-$000C)
	; $142E = Static cam region (relative to camera's left edge (origin X position)), right edge (+$000C)
	;
	;
	; It then uses $142A-$142F
	; To mimic the way how SMW's horizontal scrolling works
	REP #$20
	.HorizontalClamp
		;This figures out the X position of the target to be positioned so that Mario is always within the static cam region.
		if !Setting_ScrollLimits_UsingCenterScroll == 0
			LDA $94
			SEC
			SBC $1462|!addr		;>A is now player X pos on-screen (MarioXPosOnScrn)
			SEC
			SBC $142C|!addr		;>A is now player X pos, relative to $142C (MarioXPosOnStaticCam)
			.ClampMarioIntoStaticCam
			;Explanation of how I pull this off:
			;-The shortest distance between mario is MarioXPosOnScrn to $142C
			;-The longest distance between mario is MarioXPosOnScrn to $142E
			;-If you take $94, subtract by $1462, you'll get the player's X pos relative to screen border (MarioXPosOnScrn). The distance between the
			; left edge and Mario.
			;-$142E, relative to $142C is #$0018, the width of the static camera region
			;-If you take MarioXPosOnScrn, and subtract by $142C, it is now the X position relative to the left edge of static cam (MarioXPosOnStaticCam).
			;--Since Mario is not allowed to be outside the static cam region when the camera is not on the level edge (which will
			;  cause the screen to jump and show glitched graphics), MarioXPosOnStaticCam cannot be less than $0000 and more than $0018, which are the
			;  $142C and $142E offset by +/-$000C.
			;Therefore we are trying to solve the length of the horizontal line between Mario and the left edge of the screen:
			; ScrnDestination = RAM_94 - (RAM_142C + clamp(MarioXPosOnStaticCam, $0000, $000C))
			BPL ..NotNegative	;>If PlayerXPos142C is negative, bottom this out to 0
			..PreventSnapLeft
				LDA #$0000
				BRA ..SetPlayerXPos142C
			..NotNegative
				CMP #$0018		;>Right edge of static cam region
				BMI ..SetPlayerXPos142C
			..PreventSnapRight
				LDA #$0018
			..SetPlayerXPos142C
				STA $00
				LDA $94
				SEC
				SBC $142C|!addr
				SEC
				SBC $00
		else
			LDA $94
			SEC
			SBC $142A|!addr
		endif
		STA !Freeram_FlipScreenXDestination
		..LeftBorderCheck
			CMP !Freeram_ScrollLimitsBoxXPosition
			BPL ...NotPassingLeftBorder
			LDA !Freeram_ScrollLimitsBoxXPosition
			STA !Freeram_FlipScreenXDestination
			...NotPassingLeftBorder
		..RightBorderCheck
			LDA !Freeram_ScrollLimitsBoxXPosition		;\Right border
			CLC						;|
			ADC !Freeram_ScrollLimitsAreaWidth		;/
			CMP !Freeram_FlipScreenXDestination
			BPL ...NotPassingRightBorder
			STA !Freeram_FlipScreenXDestination
			...NotPassingRightBorder
	.VerticalClamp
		;Vertical positioning of the screen seems to be more simpler than horizontal.
		LDA $96
		SEC
		SBC.w #!Setting_ScrollLimits_PlayerYCenter
		STA !Freeram_FlipScreenYDestination
		..TopBorderCheck
			CMP !Freeram_ScrollLimitsBoxYPosition
			BPL ...NotPassingTopBorder
			LDA !Freeram_ScrollLimitsBoxYPosition
			STA !Freeram_FlipScreenYDestination
			...NotPassingTopBorder
		..BottomBorderCheck
			LDA !Freeram_ScrollLimitsBoxYPosition		;\Right border
			CLC						;|
			ADC !Freeram_ScrollLimitsAreaHeight		;/
			CMP !Freeram_FlipScreenYDestination
			BPL ...NotPassingTopBorder
			STA !Freeram_FlipScreenYDestination
			...NotPassingTopBorder
	.OuterLevelClamp
		;This is a failsafe measure that should the custom borders be extending
		;outside the level, will use the vanilla borders too. Having the screen
		;going past the left or top edge of the stage causes garbage 16x16 tiles
		;to show EVERYWHERE (even appearing INSIDE the level borders),
		;guaranteed if scrolling in certain directions.
		..TopAndLeft
			LDA #$0000
			CMP !Freeram_FlipScreenXDestination
			BMI ...LeftBorderSafe
			STA !Freeram_FlipScreenXDestination
			...LeftBorderSafe
			CMP !Freeram_FlipScreenYDestination
			BMI ...TopBorderSafe
			STA !Freeram_FlipScreenYDestination
			...TopBorderSafe
		..BottomAndRight
			LDA $5B
			LSR
			BCC ...HorizontalLevel
			
			...VerticalLevel
				LDA #$0100				;>Rightmost position
				CMP !Freeram_FlipScreenXDestination
				BPL ....RightBorderSafe
				STA !Freeram_FlipScreenXDestination
				....RightBorderSafe
				LDA $5F				;\$GGSS (GG for what was in $60, we don't need, SS is the number of screens vertically)
				DEC				;|SS now contains the stopping position when scrolling downwards, in number of screens, now becoming ss
				XBA				;|it is now ssGG
				AND #$FF00			;/now ss00, the actual bottommost position
				CMP !Freeram_FlipScreenYDestination
				BPL ....BottomBorderSafe
				STA !Freeram_FlipScreenYDestination
				....BottomBorderSafe
				BRA .Done
			...HorizontalLevel
				LDA $5E				;>$GGSS (GG for what was in $5F, we don't need, SS is the number of screens horizontally)
				DEC A				;>SS now contains the stopping position when scrolling rightwards, in number of screens, now becoming ss
				XBA				;>it is now ssGG
				AND #$FF00			;>now ss00, the actual rightmost position
				BPL ....NormalScrollLimits	;>If ss is 0 or more, then it is a normal scrolling, otherwise -1, then it is a ludwig/reznor boss fight, 1 1/2 screen area.
				....LudwigReznor
					LDA #$0080
				....NormalScrollLimits
					CMP !Freeram_FlipScreenXDestination
					BPL ....RightBorderSafe
					STA !Freeram_FlipScreenXDestination
					....RightBorderSafe
				LDA $13D7|!addr		;>Level height
				SEC
				SBC #($00E0)+1		;>The screen is 224 pixels tall, 224 = $E0, but since the screen is showing layer 1 1px lower, an additional 1 to be subtracted by is needed
				CMP !Freeram_FlipScreenYDestination
				BPL ...NotExceedBottom
				STA !Freeram_FlipScreenYDestination
				...NotExceedBottom
	.Done
		SEP #$20
		RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Check if screen have reached destination.
;;This is done by checking if the screen is close enough (within
;;!Setting_ScrollLimits_DestinationSnapDistance pixels from destination).
;;Reason for distance checking is to prevent overshooting at higher
;;speeds, which can cause the screen to constantly shake and repeatedly
;;overshooting, which softlocks the game.
;;Output:
;; Carry clear: no
;; Carry set: yes
;;This works like $00DC4F.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckScreenReachDestination:
	REP #$20
	.HorizontalDistance
		LDA $1462|!addr
		SEC
		SBC !Freeram_FlipScreenXDestination
		BPL ..Positive
		
		..Negative
		EOR #$FFFF
		INC
		
		..Positive
		CMP.w #!Setting_ScrollLimits_DestinationSnapDistance
		BCS .Far
		
	.VerticalDistance
		LDA $1464|!addr
		SEC
		SBC !Freeram_FlipScreenYDestination
		BPL ..Positive
		
		..Negative
		EOR #$FFFF
		INC
		
		..Positive
		CMP.w #!Setting_ScrollLimits_DestinationSnapDistance
		BCS .Far
	.Close
		SEP #$21
		RTL
	.Far
		SEP #$20
		CLC
		RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Speed handler
;;Input: X:
;; $00 = apply X displacement
;; $02 = apply Y displacement
;;This works like $00DC4F, using a precision of 1/16 of a pixel for
;;XY positions and how $7B/$7D moves the player.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DisplaceScreenSpeed:
	LDA !Freeram_FlipScreenXYSpeedAndFraction,X
	ASL
	ASL
	ASL
	ASL
	CLC
	ADC !Freeram_FlipScreenXYSpeedAndFraction+1,X
	STA !Freeram_FlipScreenXYSpeedAndFraction+1,X
	REP #$20
	PHP
	LDA !Freeram_FlipScreenXYSpeedAndFraction,X
	LSR
	LSR
	LSR
	LSR
	AND.W #$000F
	CMP.W #$0008
	BCC .CODE_00DC70
	ORA.W #$FFF0
	
	.CODE_00DC70
	PLP
	ADC $1462|!addr,X
	STA $1462|!addr,X
	SEP #$20
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Aiming Routine by MarioE. Improved by Akaginite to allow unlimited
;;distance.
;;
;;Input:  A   = 8 bit projectile speed
;;        $00 = 16 bit (shooter x pos - target x pos)
;;        $02 = 16 bit (shooter y pos - target y pos)
;;
;;Output: $00 = 8 bit X speed of projectile
;;        $02 = 8 bit Y speed of projectile
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Aiming:
.aiming
		PHX
		PHP
		SEP #$30
		STA $0F
		if !sa1
			STZ $2250
		endif
		LDX #$00
		REP #$30
		LDA $00
		BPL ..pos_dx
		EOR #$FFFF
		INC A
		STA $00
		LDX #$0002
		
..pos_dx	LDA $02
		BPL ..pos_dy
		EOR #$FFFF
		INC A
		STA $02
		INX
		
..pos_dy	STX $06
		ORA $00
		AND #$FF00
		BEQ +
		XBA
	-	LSR $00
		LSR $02
		LSR A
		BNE -
	+
		if !sa1
			LDA $00
			STA $2251
			STA $2253
			NOP
			BRA $00
			LDA $2306
			
			LDX $02
			STX $2251
			STX $2253
			BRA $00
			CLC
			ADC $2306
		else
			SEP #$20
			LDA $00
			STA $4202
			STA $4203
			NOP #4
			LDX $4216
			
			LDA $02
			STA $4202
			STA $4203
			NOP
			REP #$21
			TXA
			ADC $4216
		endif
		
		BCS ..v10000
		CMP #$4000
		BCS ..v4000
		CMP #$1000
		BCS ..v1000
		CMP #$0400
		BCS ..v400
		CMP #$0100
		BCS ..v100
		ASL A
		TAX
		LDA.l ..recip_sqrt_lookup,x
		BRA ..s0
		
..v100		LSR A
		AND #$01FE
		TAX
		LDA.l ..recip_sqrt_lookup,x
		BRA ..s1
		
..v400		LSR #3
		AND #$01FE
		TAX
		LDA.l ..recip_sqrt_lookup,x
		BRA ..s2
		
..v1000		ASL #2
		XBA
		ASL A
		AND #$01FE
		TAX
		LDA.l ..recip_sqrt_lookup,x
		BRA ..s3
		
..v4000		XBA
		ASL A
		AND #$01FE
		TAX
		LDA.l ..recip_sqrt_lookup,x
		BRA ..s4

..v10000	ROR A
		XBA
		AND #$00FE
		TAX
		LDA.l ..recip_sqrt_lookup,x
..s5		LSR A
..s4		LSR A
..s3		LSR A
..s2		LSR A
..s1		LSR A
..s0
		if !sa1
			STA $2251
			ASL A
			LDA $0F
			AND #$00FF
			STA $2253
			BCC ..skip_conv
	..conv		XBA
			CLC
			ADC $2307
			BRA +
	..skip_conv	LDA $2307
	+		STA $2251
			LDA $02
			STA $2253
			SEP #$20
			LSR $06
			LDA $2307
			BCS ..y_plus
			EOR #$FF
			INC A
	..y_plus	STA $02
		
			LDX $00
			STX $2253
			;LSR $06
			;LDA $2307
			;BCS ..x_plus
			LDA $2307
			LDX $06
			BNE ..x_plus
			EOR #$FF
			INC A
	..x_plus	STA $00
		
		else
			SEP #$30
			LDX $0F
			STX $4202
			STA $4203
			NOP #4
			LDX $4217
			XBA
			STA $4203
			
			BRA $00
			REP #$21
			TXA
			ADC $4216
			STA $04
			SEP #$20
			
			LDX $02
			STX $4202
			STA $4203
			NOP #4
			LDX $4217
			XBA
			STA $4203
			BRA $00
			REP #$21
			TXA
			ADC $4216
			SEP #$20
			LSR $06
			BCS ..y_plus
			EOR #$FF
			INC A
	..y_plus	STA $02
		
			LDA $00
			STA $4202
			LDA $04
			STA $4203
			NOP #4
			LDX $4217
			LDA $05
			STA $4203
			BRA $00
			REP #$21
			TXA
			ADC $4216
			SEP #$20
			LDX $06
			BNE ..x_plus
			EOR #$FF
			INC A
	..x_plus	STA $00
		endif
		
		PLP
		PLX
		RTL
		
	
..recip_sqrt_lookup
		dw $FFFF,$FFFF,$B505,$93CD,$8000,$727D,$6883,$60C2
		dw $5A82,$5555,$50F4,$4D30,$49E7,$4700,$446B,$4219
		dw $4000,$3E17,$3C57,$3ABB,$393E,$37DD,$3694,$3561
		dw $3441,$3333,$3235,$3144,$3061,$2F8A,$2EBD,$2DFB
		dw $2D41,$2C90,$2BE7,$2B46,$2AAB,$2A16,$2987,$28FE
		dw $287A,$27FB,$2780,$270A,$2698,$262A,$25BF,$2557
		dw $24F3,$2492,$2434,$23D9,$2380,$232A,$22D6,$2285
		dw $2236,$21E8,$219D,$2154,$210D,$20C7,$2083,$2041
		dw $2000,$1FC1,$1F83,$1F46,$1F0B,$1ED2,$1E99,$1E62
		dw $1E2B,$1DF6,$1DC2,$1D8F,$1D5D,$1D2D,$1CFC,$1CCD
		dw $1C9F,$1C72,$1C45,$1C1A,$1BEF,$1BC4,$1B9B,$1B72
		dw $1B4A,$1B23,$1AFC,$1AD6,$1AB1,$1A8C,$1A68,$1A44
		dw $1A21,$19FE,$19DC,$19BB,$199A,$1979,$1959,$1939
		dw $191A,$18FC,$18DD,$18C0,$18A2,$1885,$1869,$184C
		dw $1831,$1815,$17FA,$17DF,$17C5,$17AB,$1791,$1778
		dw $175F,$1746,$172D,$1715,$16FD,$16E6,$16CE,$16B7
		dw $16A1,$168A,$1674,$165E,$1648,$1633,$161D,$1608
		dw $15F4,$15DF,$15CB,$15B7,$15A3,$158F,$157C,$1568
		dw $1555,$1542,$1530,$151D,$150B,$14F9,$14E7,$14D5
		dw $14C4,$14B2,$14A1,$1490,$147F,$146E,$145E,$144D
		dw $143D,$142D,$141D,$140D,$13FE,$13EE,$13DF,$13CF
		dw $13C0,$13B1,$13A2,$1394,$1385,$1377,$1368,$135A
		dw $134C,$133E,$1330,$1322,$1315,$1307,$12FA,$12ED
		dw $12DF,$12D2,$12C5,$12B8,$12AC,$129F,$1292,$1286
		dw $127A,$126D,$1261,$1255,$1249,$123D,$1231,$1226
		dw $121A,$120F,$1203,$11F8,$11EC,$11E1,$11D6,$11CB
		dw $11C0,$11B5,$11AA,$11A0,$1195,$118A,$1180,$1176
		dw $116B,$1161,$1157,$114D,$1142,$1138,$112E,$1125
		dw $111B,$1111,$1107,$10FE,$10F4,$10EB,$10E1,$10D8
		dw $10CF,$10C5,$10BC,$10B3,$10AA,$10A1,$1098,$108F
		dw $1086,$107E,$1075,$106C,$1064,$105B,$1052,$104A
		dw $1042,$1039,$1031,$1029,$1020,$1018,$1010,$1008
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Setup borders, this determine which borders to use based on player position
;;in the level.
;;
;;Call this as "level" under "main":
;; JSL LibraryScrollLimits_IdentifyWhichBorder
;;
;;Input (little endian!):
;;-$00 to $02 (3 bytes): Table (each item is 2 bytes) of X positions
;;-$03 to $05 (3 bytes): Table (each item is 2 bytes) of Y positions
;;-$06 to $08 (3 bytes): Table (each item is 2 bytes) of widths
;;-$09 to $0B (3 bytes): Table (each item is 2 bytes) of heights
;;-$0C to $0D (3 bytes): Size of the table in bytes, minus 2
;;Output:
;;-!Freeram_FlipScreenAreaIdentifier: An index representing which screen area
;; the player is in. If not in any of these areas, will contain whatever last
;; he was in (if mario is in none of these areas, will not trigger a scroll,
;; the camera will still be in the zone he left).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IdentifyWhichBorder:
	.CheckMarioIsInThoseAreas
		REP #$30
		LDA $94					;\Get mario's center position
		CLC					;|
		ADC #$0008				;|
		STA !Scratchram_MarioCenterXPos		;|
		LDA $96					;|
		CLC					;|
		ADC #$0018				;|
		STA !Scratchram_MarioCenterYPos		;/

		LDA $0C
		TAY
		..CheckIfPlayerIsInsideAnyOfTheseBorders
			...Loop
				....HorizontalRange
					LDA !Scratchram_MarioCenterXPos
					CMP [$00],y
					BMI ....Next
					LDA [$00],y
					CLC
					ADC [$06],y
					CLC				;\The screen area extend at a minimum to the right by 256 pixels
					ADC #$0100			;/
					CMP !Scratchram_MarioCenterXPos
					BMI ....Next
				....VerticalRange
					LDA !Scratchram_MarioCenterYPos
					CMP [$03],y
					BMI ....Next
					LDA [$03],y
					CLC
					ADC [$09],y
					CLC				;\The screen area extend at a minimum downwards by 224 pixels
					ADC #$00E0			;/
					CMP !Scratchram_MarioCenterYPos
					BMI ....Next
				....Found
					TYA
					LSR
					SEP #$30
					STA !Freeram_FlipScreenAreaIdentifier
					BRA ....BreakLoop
				....Next
					DEY #2
					BPL ...Loop
				....NotFound
					SEP #$30			;\If mario is not in any of the areas listed in the tables, don't set the
					BRA .Done			;/screen area to some weird areas (will be the last valid area he's in).
				....BreakLoop
	.Done
		SEP #$30		;>Just in case
		RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Control borders, use for activating screen transition to another area.
;;
;;Call this as "level" under "main":
;; JSL LibraryScrollLimits_SetScrollBorder
;;
;;Input (little endian!):
;;-$00 to $02 (3 bytes): Table (each item is 2 bytes) of X positions
;;-$03 to $05 (3 bytes): Table (each item is 2 bytes) of Y positions
;;-$06 to $08 (3 bytes): Table (each item is 2 bytes) of widths
;;-$09 to $0B (3 bytes): Table (each item is 2 bytes) of heights
;;-$0C (1 byte): Scroll limits flag (don't use other values than listed here):
;; -$02 = Scroll without freeze
;; -$03 = Scroll with freeze
;;-!Freeram_FlipScreenAreaIdentifier: Index on the tables to select which
;; border to be in.
;;Output:
;;-$0D: Is there a screen transition?: $00 = No, $01 = Yes. Useful if you
;; code to run for 1 frame at the initial screen transition, such as changing
;; the music or other effects. Most likely you'll have to check $0D and
;; !Freeram_FlipScreenAreaIdentifier to identify which area you are
;; transitioning to. Not to be confused with "ScrollLimitMain" which triggers
;; at the END of the transition.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetScrollBorder:
	STZ $0D						;>Default screen transitioning to $00
	.CheckShouldScreenTransition
		LDA $0100|!addr					;\Set the borders, ignoring the screen check and transition during level load.
		CMP #$11					;|
		BEQ .SetBorders					;/
		CMP #$12					;\...Just in case
		BEQ .SetBorders					;|
		LDA #$13					;|
		BEQ .SetBorders					;/
		LDA !Freeram_FlipScreenAreaIdentifier		;\If there is a change in screen area detected, perform a screen flip
		CMP !Freeram_FlipScreenAreaIdentifierPrev	;|
		BEQ .NoTransition				;/
	.Transition
		STA !Freeram_FlipScreenAreaIdentifierPrev	;>Do it only once (update)
		INC $0D						;>Mark that a screen is transitioning.
		LDA $0C						;\No insta-scroll (transition)
		STA !Freeram_ScrollLimitsFlag			;/
		STZ $1411|!addr					;\Just in case SMW's scrolling would assume
		STZ $1412|!addr					;/these are set to nonzero and insta-scroll.
	.SetBorders
		REP #$30
		LDA !Freeram_FlipScreenAreaIdentifier
		AND #$00FF
		ASL
		TAY
		LDA [$00],y				;\Set attributes of the limit box based on what area identifier.
		STA !Freeram_ScrollLimitsBoxXPosition	;|
		LDA [$03],y				;|
		STA !Freeram_ScrollLimitsBoxYPosition	;|
		LDA [$06],y				;|
		STA !Freeram_ScrollLimitsAreaWidth	;|
		LDA [$09],y				;|
		STA !Freeram_ScrollLimitsAreaHeight	;/
	.NoTransition
		SEP #$30
		RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Force screen to be in bounds (this will instantly set the XY pos of the
;;screen.
;;Call this as "level" under "load":
;; JSL LibraryScrollLimits_ForceScreenWithinLimits
;;
;;This not to be used for the flip-screen effect, use the other subroutine
;;after this one (this is good for static borders). This is for "static"
;;borders not using the identifier (!Freeram_FlipScreenAreaIdentifier).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ForceScreenWithinLimits:
	REP #$20
	.Horiz
		..LeftSide
			LDA !Freeram_ScrollLimitsBoxXPosition
			CMP $1462|!addr
			BMI ..RightSide
			STA $1462|!addr
			STA $1A
		..RightSide
			CLC
			ADC !Freeram_ScrollLimitsAreaWidth
			CMP $1462|!addr
			BPL .Vert
			STA $1462|!addr
			STA $1A
	.Vert
		..Top
			LDA !Freeram_ScrollLimitsBoxYPosition
			CMP $1464|!addr
			BMI ..Bottom
			STA $1464|!addr
			STA $1C
		..Bottom
			CLC
			ADC !Freeram_ScrollLimitsAreaHeight
			CMP $1464|!addr
			BPL .Done
			STA $1464|!addr
			STA $1C
	.Done
	SEP #$20
	JSL FailSafeScrollBorder
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Force screen to be in identified bounds (this will instantly set the XY pos of the
;;screen. This is meant to be used for multi-bordered area for the flip-screen effect.
;;Call this as "level" under "load":
;; JSL LibraryScrollLimits_ForceScreenWithinIdentifiedLimits
;;
;;Call this AFTER calling "JSL LibraryScrollLimits_IdentifyWhichBorder".
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ForceScreenWithinIdentifiedLimits:
	JSL SetScrollBorder
	JSL ClampDestinationPosition		;\Fix a potential bug that can occur
	REP #$20				;|when teleporting within the same level
	LDA !Freeram_FlipScreenXDestination	;|
	STA $1462|!addr				;|
	STA $1A					;|
	LDA !Freeram_FlipScreenYDestination	;|
	STA $1464|!addr				;|
	STA $1C					;/
	.Horiz
		LDA !Freeram_ScrollLimitsBoxXPosition
		CMP $1462|!addr
		BMI ..NotExceedLeft
		STA $1462|!addr
		STA $1A
		
		..NotExceedLeft
		CLC
		ADC !Freeram_ScrollLimitsAreaWidth
		CMP $1462|!addr
		BPL ..NotExceedRight
		STA $1462|!addr
		STA $1A
		
		..NotExceedRight
	.Vert
		LDA !Freeram_ScrollLimitsBoxYPosition
		CMP $1464|!addr
		BMI ..NotExceedTop
		STA $1464|!addr
		STA $1C
		
		..NotExceedTop
		LDA !Freeram_ScrollLimitsBoxYPosition
		CLC
		ADC !Freeram_ScrollLimitsAreaHeight
		CMP $1464|!addr
		BPL ..NotExceedBottom
		STA $1464|!addr
		STA $1C
		
		..NotExceedBottom
	SEP #$20
	JSL FailSafeScrollBorder
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Failsafe level scroll border. Prevents these routines:
;;-ForceScreenWithinLimits
;;-ForceScreenWithinIdentifiedLimits
;;From potentially placing the screen outside the level bounds
;;Note: This assumes that the “Allow viewing full bottom row of
;;tiles” is always checked.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FailSafeScrollBorder:
	REP #$20
	.TopAndLeft
		LDA #$0000
		CMP $1462|!addr
		BMI ..NotExceedLeft
		STA $1462|!addr
		STA $1A
		..NotExceedLeft
		CMP $1464|!addr
		BMI ..NotExceedTop
		STA $1464|!addr
		STA $1C
		..NotExceedTop
	.BottomAndRight
		LDA $5B
		LSR
		BCC ..HorizontalLevel
		
		..VerticalLevel
			LDA #$0100
			CMP $1462|!addr
			BPL ...NotExceedRight
			STA $1462|!addr
			STA $1A
			...NotExceedRight
			LDA $5F			;>$GGSS
			DEC			;>$GGss
			XBA			;>$ssGG
			AND #$FF00		;>$ss00
			CMP $1464|!addr
			BPL ...NotExceedBottom
			STA $1464|!addr
			STA $1C
			...NotExceedBottom
			BRA .Done
		..HorizontalLevel
			LDA $5E			;>$GGSS
			DEC			;>$GGss
			XBA			;>$ssGG
			AND #$FF00		;>$ss00
			CMP $1462|!addr
			BPL ...NotExceedRight
			STA $1462|!addr
			STA $1A
			...NotExceedRight
			LDA $13D7|!addr		;>Level height
			SEC
			SBC #$00E0		;>The screen is 224 pixels tall, 224 = $E0
			CMP $1464|!addr
			BPL ...NotExceedBottom
			STA $1464
			STA $1C
			...NotExceedBottom
	.Done
		SEP #$20
		RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Check if Mario is outside the screen zone. Can be called anywhere, but
;;used mainly for "single-screen" (level - main):
;; JSL LibraryScrollLimits_CheckIfMarioIsOutsideZone
;;Input:
;;-Border attributes used to check if Mario is within them:
;;--!Freeram_ScrollLimitsBoxXPosition
;;--!Freeram_ScrollLimitsBoxYPosition
;;--!Freeram_ScrollLimitsAreaWidth
;;--!Freeram_ScrollLimitsAreaHeight
;;Output:
;;-Carry: clear if Mario is within, set if Mario is outside (which should
;; trigger the scrolling effect)
;;Destroyed:
;;$00-$03: Used for finding Mario's center position.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckIfMarioIsOutsideZone:
	REP #$20				;\Get player's center position
	LDA $94					;|
	CLC					;|
	ADC #$0008				;|
	STA $00					;|
	LDA $96					;|
	CLC					;|
	ADC #$0018				;|
	STA $02					;/
	LDA !Freeram_ScrollLimitsBoxXPosition
	CMP $00
	BEQ +					;>Prevent two areas from creating a 1px overlap area (so the range is 0-255 rather than 0-256).
	BPL .Outside
	+
	CLC
	ADC !Freeram_ScrollLimitsAreaWidth
	CLC
	ADC #$0100				;>Plus 256 because the screen is 256 pixels wide
	CMP $00
	BEQ .Outside				;>Prevent two areas from creating a 1px overlap area (so the range is 0-255 rather than 0-256).
	BMI .Outside
	LDA !Freeram_ScrollLimitsBoxYPosition
	CMP $02
	BEQ +					;>Prevent two areas from creating a 1px overlap area (so the range is 0-255 rather than 0-256).
	BPL .Outside
	+
	CLC
	ADC !Freeram_ScrollLimitsAreaHeight
	CLC
	ADC #$00E0				;>Plus 224 because the screen is 224 pixels tall
	CMP $02
	BEQ .Outside				;>Prevent two areas from creating a 1px overlap area (so the range is 0-255 rather than 0-256).
	BMI .Outside
	
	.Inside
		SEP #$20
		CLC
		RTL
	.Outside
		SEP #$21
		RTL