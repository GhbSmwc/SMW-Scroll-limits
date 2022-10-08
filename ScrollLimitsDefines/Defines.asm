;Don't touch
	;Sa-1 check
	if defined("sa1") == 0
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
	endif

;Freeram
;If you have trouble tracking your used RAM to avoid conflicts, look for “[address tracker]”.
 ;[1 byte] Flag of scroll limits:
 ;$00 = Off (scroll within the main level limits)
 ;$01 = On
 ;$02 = Camera gets scrolled into bounds, to the position closest to the player.
 ;$03 = Same as above but freezes mario and sprites by setting $13FB and $9D.
  if !sa1 == 0
   !Freeram_ScrollLimitsFlag = $58
  else
   !Freeram_ScrollLimitsFlag = $58
  endif
 ;[2 bytes each] Scroll boundary positions, in pixels. These RAMs themselves represents the top and left border.
 ;They also represent the position of the scroll area since these are the "origin position"
 ;of the zone. The right and bottom boundaries are actually measured as the width and height,
 ;measuring how far the screen can scroll rightwards and downwards (in units of pixels, not whole screens) from
 ;that area
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
  ;the width and height.), in pixels. NOTE: This is how far, the top-left of the screen can move
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
 ;move similar to how $7B/$7D/$00DC4F works, as well as the fixed point
 ;coordinates that $13DA/$13DC works. This also enables diagonal scrolling
 ;similar to how Celeste's flip screen works, since the routine uses an aiming
 ;routine rather than a primitive 8-directional speed.
  ;[4 bytes] X and Y speed and fraction
  ;+$00 X speed (1/16th px per frame)
  ;+$01 fraction X position
  ;+$02 Y speed (1/16th px per frame)
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
 ;If that happens (results in these two RAMs not being equal values), the routine
 ;"SetScrollBorder" should only execute once on every transition.
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
 ;1/16th pixel per frame. Use only $01-$7F, $7F being the fastest.
 ;
 ;Be careful with faster speeds, as the screen does move by a handful of pixels,
 ;and if that movement distance is big enough that can OVERSHOOT the destination,
 ;the game could "softlock" oscillating and constantly overshooting it and shaking
 ;the screen (it gets stuck). If this can happen, set
 ;!Setting_ScrollLimits_DestinationSnapDistance to a higher number.
  !Setting_ScrollLimits_FlipScreenSpeed = $60
 ;Destination snapping distance. When the screen gets close within this number of
 ;distance (in pixels), will snap the screen and end the scrolling effect. Set this
 ;to a higher number if you have a higher speed (!Setting_ScrollLimits_FlipScreenSpeed).
 ;
 ;To know if there are a potential risk:
 ;-find how many pixels range:
 ;  DestinationPixelRange = !Setting_ScrollLimits_DestinationSnapDistance * 2
 ;-find how many pixels being traveled, potentially:
 ;  PotentialPixelsMoved = ceiling(!Setting_ScrollLimits_FlipScreenSpeed / 16)
 ;   ^Used the ceiling function because fractional movement of a pixel can accumulate and
 ;    potentially add an additional pixel of movement (14/16 becomes 15/16 wouldn't move
 ;    by a pixel, however 15/16 becoming 1 and 0/16 DOES move a pixel)
 ;
 ;    In case you don't know, the ceiling function rounds the number up an integer (picks
 ;    the lowest integer >= x, like ceiling(x) when x is 5.1 to 5.9 results 6)
 ;
 ;And now if DestinationPixelRange is less than PotentialPixelsMoved, then it is possible
 ;the screen could get stuck. Just be careful not to have slow speed and large snap
 ;distance, that can cause the screen to noticeably snap to its destination position abruptly.
  !Setting_ScrollLimits_DestinationSnapDistance = $0004
 ;Y position of a point the screen tries to center with the player vertically
  !Setting_ScrollLimits_PlayerYCenter = $0070
 ;[address tracker] Display RAM usage in console window (formatted and compatible with the address
 ;tracker JS tool I made: https://www.smwcentral.net/?p=section&a=details&id=26516 )
 ;Note:
 ; -you'll have to pad the bank byte yourself
 ; -The text on the console window does not allow the tab character, but you can make it output a text file with the tab
 ;  characters using the batch and/or command prompt. Syntax in doing so is by 2 ways using this string:
 ;   [path to asar.exe] [path to this define file] [path to game file] >> [path of output file]
 ;  -The methods:
 ;   -Command prompt: Just put the whole previously mentioned command in there.
 ;   -Batch file: create a txt file, rename it InsertNameHere.bat (make sure your file explorer lets you edit the extension), with the syntax previously
 ;    mentioned.
 ;  use quotes if you have spaces in filename(s).
  !Setting_ScrollLimits_ShowRAMUsage = 0
;Print command (don't touch unless you know what you're doing) [address tracker]
	if !Setting_ScrollLimits_ShowRAMUsage != 0
		print "RAM usage:"
		print hex(!Freeram_ScrollLimitsFlag), "	1	Freeram_ScrollLimitsFlag"
		print hex(!Freeram_ScrollLimitsBoxXPosition), "	2	Freeram_ScrollLimitsBoxXPosition"
		print hex(!Freeram_ScrollLimitsBoxYPosition), "	2	Freeram_ScrollLimitsBoxYPosition"
		print hex(!Freeram_ScrollLimitsAreaWidth), "	2	Freeram_ScrollLimitsAreaWidth"
		print hex(!Freeram_ScrollLimitsAreaHeight), "	2	Freeram_ScrollLimitsAreaHeight"
		print hex(!Freeram_FlipScreenXDestination), "	2	Freeram_FlipScreenXDestination"
		print hex(!Freeram_FlipScreenYDestination), "	2	Freeram_FlipScreenYDestination"
		print hex(!Freeram_FlipScreenXYSpeedAndFraction), "	4	Freeram_FlipScreenXYSpeedAndFraction"
		print hex(!Freeram_FlipScreenAreaIdentifier), "	1	Freeram_FlipScreenAreaIdentifier"
		print hex(!Freeram_FlipScreenAreaIdentifierPrev), "	1	Freeram_FlipScreenAreaIdentifierPrev"
		print hex(!Scratchram_MarioCenterXPos), "	2	Scratch RAM"
		print hex(!Scratchram_MarioCenterYPos), "	2	Scratch RAM"
		print hex(!Freeram_DisableBarrier), "	1	Freeram_DisableBarrier (disables the barrier preventing player from leaving the screen)."
	endif