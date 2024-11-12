@if exist Build @del /q Build
@echo.
@echo Compiling...
set fileName=DinoGame
C:\\cc65\bin\ca65 %fileName%.s -g -o %fileName%.o
@IF ERRORLEVEL 1 GOTO failure
@echo.
@echo Linking...
C:\\cc65\bin\ld65 -o %fileName%.nes -C %fileName%.cfg %fileName%.o -m %fileName%.map.txt -Ln %fileName%.labels.txt --dbgfile %fileName%.nes.dbg
@IF ERRORLEVEL 1 GOTO failure
@echo.
@mkdir Build
@move /y %fileName%.o Build 
@move /y %fileName%.nes Build
@move /y %fileName%.nes.dbg Build
@move /y %fileName%.map.txt Build
@move /y %fileName%.labels.txt Build
@echo Success!
@GOTO endbuild
:failure
@echo.
@echo Build error!
:endbuild