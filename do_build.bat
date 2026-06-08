@echo off
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"

echo === Runtime package ===
msbuild Source\Blinki.dproj /t:Build /p:Config=Release /p:Platform=Win32 /nologo /v:normal
if errorlevel 1 goto :error

echo === Smoke tests ===
msbuild Tests\SmokeTests\Blinki.SmokeTests.groupproj /t:Build /p:Config=Release /p:Platform=Win32 /nologo /v:minimal
if errorlevel 1 goto :error

echo === Demos ===
msbuild Demos\Blinki.Demos.groupproj /t:Build /p:Config=Release /p:Platform=Win32 /nologo /v:minimal
if errorlevel 1 goto :error

echo === Unit tests ===
msbuild Tests\UnitTests\BlinkiUnitTests.dproj /t:Build /p:Config=Release /p:Platform=Win32 /nologo /v:minimal
if errorlevel 1 goto :error

echo.
echo Build completed successfully.
goto :eof

:error
echo.
echo Build FAILED.
exit /b 1
