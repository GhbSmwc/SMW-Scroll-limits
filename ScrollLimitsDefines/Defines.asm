;Freeram
 ;[1 byte] Flag of scroll limits:
 ;$00 = Off (scroll within the main level limits)
 ;$01 = On
 ;$02 = Camera gets scrolled into bounds.
 ;$03 = Same as above but freezes mario and sprites by setting $13FB and $9D.
  if !sa1 == 0
   !Freeram_ScrollLimitsFlag = $58
  else
   !Freeram_ScrollLimitsFlag = $58
  endif
 ;[2 bytes each] Scroll boundaries. These RAMs themselves represents the top and left border.
 ;They also represent the position of the scroll area since these are the "origin position"
 ;of the zone. The right and bottom boundaries are actually measured as the width and height,
 ;measuring how far the screen can scroll rightwards and downwards (in units of pixels, not whole screens)
  ;Left limit X position
   if !sa1 == 0
    !Freeram_ScrollLimitsBoxXPosition = $60
   else
    !Freeram_ScrollLimitsBoxXPosition = $60
   endif
  ;Top limit Y position
   if !sa1 == 0
    !Freeram_ScrollLimitsBoxYPosition = $62
   else
    !Freeram_ScrollLimitsBoxYPosition = $62
   endif
  ;[2 bytes each] Dimensions (extends rightwards and downwards when you increase
  ;the width and height.) NOTE: This is how far, the top-left of the screen can move
  ;from the top-left of the scroll limits. Therefore the right and bottom edge of
  ;the screen extends by 256/224 pixels beyond here.
  ;(Example: A room width of $0000 means 256-pixel wide area)
  ;It is calculated: XY_Max_Value = XYTopOrLeft + WidthOrHeight.
   ;Width of the area 
    if !sa1 == 0
     !Freeram_ScrollLimitsAreaWidth = $0F5E
    else
     !Freeram_ScrollLimitsAreaWidth = $6F5E
    endif
   ;Height of the area
    if !sa1 == 0
     !Freeram_ScrollLimitsAreaHeight = $0F60
    else
     !Freeram_ScrollLimitsAreaHeight = $6F60
    endif
 ;[2 bytes each] Screen scroll target position
 ;This is needed for “flip screen” effect seen in games like Megaman, metroid, or celeste. This is used under uberasm tool code.
 ;It holds the value of the destination position the screen to gradually scroll towards it (clamped by
 ;the scroll limits to be positioned within bounds).
 ;When !Freeram_ScrollLimitsFlag >= 2, it will scroll to the player so that the player is in the static camera region
 ;($142A-142F), clamped (be in bounds closest to the current screen position) by the borders should the screen be out
 ;of bounds. This should guarantee that the screen shouldn't insta-scroll and show unloaded glitched layer 1 graphics.
  ;X position
   if !sa1 == 0
    !Freeram_FlipScreenXDestination = $0F62
   else
    !Freeram_FlipScreenXDestination = $6F62
   endif
  ;Y position
   if !sa1 == 0
    !Freeram_FlipScreenYDestination = $0F64
   else
    !Freeram_FlipScreenYDestination = $6F64
   endif
 ;These makes the screen's scrolling during a flip effect
 ;move similar to how $7B/$7D works, as well as the fixed point
 ;coordinates that $13DA/$13DC works. This also enables diagonal scrolling
 ;similar to how Celeste's flip screen works, since the routine uses an aiming
 ;routine rather than a primitive 8-directional speed.
  ;[4 bytes] X and Y speed and fraction
  ;+$00 X speed
  ;+$01 fraction X position
  ;+$02 Y speed
  ;+$03 fraction Y position
   if !sa1 == 0
    !Freeram_FlipScreenXYSpeedAndFraction = $0F66
   else
    !Freeram_FlipScreenXYSpeedAndFraction = $6F66
   endif
 ;[1 byte] This identify which screen area the screen is on.
 ;Needed to determine which screen limits to be.
  if !sa1 == 0
   !Freeram_FlipScreenAreaIdentifier = $79
  else
   !Freeram_FlipScreenAreaIdentifier = $79
  endif
 ;[1 byte] Same as above but is needed to check if the player is switching screens.
 ;If that happens, the routine "SetScrollBorder" should only execute once on every transition.
  if !sa1 == 0
   !Freeram_FlipScreenAreaIdentifierPrev = $7C
  else
   !Freeram_FlipScreenAreaIdentifierPrev = $7C
  endif
;Scratch RAM (can be reused for entirely different ASM resources, as long as during routine execution not to be used
;at the same time).
 ;[2 bytes each] Scratch RAM (things like the 24-bit indirect addressing eat up a large portion at $00)
  ;Mario's center position
   ;X position
    if !sa1 == 0
     !Scratchram_MarioCenterXPos = $7F8449
    else
     !Scratchram_MarioCenterXPos = $4001B8
    endif
   ;Y position
    if !sa1 == 0
     !Scratchram_MarioCenterYPos = $7F844B
    else
     !Scratchram_MarioCenterYPos = $4001BA
    endif
;RAM used by other patches
 ;Disable screen barrier via RAM
  if !sa1 == 0
   !Freeram_DisableBarrier = $5C
  else
   !Freeram_DisableBarrier = $5C
  endif
;Settings
 ;Are you using center scroll patch? (0 = no, 1 = yes)
  !Setting_ScrollLimits_UsingCenterScroll = 0
 ;Flip screen speed, approximately (because it uses an aiming routine)
 ;1/16th pixel per frame. Use only $01-$7F.
  !Setting_ScrollLimits_FlipScreenSpeed = $60
 ;Y position of a point the screen tries to center with the player vertically
  !Setting_ScrollLimits_PlayerYCenter = $0070