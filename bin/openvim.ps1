#!/usr/bin/env pwsh
# openvim launcher: boots Neovim against the bundled openvim config.
$root = Split-Path -Parent $PSScriptRoot
$cfg = Join-Path $root 'config\init.lua'
& nvim -u $cfg @args
exit $LASTEXITCODE
