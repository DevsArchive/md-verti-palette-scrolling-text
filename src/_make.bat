@echo off
..\bin\asm68k.exe /p /o ae- /o l. core.asm,textdemo.gen,,textdemo.lst
..\bin\ConvSym.exe textdemo.lst textdemo.gen -input asm68k_lst -inopt "/localSign=. /localJoin=. /ignoreMacroDefs+ /ignoreMacroExp- /addMacrosAsOpcodes+" -a
..\bin\rompad.exe textdemo.gen 255 0
..\bin\fixheadr.exe textdemo.gen
pause