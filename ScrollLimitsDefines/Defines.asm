;Freeram
 ;[1 byte] Flag of scroll limits:
 ;$00 = Off (scroll within the main level limits)
 ;$01 = Inital phase (camera is outside of an area and needs to scroll to it)
 ;$02 = main phase (camrea is locked in this area).
  if !sa1 == 0
   !Freeram_ScrollLimitsFlag = $58
  else
   !Freeram_ScrollLimitsFlag = $58
  endif
 ;[2 bytes] Scroll boundaries.
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
  ;[2 bytes] Dimensions (extends rightwards and downwards when they increase
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
;Settings
 ;Are you using center scroll patch? (0 = no, 1 = yes)
  !Setting_ScrollLimits_UsingCenterScroll = 0