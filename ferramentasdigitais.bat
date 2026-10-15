```bat
@echo off
title Ferramentas Digitais
chcp 65001 >nul
color 09

goto menu


:: =========================================================
:: MENU PRINCIPAL
:: =========================================================
:menu
call :cabecalho
echo.
echo.
echo   [1]  LIMPEZA
echo        Ferramentas para disco e armazenamento
echo.
echo   [2]  REPAROS
echo        Diagnóstico e recuperação do Windows
echo.
echo   [3]  REDE
echo        Informações e comandos de conectividade
echo.
echo   [0]  SAIR
echo.
call :linha
echo.
set /p opcao="  Ir para: "

if "%opcao%"=="0" goto confirmarSaida
if "%opcao%"=="3" goto rede
if "%opcao%"=="2" goto reparo
if "%opcao%"=="1" goto limpeza

echo.
pause


:: =========================================================
:: LIMPEZA
:: =========================================================
:limpeza
call :TituloTela "LIMPEZA"
echo.
echo   [1]  cleanmgr
echo        Abre a Limpeza de Disco
echo.
echo   [2]  dism /Online /Cleanup-Image /StartComponentCleanup
echo        Limpa o armazenamento de componentes do Windows
echo.
echo   [3]  diskpart
echo        Abre o utilitário de partições
echo.
echo   [4]  format
echo        ATENÇÃO: Formata uma unidade
echo.
echo   [0]  Voltar ao menu principal
echo.
call :linha
echo.
set /p opcao="  Escolha: "

if "%opcao%"=="0" goto menu
if "%opcao%"=="4" goto format
if "%opcao%"=="3" goto diskpart
if "%opcao%"=="2" goto dism
if "%opcao%"=="1" goto cleanmgr

echo.
pause
goto menu


:: =========================================================
:: REPAROS
:: =========================================================
:reparo
call :TituloTela "REPAROS"
echo.
echo   [1]  sfc /scannow
echo        Verifica e repara arquivos do sistema
echo.
echo   [2]  chkdsk
echo        Verifica e repara erros no disco
echo.
echo   [3]  dism /Online /Cleanup-Image /CheckHealth
echo        Verifica a integridade da imagem do Windows
echo.
echo   [4]  dism /Online /Cleanup-Image /ScanHealth
echo        Verifica profundamente a integridade da imagem do Windows
echo.
echo   [5]  dism /Online /Cleanup-Image /RestoreHealth
echo        Repara a imagem do Windows
echo.
echo   [0]  Voltar ao menu principal
echo.
call :linha
echo.
set /p opcao="  Escolha: "

if "%opcao%"=="0" goto menu
if "%opcao%"=="5" goto dism3
if "%opcao%"=="4" goto dism2
if "%opcao%"=="3" goto dism1
if "%opcao%"=="2" goto chkdsk
if "%opcao%"=="1" goto sfc

echo.
pause
goto menu


:: =========================================================
:: REDE
:: =========================================================
:rede
call :TituloTela "REDE"
echo.
echo   [1]  ipconfig /all
echo        Exibe informações detalhadas da rede
echo.
echo   [2]  ipconfig /flushdns
echo        Limpa o cache DNS
echo.
echo   [3]  ipconfig /renew
echo        Renova o endereço IP atual
echo.
echo   [4]  ipconfig /release
echo        Libera o endereço IP atual
echo.
echo   [5]  ping google.com
echo        Testa a conectividade com o Google
echo.
echo   [6]  hostname
echo        Exibe o nome do computador
echo.
echo   [0]  Voltar ao menu principal
echo.
call :linha
echo.
set /p opcao="  Escolha: "

if "%opcao%"=="0" goto menu
if "%opcao%"=="6" goto hostname
if "%opcao%"=="5" goto ping
if "%opcao%"=="4" goto ipconfig3
if "%opcao%"=="3" goto ipconfig2
if "%opcao%"=="2" goto ipconfig1
if "%opcao%"=="1" goto ipconfig

echo.
pause
goto menu


:: =========================================================
:: ELEMENTOS VISUAIS
:: =========================================================
:cabecalho
cls
echo.
echo  ==========================================================
echo.
echo                  FERRAMENTAS DIGITAIS
echo                  PAINEL DE MANUTENÇÃO DO WINDOWS
echo.
echo  ==========================================================
exit /b

:linha
echo  ----------------------------------------------------------
exit /b

:mensagem
echo  %~1
exit /b

:erro
echo.
echo  [ERRO] %~1
echo.
exit /b

:TituloTela
cls
echo.
echo  ==========================================================
echo                         %~1
echo  ==========================================================
exit /b


:: =========================================================
:: SAÍDA
:: =========================================================
:confirmarSaida
echo.
choice /c SN /n /m "  Deseja realmente sair? (S/N)"
if errorlevel 2 goto menu
if errorlevel 1 exit
exit /b


:: =========================================================
:: COMANDOS DE LIMPEZA
:: =========================================================
:cleanmgr
cleanmgr
goto limpeza

:dism
dism /Online /Cleanup-Image /StartComponentCleanup
goto limpeza

:diskpart
diskpart
goto limpeza


:: =========================================================
:: FORMATAÇÃO
:: =========================================================
:format
cls
echo.
echo  ==========================================================
echo                       FORMATAR UNIDADE
echo  ==========================================================
echo.
echo  Unidades disponíveis:
echo.

(
echo list volume
) | diskpart

echo.
echo  ==========================================================
echo   ATENÇÃO: FORMATAR UMA UNIDADE APAGA TODOS OS SEUS DADOS!
echo  ==========================================================
echo.
echo.
echo   [0]  Voltar para Limpeza
echo.

set /p "disco=  Digite a letra da unidade (ex: D): "

set "disco=%disco::=%"

if "%disco%"=="0" goto limpeza

if /I "%disco%"=="C" (
    echo.
    echo  [ERRO] A unidade C: está protegida!
    echo  Por segurança, este script não permite formatá-la.
    pause
    goto format
)

if not "%disco:\~1%"=="" (
    echo.
    echo  [ERRO] Digite somente a letra da unidade.
    pause
    goto format
)

if "%disco%"=="" (
    echo.
    echo  [ERRO] Nenhuma unidade foi informada.
    pause
    goto format
)

if not exist "%disco%:\\" (
    echo.
    echo  [ERRO] A unidade %disco%: não foi encontrada.
    echo.
    pause
    goto format
)

echo.
echo  ==========================================================
echo   Unidade selecionada: %disco%:
echo  ==========================================================
echo.
echo  Escolha o tipo de formatação:
echo.
echo   [1]  Formatação rápida
echo   [2]  Formatação completa
echo   [3]  Cancelar
echo.

choice /C 123 /N /M "  Escolha uma opção: "

if errorlevel 3 goto limpeza
if errorlevel 2 goto format\_completa
if errorlevel 1 goto format\_rapida


:format\_rapida
cls
echo.
echo  ==========================================================
echo                     FORMATAÇÃO RÁPIDA
echo  ==========================================================
echo.
echo  Unidade: %disco%:
echo.
echo  ATENÇÃO: Todos os dados serão apagados!
echo.

choice /C SN /M "  Tem CERTEZA que deseja continuar?"

if errorlevel 2 goto menu

echo.
echo  Iniciando formatação rápida...
echo.

format %disco%: /Q

pause
goto menu


:format\_completa
cls
echo.
echo  ==========================================================
echo                    FORMATAÇÃO COMPLETA
echo  ==========================================================
echo.
echo  Unidade: %disco%:
echo.
echo  ATENÇÃO: Todos os dados serão apagados!
echo  A formatação completa pode demorar bastante.
echo.
echo  Em HDs grandes, isso pode levar horas.
echo.

choice /C SN /M "  Tem CERTEZA que deseja continuar?"

if errorlevel 2 goto menu

echo.
echo  Iniciando formatação completa...
echo.

format %disco%:

pause
goto limpeza


:: =========================================================
:: COMANDOS DE REPARO
:: =========================================================
:sfc
sfc /scannow
goto reparo

:chkdsk
chkdsk
goto reparo

:dism1
dism /Online /Cleanup-Image /CheckHealth
goto reparo

:dism2
dism /Online /Cleanup-Image /ScanHealth
goto reparo

:dism3
dism /Online /Cleanup-Image /RestoreHealth
goto reparo


:: =========================================================
:: COMANDOS DE REDE
:: =========================================================
:ipconfig
echo.
echo  Informações de rede:
echo.
ipconfig /all
echo.
pause
goto rede

:ipconfig1
ipconfig /flushdns
goto rede

:ipconfig2
ipconfig /renew
goto rede

:ipconfig3
ipconfig /release
goto rede

:ping
ping google.com
goto rede

:hostname
echo.
echo  Nome do computador:
echo.
hostname
echo.
pause
goto rede
```