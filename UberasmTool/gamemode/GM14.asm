;Run this as gamemode 14 or 7 as main.

incsrc "../ScrollLimitsDefines/Defines.asm"

main:
	JSL LibraryScrollLimits_ScrollLimitMain
	RTL