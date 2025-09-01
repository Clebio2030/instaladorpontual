@echo off
:: Copiar o arquivo para System32
copy "C:\Administracao\RBuilder.ini" "C:\Windows\System32\" /Y

:: Copiar o arquivo para SysWOW64
copy "C:\Administracao\RBuilder.ini" "C:\Windows\SysWOW64\" /Y

:: Definir permissões (System32)
icacls "C:\Windows\System32\rbuilder.ini" /grant:r Todos:(F) /c >nul 2>&1

:: Definir permissões (SysWOW64)
icacls "C:\Windows\SysWOW64\rbuilder.ini" /grant:r Todos:(F) /c >nul 2>&1

echo Operação concluída.
pause
