@echo off
cls
C:
cd C:\Administracao
Echo.
Echo.                        
Echo                      ****************************  
Echo                      *  Atualizando o Automec ..*
Echo                      *                          *
Echo                      *       MI-Informatica     *
Echo                      *                          * 
Echo                      *   Inicializando Processo *
Echo                      **************************** 
Echo.                                             
Echo.                          
Echo.
xcopy /s /e "\\SERVIDOR\Acessos\Automec.exe" "C:\Administracao" /y
start C:\administracao\Automec.exe
Echo.                        
Echo                      ****************************  
Echo                      *  Processo Finalizado.... *
Echo                      *                          *
Echo                      *       Com Sucesso        *
Echo                      *                          * 
Echo                      *                          *
Echo                      **************************** 
CLS
exit
