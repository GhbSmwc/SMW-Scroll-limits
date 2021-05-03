;Freeram
 ;[1 byte] Flag of scroll limits:
 ;$00 = Off (scroll within the main level limits)
 ;$01 = On
 ;$02 = Camera gets scroll into bounds.
  if !sa1 == 0
   !Freeram_ScrollLimitsFlag = $58
  else
   !Freeram_ScrollLimitsFlag = $58
  endif
 ;[2 bytes each] Scroll boundaries.
  ;Left limit X position
   if !sa1 == 0
    !Freeram_ScrollLimitsLeftBorder = $60
   else
    !Freeram_ScrollLimitsLeftBorder = $60
   endif
  ;Top limit Y position
   if !sa1 == 0
    !Freeram_ScrollLimitsTopBorder = $62
   else
    !Freeram_ScrollLimitsTopBorder = $62
   endif
  ;[2 bytes each] Dimensions (extends rightwards and downwards when they increase
  ;the bottom and right are calculated: XY_Max_Value = XYTopOrLeft + WidthOrHeight)
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
  ;This is needed for “flip screen” effect seen in games like Megaman or metroid,
  ;it holds the value of the destination position the screen to scroll towards.
  ;It is also used when the screen tries to “revert” towards the player, to avoid
  ;the screen jumping and showing unloaded layer 1 graphics.
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
  ;coordinates that $13DA/$13DC. This also enables diagonal scrolling
  ;similar to how Celeste's flip screen works.
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
;Settings
 ;Are you using center scroll patch? (0 = no, 1 = yes)
  !Setting_ScrollLimits_UsingCenterScroll = 0
 ;Flip screen speed, approximately (because it uses an aiming routine)
 ;1/16th pixel per frame.
  !Setting_ScrollLimits_FlipScreenSpeed = $60