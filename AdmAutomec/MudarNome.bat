@echo off
setlocal EnableExtensions
title Trocar apenas o nome "SERVIDOR" nas 3 linhas do start.ini

rem Arquivo alvo na pasta atual
set "ARQ=start.ini"

if not exist "%ARQ%" (
  echo [ERRO] start.ini nao encontrado nesta pasta.
  pause & exit /b 1
)

rem Pede o nome do servidor (Enter mantem SERVIDOR)
set "PADRAO=SERVIDOR"
set /p "NOME=Digite o nome do servidor (Enter mantem %PADRAO%): "
if not defined NOME set "NOME=%PADRAO%"
if "%NOME:~-1%"==":" set "NOME=%NOME:~0,-1%"

rem ---- Edicao direta via PowerShell (preserva restante da linha e formatacao) ----
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$f=$env:ARQ; $s=$env:NOME; $enc=[Text.Encoding]::Default;" ^
"$t=[IO.File]::ReadAllText($f,$enc);" ^
"$t=[regex]::Replace($t,'(?im)^(\\s*Path\\s+Automec\\s*=)SERVIDOR(:?)',{param($m) $m.Groups[1].Value + $s + $m.Groups[2].Value});" ^
"$t=[regex]::Replace($t,'(?im)^(\\s*Path\\s+PontualCentral\\s*=)SERVIDOR(:?)',{param($m) $m.Groups[1].Value + $s + $m.Groups[2].Value});" ^
"$t=[regex]::Replace($t,'(?im)^(\\s*Path\\s+CLIMB\\s*=)SERVIDOR(:?)',{param($m) $m.Groups[1].Value + $s + $m.Groups[2].Value});" ^
"[IO.File]::WriteAllText($f,$t,$enc);"

if errorlevel 1 (
  echo [ERRO] Nao foi possivel editar "%ARQ%". Verifique se o arquivo esta aberto ou somente leitura.
) else (
  echo [OK] Ajuste concluido.
)
pause
