@echo off
rem Starts the emulator created by setup.ps1. Usage: start-emulator.cmd [avd name]
set AVD=%~1
if "%AVD%"=="" set AVD=claude
if "%ANDROID_HOME%"=="" set ANDROID_HOME=C:\Android\Sdk
if "%ANDROID_USER_HOME%"=="" set ANDROID_USER_HOME=C:\Android\home
if "%ANDROID_AVD_HOME%"=="" set ANDROID_AVD_HOME=%ANDROID_USER_HOME%\avd
set ANDROID_SDK_ROOT=%ANDROID_HOME%
start "" "%ANDROID_HOME%\emulator\emulator.exe" -avd %AVD% -no-boot-anim
