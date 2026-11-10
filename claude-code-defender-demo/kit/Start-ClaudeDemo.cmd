@echo off
title Claude Code - Defender AI agent runtime protection demo
set "CLAUDE_CONFIG_DIR=C:\Demo\claude-config"
set "CLAUDE_CODE_USE_FOUNDRY=1"
set "ANTHROPIC_FOUNDRY_BASE_URL=http://127.0.0.1:8787/anthropic"
set "ANTHROPIC_FOUNDRY_API_KEY=<PLACEHOLDER_KEY>"
set "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
powershell -NoProfile -Command "if (-not (Get-NetTCPConnection -LocalPort 8787 -State Listen -ErrorAction SilentlyContinue)) { Start-Process 'C:\Program Files\nodejs\node.exe' -ArgumentList 'C:\Demo\tools\model-stub.js' -WindowStyle Hidden; Start-Sleep -Seconds 2 }"
cd /d C:\Demo
echo.
echo   Claude Code is using a local stub model: nothing leaves this VM and no account is needed.
echo   Paste the prompt from C:\Demo\test-prompt.txt. Defender blocks it before any model sees it.
echo.
claude
