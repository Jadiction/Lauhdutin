@echo off
cls
echo Parsing shortcuts in %1
cd "%~dp0"
set "parser="%cd%\parser.vbs""
cd ..\..\..
if not exist "%cd%\Shortcuts" mkdir "%cd%\Shortcuts"
cd cache
if not exist "%cd%\shortcuts" mkdir "%cd%\shortcuts"
cd shortcuts
set "output="%cd%\output.txt""
cd %1
for /R %%F in (*.lnk) do (
	echo %%F >> %output%
	wscript %parser% "%%~fF" >> %output%
)
for /R %%F in (*.url) do (
	echo %%F >> %output%
	wscript %parser% "%%~fF" >> %output%
)
set "rainmeter="%~2\Rainmeter.exe""
start /B "" %rainmeter% !CommandMeasure "Script" "OnParsedShortcuts()" %3
::pause
