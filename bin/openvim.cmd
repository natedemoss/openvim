@echo off
REM openvim launcher (cmd.exe): boots Neovim against the bundled config.
nvim -u "%~dp0..\config\init.lua" %*
