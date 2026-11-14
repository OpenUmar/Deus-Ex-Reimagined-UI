@echo off
rem Rebuilds the vanilla ReimaginedUI.u only (no launch), log in build_ri_vanilla.log
call "%~dp0Build_ReimaginedUI.cmd" Vanilla < nul > "%~dp0build_ri_vanilla.log" 2>&1
