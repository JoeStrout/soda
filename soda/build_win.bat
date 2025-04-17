@echo off
cls

echo --------              --------
echo -------- build start. --------
echo --------              --------

:check

if defined VSCMD_ARG_TGT_ARCH (
	goto build
)

:nobuild
	echo error!
	echo this prompt calls no VS BuildTools.
	echo Please execute build_win.bat in Developer Command Prompt 
	echo or x86/x64 Native Tools Command Prompt
	echo --------- build stopped. --------
	echo Please press Enter to continue the program...
	set /p dummy=
	goto finish


:build
	echo %VCToolsInstallDir% is BuildTools installed path.
	echo this prompt calls %VSCMD_ARG_TGT_ARCH% build applications.
	echo If you are told that a library or include file does not exist, 
	echo please check the "include" and "lib" folders in the above path.

	echo -------- move folder. --------
	rem move to src folder.
	@echo on
	cd src
	@echo off
	
	rem compile command.
	echo -------- compile programs. --------
	@echo on
	cl -I . -I MiniScript -I compiledData -I SDL2 /EHsc /wd4068 /source-charset:utf-8 /execution-charset:utf-8 ./*.cpp ./MiniScript/*.cpp ./compiledData/*.c /Fesoda.exe /link /LIBPATH:./SDL2/SDL2_2/lib/%VSCMD_ARG_TGT_ARCH% /LIBPATH:./SDL2/SDL2_image/lib/%VSCMD_ARG_TGT_ARCH% /LIBPATH:./SDL2/SDL2_mixer/lib/%VSCMD_ARG_TGT_ARCH% SDL2.lib SDL2main.lib SDL2_image.lib SDL2_mixer.lib Shell32.lib /SUBSYSTEM:console
	@echo off
	
	rem move executable file to upper folder.
	if %ERRORLEVEL% equ 0 (
		echo -------- build succeed. --------
		echo this build program made %VSCMD_ARG_TGT_ARCH% executable file.
		if %VSCMD_ARG_TGT_ARCH% equ x86 (
			rem 32bit exe file.
			move soda.exe ../soda_x86.exe
		) else if %VSCMD_ARG_TGT_ARCH% equ x64 (
			rem 64bit exe file.
			move soda.exe ../soda_x64.exe
		) else (
			rem other build arch.(I think that is not existed)
			move soda.exe ../soda.exe
		)
	) else (
		echo -------- build failed. --------
	)

	rem leave src folder.
	cd ..

:finish
	echo -------- build program end. --------


