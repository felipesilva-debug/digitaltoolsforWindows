#requires -Version 5.1
<#
.SYNOPSIS
    Painel interativo para diagnostico e manutencao do Windows.
.DESCRIPTION
    Execute no Windows PowerShell como administrador. As operacoes que removem
    dados, alteram a rede, reiniciam ou desligam o computador pedem confirmacao.
#>
[CmdletBinding()]
param(
    [switch] $NoElevation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-AsAdministrator {
    if ($NoElevation -or (Test-Administrator)) { return }
    Write-Host "`n  Solicitando permissao de administrador..." -ForegroundColor Yellow
    try {
        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments
        exit
    } catch {
        Write-Host "  [ERRO] A elevacao foi cancelada ou nao esta disponivel." -ForegroundColor Red
        exit 1
    }
}

Start-AsAdministrator

$script:LogFolder = Join-Path $env:ProgramData 'FerramentasDigitais\Logs'
$script:LogFile = Join-Path $script:LogFolder ('operacoes_{0}.log' -f (Get-Date -Format 'yyyy-MM-dd'))
try { New-Item -ItemType Directory -Force -Path $script:LogFolder | Out-Null } catch { }

function Write-Log {
    param([string] $Message, [ValidateSet('INFO','AVISO','ERRO')] [string] $Level = 'INFO')
    $entry = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    try { Add-Content -LiteralPath $script:LogFile -Value $entry -Encoding UTF8 } catch { }
}

function Show-Header {
    param([string] $Title = 'PAINEL DE MANUTENCAO DO WINDOWS')
    Clear-Host
    Write-Host ''
    Write-Host '  ================================================================' -ForegroundColor Cyan
    Write-Host '                       FERRAMENTAS DIGITAIS                       ' -ForegroundColor Cyan
    Write-Host ('  {0}' -f $Title) -ForegroundColor White
    Write-Host '  ================================================================' -ForegroundColor Cyan
    Write-Host ''
}

function Show-Line { Write-Host '  ----------------------------------------------------------------' -ForegroundColor DarkCyan }
function Wait-Return { Write-Host ''; Read-Host '  Pressione ENTER para continuar' | Out-Null }
function Read-Option { param([string] $Prompt = 'Escolha uma opcao'); return (Read-Host "  $Prompt").Trim() }
function Confirm-Action {
    param([string] $Question)
    return ((Read-Host "  $Question (S/N)").Trim() -match '^(s|sim|y|yes)$')
}

function Invoke-Tool {
    param([scriptblock] $Action, [string] $Description)
    try {
        Write-Log "Inicio: $Description"
        Write-Host "  Executando: $Description...`n" -ForegroundColor DarkGray
        $global:LASTEXITCODE = 0
        & $Action
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            throw "A ferramenta retornou o codigo $LASTEXITCODE."
        }
        Write-Host "`n  [OK] Operacao concluida." -ForegroundColor Green
        Write-Log "Concluido: $Description"
    } catch {
        Write-Host "`n  [ERRO] $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "$Description - $($_.Exception.Message)" 'ERRO'
    }
    Wait-Return
}

function Test-Command { param([string] $Name); return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
function Get-DefaultGateway {
    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Where-Object { $_.NextHop -ne '0.0.0.0' } |
        Sort-Object RouteMetric, InterfaceMetric | Select-Object -First 1
    if ($route) { return $route.NextHop }
    return $null
}

function Clear-SafeFolderContents {
    param([Parameter(Mandatory)] [string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $freed = 0
    Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            if (-not $_.PSIsContainer) { $freed += $_.Length }
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
        } catch { Write-Log "Nao foi possivel remover: $($_.FullName)" 'AVISO' }
    }
    return $freed
}

function Show-SystemInfo {
    Show-Header 'INFORMACOES DO COMPUTADOR'
    Invoke-Tool {
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $computer = Get-CimInstance Win32_ComputerSystem
        $bios = Get-CimInstance Win32_BIOS
        $uptime = (Get-Date) - $os.LastBootUpTime
        Write-Host "  Computador:       $env:COMPUTERNAME ($($computer.Manufacturer) - $($computer.Model))"
        Write-Host "  Usuario atual:    $env:USERNAME"
        Write-Host "  Sistema:          $($os.Caption) (Build $($os.BuildNumber), $($os.OSArchitecture))"
        Write-Host "  BIOS/UEFI:        $($bios.Manufacturer) - $($bios.SMBIOSBIOSVersion)"
        Write-Host ('  Tempo ligado:     {0}d {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
        Write-Host "  Processador:      $($cpu.Name.Trim())"
        Write-Host "  Nucleos:          $($cpu.NumberOfCores) fisicos / $($cpu.NumberOfLogicalProcessors) logicos"
        Write-Host ('  Memoria RAM:      {0:N2} GB total ({1:N2} GB livre)' -f ($computer.TotalPhysicalMemory / 1GB), ($os.FreePhysicalMemory / 1MB))
        Get-CimInstance Win32_VideoController | ForEach-Object { Write-Host "  Video:            $($_.Name)" }
        Write-Host "`n  Armazenamento local:" -ForegroundColor Cyan
        Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
            $total = $_.Size / 1GB; $free = $_.FreeSpace / 1GB
            $used = if ($total) { 100 * ($total - $free) / $total } else { 0 }
            Write-Host ('    {0}: {1:N2} GB livre de {2:N2} GB ({3:N1}% em uso)' -f $_.DeviceID, $free, $total, $used)
        }
        Write-Host "`n  Rede ativa:" -ForegroundColor Cyan
        Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' |
            ForEach-Object { Write-Host "    [$($_.Name)] $($_.InterfaceDescription) - $($_.LinkSpeed)" }
    } 'Consulta de informacoes do computador'
}

function Show-Temperature {
    Show-Header 'DIAGNOSTICO DE TEMPERATURA'
    Invoke-Tool {
        $zones = Get-CimInstance -Namespace 'root/wmi' -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        if (-not $zones) { Write-Host '  Nenhum sensor ACPI foi disponibilizado pelo firmware.' -ForegroundColor Yellow; return }
        foreach ($zone in $zones) {
            $temperature = ($zone.CurrentTemperature / 10) - 273.15
            $color = if ($temperature -ge 80) { 'Red' } elseif ($temperature -ge 65) { 'Yellow' } else { 'Green' }
            Write-Host ('  Sensor {0}: {1:N1} C' -f $zone.InstanceName, $temperature) -ForegroundColor $color
        }
        Write-Host "`n  Sensores ACPI podem nao representar a temperatura exata da CPU/GPU." -ForegroundColor DarkGray
    } 'Diagnostico de temperatura'
}

function Show-CleanMenu {
    while ($true) {
        Show-Header 'LIMPEZA E ARMAZENAMENTO'
        Write-Host '   [1]  Limpar temporarios e cache de download do Windows Update'
        Write-Host '   [2]  Esvaziar Lixeira de todas as unidades'
        Write-Host '   [3]  Abrir Limpeza de Disco do Windows'
        Write-Host '   [4]  Limpar componentes substituidos (DISM)'
        Write-Host '   [5]  Analisar tamanho da pasta WinSxS (DISM)'
        Write-Host '   [6]  Abrir Gerenciamento de Disco'
        Write-Host '   [0]  Voltar'
        Show-Line
        switch (Read-Option) {
            '0' { return }
            '1' { if (Confirm-Action 'Remover arquivos temporarios que nao estejam em uso?') { Invoke-Tool {
                    $paths = @($env:TEMP, (Join-Path $env:WINDIR 'Temp'), (Join-Path $env:WINDIR 'SoftwareDistribution\Download'))
                    $freed = 0; foreach ($path in $paths) { Write-Host "  Limpando: $path"; $freed += Clear-SafeFolderContents $path }
                    Write-Host ('  Espaco estimado liberado: {0:N2} MB' -f ($freed / 1MB))
                } 'Limpeza de arquivos temporarios' } }
            '2' { if (Confirm-Action 'Esvaziar permanentemente a Lixeira?') { Invoke-Tool { Clear-RecycleBin -Force } 'Esvaziamento da Lixeira' } }
            '3' { Invoke-Tool { Start-Process cleanmgr.exe } 'Abertura da Limpeza de Disco' }
            '4' { if (Confirm-Action 'Limpar componentes antigos do Windows?') { Invoke-Tool { & DISM.exe /Online /Cleanup-Image /StartComponentCleanup } 'Limpeza de componentes DISM' } }
            '5' { Invoke-Tool { & DISM.exe /Online /Cleanup-Image /AnalyzeComponentStore } 'Analise de componentes DISM' }
            '6' { Invoke-Tool { Start-Process diskmgmt.msc } 'Abertura do Gerenciamento de Disco' }
            default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
        }
    }
}

function Show-RepairMenu {
    while ($true) {
        Show-Header 'REPAROS E RECUPERACAO DO SISTEMA'
        Write-Host '   [1]  Verificar e reparar arquivos do sistema (SFC)'
        Write-Host '   [2]  Verificar disco (CHKDSK somente leitura)'
        Write-Host '   [3]  Agendar reparo completo de disco no proximo boot (CHKDSK /F /R)'
        Write-Host '   [4]  Verificar imagem do Windows (DISM CheckHealth)'
        Write-Host '   [5]  Analisar imagem do Windows (DISM ScanHealth)'
        Write-Host '   [6]  Reparar imagem do Windows (DISM RestoreHealth)'
        Write-Host '   [7]  Criar ponto de restauracao'
        Write-Host '   [0]  Voltar'
        Show-Line
        switch (Read-Option) {
            '0' { return }
            '1' { Invoke-Tool { & sfc.exe /scannow } 'Verificacao SFC' }
            '2' { Invoke-Tool { & chkdsk.exe $env:SystemDrive } 'Verificacao CHKDSK' }
            '3' { if (Confirm-Action 'Agendar verificacao completa para a proxima reinicializacao?') { Invoke-Tool { cmd.exe /c "echo S|chkdsk $env:SystemDrive /f /r" } 'Agendamento CHKDSK' } }
            '4' { Invoke-Tool { & DISM.exe /Online /Cleanup-Image /CheckHealth } 'DISM CheckHealth' }
            '5' { Invoke-Tool { & DISM.exe /Online /Cleanup-Image /ScanHealth } 'DISM ScanHealth' }
            '6' { Invoke-Tool { & DISM.exe /Online /Cleanup-Image /RestoreHealth } 'DISM RestoreHealth' }
            '7' { $name = Read-Host '  Descricao (ENTER para nome padrao)'; if ([string]::IsNullOrWhiteSpace($name)) { $name = 'Ferramentas Digitais - ' + (Get-Date -Format 'yyyy-MM-dd HH-mm') }; Invoke-Tool {
                    Enable-ComputerRestore -Drive "$env:SystemDrive\"
                    Checkpoint-Computer -Description $name -RestorePointType MODIFY_SETTINGS
                } "Criacao de ponto de restauracao: $name" }
            default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
        }
    }
}

function Show-NetworkMenu {
    while ($true) {
        Show-Header 'REDE E CONECTIVIDADE'
        Write-Host '   [1]  Exibir configuracao detalhada (IPConfig /all)'
        Write-Host '   [2]  Testar gateway/roteador'
        Write-Host '   [3]  Testar internet e resolucao DNS'
        Write-Host '   [4]  Teste de velocidade de download (10 MB)'
        Write-Host '   [5]  Limpar cache DNS'
        Write-Host '   [6]  Renovar endereco IP'
        Write-Host '   [7]  Resetar TCP/IP e Winsock (requer reinicializacao)'
        Write-Host '   [8]  Exibir conexoes TCP estabelecidas'
        Write-Host '   [0]  Voltar'
        Show-Line
        switch (Read-Option) {
            '0' { return }
            '1' { Invoke-Tool { & ipconfig.exe /all } 'Consulta de configuracao de rede' }
            '2' { Invoke-Tool { $gateway = Get-DefaultGateway; if ($gateway) { Write-Host "  Gateway: $gateway"; Test-Connection -ComputerName $gateway -Count 4 | Format-Table -AutoSize } else { Write-Host '  Nenhum gateway IPv4 encontrado.' -ForegroundColor Yellow } } 'Teste do gateway' }
            '3' { Invoke-Tool { Test-Connection -ComputerName '1.1.1.1' -Count 4 | Format-Table -AutoSize; Resolve-DnsName 'cloudflare.com' -ErrorAction Stop | Select-Object -First 3 Name,Type,IPAddress | Format-Table -AutoSize } 'Teste de internet e DNS' }
            '4' { Invoke-Tool {
                    $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
                    try { $stopwatch = [Diagnostics.Stopwatch]::StartNew(); $response = Invoke-WebRequest -Uri 'https://speed.cloudflare.com/__down?bytes=10000000' -UseBasicParsing -TimeoutSec 30; $stopwatch.Stop(); if ($stopwatch.Elapsed.TotalSeconds -eq 0) { throw 'Tempo de teste invalido.' }; $mbps = (($response.Content.Length * 8 / 1MB) / $stopwatch.Elapsed.TotalSeconds); Write-Host ('  Velocidade: {0:N2} Mbps ({1:N2} s)' -f $mbps, $stopwatch.Elapsed.TotalSeconds) } finally { $ProgressPreference = $old }
                } 'Teste de velocidade de download' }
            '5' { Invoke-Tool { Clear-DnsClientCache } 'Limpeza de cache DNS' }
            '6' { if (Confirm-Action 'Renovar endereco IP? A conexao pode cair brevemente') { Invoke-Tool { & ipconfig.exe /release; & ipconfig.exe /renew } 'Renovacao de endereco IP' } }
            '7' { if (Confirm-Action 'Resetar Winsock e TCP/IP? Reinicie ao final') { Invoke-Tool { & netsh.exe winsock reset; & netsh.exe int ip reset; Clear-DnsClientCache } 'Reset completo de rede' } }
            '8' { Invoke-Tool { Get-NetTCPConnection -State Established | Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess,@{Name='Processo';Expression={ (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName }} | Format-Table -AutoSize } 'Listagem de conexoes TCP' }
            default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
        }
    }
}

function Show-SoftwareMenu {
    while ($true) {
        Show-Header 'PROGRAMAS E ATUALIZACOES'
        Write-Host '   [1]  Listar atualizacoes disponiveis (Winget)'
        Write-Host '   [2]  Atualizar todos os programas (Winget)'
        Write-Host '   [3]  Listar programas na inicializacao'
        Write-Host '   [4]  Abrir Programas e Recursos'
        Write-Host '   [0]  Voltar'
        Show-Line
        switch (Read-Option) {
            '0' { return }
            '1' { Invoke-Tool { if (-not (Test-Command 'winget.exe')) { throw 'Winget nao esta instalado.' }; & winget.exe upgrade } 'Verificacao de atualizacoes' }
            '2' { if (Confirm-Action 'Atualizar todos os programas detectados pelo Winget?') { Invoke-Tool { if (-not (Test-Command 'winget.exe')) { throw 'Winget nao esta instalado.' }; & winget.exe upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements } 'Atualizacao global de aplicativos' } }
            '3' { Invoke-Tool { Get-CimInstance Win32_StartupCommand | Select-Object Name,User,Location,Command | Format-Table -Wrap -AutoSize } 'Listagem de inicializacao' }
            '4' { Invoke-Tool { Start-Process appwiz.cpl } 'Abertura de Programas e Recursos' }
            default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
        }
    }
}

function Show-BackupMenu {
    Show-Header 'BACKUP DE ARQUIVOS (ROBOCOPY)'
    $source = (Read-Host '  Pasta de origem (ENTER para cancelar)').Trim('"',' ')
    if ([string]::IsNullOrWhiteSpace($source)) { return }
    $destination = (Read-Host '  Pasta de destino').Trim('"',' ')
    if (-not (Test-Path -LiteralPath $source)) { Write-Host '  [ERRO] Origem inexistente.' -ForegroundColor Red; Wait-Return; return }
    if ([string]::IsNullOrWhiteSpace($destination)) { Write-Host '  [ERRO] Destino invalido.' -ForegroundColor Red; Wait-Return; return }
    $sourceFull = [IO.Path]::GetFullPath($source).TrimEnd('\')
    $destinationFull = [IO.Path]::GetFullPath($destination).TrimEnd('\')
    if ($sourceFull -eq $destinationFull -or $destinationFull.StartsWith($sourceFull + '\', [StringComparison]::OrdinalIgnoreCase)) { Write-Host '  [ERRO] O destino nao pode ser a origem ou uma subpasta dela.' -ForegroundColor Red; Wait-Return; return }
    if (-not (Test-Path -LiteralPath $destinationFull)) { New-Item -ItemType Directory -Force -Path $destinationFull | Out-Null }
    if (Confirm-Action "Iniciar backup de '$sourceFull' para '$destinationFull'?") { Invoke-Tool {
            & robocopy.exe $sourceFull $destinationFull /E /COPY:DAT /DCOPY:DAT /R:2 /W:2 /FFT /MT:8
            if ($LASTEXITCODE -gt 7) { throw "Robocopy encontrou falhas (codigo $LASTEXITCODE)." }
            $global:LASTEXITCODE = 0
        } "Backup de '$sourceFull' para '$destinationFull'" }
}

function Show-PrintersMenu {
    while ($true) {
        Show-Header 'IMPRESSORAS E SPOOLER'
        Write-Host '   [1]  Listar impressoras e status'
        Write-Host '   [2]  Abrir fila de impressao'
        Write-Host '   [3]  Enviar pagina de teste'
        Write-Host '   [4]  Reiniciar servico Spooler'
        Write-Host '   [5]  Limpar fila travada (cancela todos os documentos)'
        Write-Host '   [6]  Abrir configuracoes de impressoras'
        Write-Host '   [0]  Voltar'
        Show-Line
        switch (Read-Option) {
            '0' { return }
            '1' { Invoke-Tool { Get-CimInstance Win32_Printer | Select-Object Name,Default,WorkOffline,PrinterStatus,PortName | Format-Table -AutoSize } 'Consulta de impressoras' }
            '2' { $name = (Read-Host '  Nome exato da impressora').Trim(); if ($name) { Invoke-Tool { Start-Process rundll32.exe -ArgumentList "printui.dll,PrintUIEntry /o /n `"$name`"" } "Abertura da fila: $name" } }
            '3' { $name = (Read-Host '  Nome exato da impressora').Trim(); if ($name) { Invoke-Tool { $safe = $name.Replace("'", "''"); $printer = Get-CimInstance Win32_Printer -Filter "Name='$safe'"; if (-not $printer) { throw "Impressora '$name' nao encontrada." }; Invoke-CimMethod -InputObject $printer -MethodName PrintTestPage | Out-Null } "Pagina de teste: $name" } }
            '4' { if (Confirm-Action 'Reiniciar o Spooler?') { Invoke-Tool { Restart-Service -Name Spooler -Force } 'Reinicio do Spooler' } }
            '5' { if (Confirm-Action 'Cancelar TODOS os documentos da fila?') { Invoke-Tool { Stop-Service -Name Spooler -Force; Get-ChildItem -LiteralPath (Join-Path $env:SystemRoot 'System32\spool\PRINTERS') -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue; Start-Service -Name Spooler } 'Limpeza da fila do Spooler' } }
            '6' { Invoke-Tool { Start-Process 'ms-settings:printers' } 'Abertura de configuracoes de impressora' }
            default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
        }
    }
}

function Show-HardwareMenu {
    while ($true) {
        Show-Header 'DIAGNOSTICO DE HARDWARE'
        Write-Host '   [1]  Resumo de CPU, GPU, RAM e discos'
        Write-Host '   [2]  Diagnostico de temperatura'
        Write-Host '   [3]  Verificar estado dos discos'
        Write-Host '   [4]  Gerar relatorio da bateria'
        Write-Host '   [5]  Abrir Diagnostico de Memoria'
        Write-Host '   [6]  Abrir DxDiag'
        Write-Host '   [7]  Abrir Gerenciador de Dispositivos'
        Write-Host '   [0]  Voltar'
        Show-Line
        switch (Read-Option) {
            '0' { return }; '1' { Show-SystemInfo }; '2' { Show-Temperature }
            '3' { Invoke-Tool { Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,@{Name='Tamanho(GB)';Expression={[math]::Round($_.Size / 1GB,2)}} | Format-Table -AutoSize } 'Consulta de discos' }
            '4' { Invoke-Tool { $report = Join-Path $env:TEMP 'battery-report.html'; & powercfg.exe /batteryreport /output $report; if (Test-Path -LiteralPath $report) { Write-Host "  Relatorio: $report"; Start-Process $report } else { Write-Host '  Nenhuma bateria detectada.' -ForegroundColor Yellow } } 'Geracao de relatorio de bateria' }
            '5' { Invoke-Tool { Start-Process mdsched.exe } 'Abertura do Diagnostico de Memoria' }
            '6' { Invoke-Tool { Start-Process dxdiag.exe } 'Abertura do DxDiag' }
            '7' { Invoke-Tool { Start-Process devmgmt.msc } 'Abertura do Gerenciador de Dispositivos' }
            default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
        }
    }
}

function Show-PowerMenu {
    while ($true) {
        Show-Header 'ENERGIA E DESEMPENHO'
        Write-Host '   [1]  Reiniciar computador agora'
        Write-Host '   [2]  Desligar computador agora'
        Write-Host '   [3]  Reiniciar diretamente na BIOS/UEFI'
        Write-Host '   [4]  Adicionar plano Desempenho Maximo'
        Write-Host '   [0]  Voltar'
        Show-Line
        switch (Read-Option) {
            '0' { return }
            '1' { if (Confirm-Action 'Reiniciar agora? Salve seu trabalho antes') { Write-Log 'Reinicio solicitado'; Restart-Computer -Force } }
            '2' { if (Confirm-Action 'Desligar agora? Salve seu trabalho antes') { Write-Log 'Desligamento solicitado'; Stop-Computer -Force } }
            '3' { if (Confirm-Action 'Reiniciar diretamente no Setup UEFI/BIOS?') { Invoke-Tool { & shutdown.exe /r /fw /t 0 } 'Reinicio para o firmware UEFI' } }
            '4' { Invoke-Tool { & powercfg.exe -duplicatescheme 'e9a42b02-d5df-448d-aa00-03f14749eb61'; Start-Process powercfg.cpl } 'Adicao do plano Desempenho Maximo' }
            default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
        }
    }
}

Write-Log "Aplicacao iniciada por $env:USERNAME em $env:COMPUTERNAME"
:MainLoop while ($true) {
    Show-Header
    Write-Host '   [1]  LIMPEZA                 Temporarios, Lixeira e disco'
    Write-Host '   [2]  REPAROS                 SFC, DISM, CHKDSK e Restauracao'
    Write-Host '   [3]  REDE                    Diagnostico, velocidade e reset'
    Write-Host '   [4]  PROGRAMAS               Atualizacoes e inicializacao'
    Write-Host '   [5]  COMPUTADOR              Resumo completo do sistema'
    Write-Host '   [6]  HARDWARE                Sensores, memoria, bateria e discos'
    Write-Host '   [7]  IMPRESSORAS             Filas, testes e Spooler'
    Write-Host '   [8]  BACKUP                  Copia incremental segura'
    Write-Host '   [9]  ENERGIA                 Energia, BIOS/UEFI e desempenho'
    Write-Host '   [L]  ABRIR LOGS'
    Write-Host '   [0]  SAIR'
    Show-Line
    switch ((Read-Option 'Ir para').ToUpperInvariant()) {
        '0' { if (Confirm-Action 'Deseja realmente sair?') { Write-Log 'Aplicacao encerrada pelo usuario'; break MainLoop } }
        '1' { Show-CleanMenu }; '2' { Show-RepairMenu }; '3' { Show-NetworkMenu }; '4' { Show-SoftwareMenu }
        '5' { Show-SystemInfo }; '6' { Show-HardwareMenu }; '7' { Show-PrintersMenu }; '8' { Show-BackupMenu }; '9' { Show-PowerMenu }
        'L' { Invoke-Tool { Start-Process notepad.exe $script:LogFile } 'Abertura do arquivo de log' }
        default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
    }
}
Clear-Host
Write-Host "`n  Obrigado por utilizar o painel Ferramentas Digitais!`n" -ForegroundColor Cyan
