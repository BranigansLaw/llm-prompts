@echo off
rem Shim so "git-cleanup" works from cmd.exe and PowerShell without PATHEXT edits.
rem Forwards all arguments to the PowerShell script next to this file.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0git-cleanup.ps1" %*
