#requires -version 5.1
<#+
Ferramentas Digitais - painel de manutenção do Windows
Execute pelo arquivo .cmd ao lado para obter elevação automática.
#>
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$ErrorActionPreference = 'Stop'

$LogFolder = Join-Path $env:ProgramData 'FerramentasDigitais\Logs'
New-Item -ItemType Directory -Force -Path $LogFolder | Out-Null
$LogFile = Join-Path $LogFolder ("operacoes_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd'))

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','AVISO','ERRO')] [string]$Level = 'INFO')
    $entry = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $LogFile -Value $entry -Encoding UTF8
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-AsAdministrator {
    try {
    Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class ConsoleFont {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct FontInfo {
        public uint cbSize;
        public uint nFont;
        public short FontSizeX;
        public short FontSizeY;
        public int FontFamily;
        public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string FaceName;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetCurrentConsoleFontEx(
        IntPtr hConsoleOutput, bool maximumWindow, ref FontInfo info);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetCurrentConsoleFontEx(
        IntPtr hConsoleOutput, bool maximumWindow, ref FontInfo info);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetStdHandle(int handle);
}
'@

    $font = New-Object ConsoleFont+FontInfo
    $font.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($font)
    $handle = [ConsoleFont]::GetStdHandle(-11)

    if ([ConsoleFont]::GetCurrentConsoleFontEx($handle, $false, [ref]$font)) {
        $font.FontSizeY = 22 # Aumente este valor para letras maiores
        [void][ConsoleFont]::SetCurrentConsoleFontEx($handle, $false, [ref]$font)
    }
} catch {
    # Mantém a execução mesmo se o console não permitir alterar a fonte
}
    if (Test-Administrator) { return }
    Write-Host '  Solicitando permissao de administrador...' -ForegroundColor Yellow
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
        exit
    } catch {
        Write-Host '  A execucao como administrador foi cancelada.' -ForegroundColor Red
        Start-Sleep -Seconds 2
        exit 1
    }
}

function Show-Line { Write-Host '  ----------------------------------------------------------' -ForegroundColor DarkCyan }
function Show-Header {
    param([string]$Title = 'PAINEL DE MANUTENCAO DO WINDOWS')
    Clear-Host
    Write-Host ''
    Write-Host '  ==========================================================' -ForegroundColor Cyan
    Write-Host '                  FERRAMENTAS DIGITAIS' -ForegroundColor Cyan
    Write-Host ("                  {0}" -f $Title) -ForegroundColor White
    Write-Host '  ==========================================================' -ForegroundColor Cyan
    Write-Host ''
}
function Wait-Return { Write-Host ''; Read-Host '  Pressione ENTER para continuar' | Out-Null }
function Read-Option([string]$Prompt = 'Escolha') { return (Read-Host "  $Prompt").Trim() }
function Confirm([string]$Question) { return (Read-Host "  $Question (S/N)").Trim() -match '^(s|sim)$' }
function Invoke-Tool {
    param([scriptblock]$Action, [string]$Description)
    try { Write-Log "Inicio: $Description"; & $Action; Write-Log "Concluido: $Description" }
    catch { Write-Host "`n  [ERRO] $($_.Exception.Message)" -ForegroundColor Red; Write-Log "$Description - $($_.Exception.Message)" 'ERRO' }
    Wait-Return
}
function Get-Gateway {
    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Where-Object NextHop -ne '0.0.0.0' | Sort-Object RouteMetric, InterfaceMetric | Select-Object -First 1
    if ($route) { $route.NextHop } else { $null }
}

function Show-SystemInfo {
    Show-Header 'INFORMACOES DO COMPUTADOR'
    Invoke-Tool {
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $cs = Get-CimInstance Win32_ComputerSystem
        Write-Host "  Computador: $env:COMPUTERNAME"
        Write-Host "  Usuario:    $env:USERNAME"
        Write-Host "  Windows:    $($os.Caption) ($($os.Version))"
        Write-Host "  CPU:        $($cpu.Name.Trim())"
        Write-Host "  Nucleos:    $($cpu.NumberOfCores) fisicos / $($cpu.NumberOfLogicalProcessors) logicos"
        Write-Host ('  RAM:        {0:N2} GB' -f ($cs.TotalPhysicalMemory / 1GB))
        Write-Host "`n  Armazenamento local:"
        Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
            Write-Host ('    {0}  Livre: {1:N2} GB | Total: {2:N2} GB' -f $_.DeviceID,($_.FreeSpace/1GB),($_.Size/1GB))
        }
        Write-Host "`n  Adaptadores de rede ativos:"
        Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object { Write-Host "    $($_.Name) - $($_.LinkSpeed)" }
    } 'Consulta de informacoes do computador'
}

function Show-Temperature {
    Show-Header 'DIAGNOSTICO DE TEMPERATURA'
    Invoke-Tool {
        $zones = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        if ($zones) {
            $zones | ForEach-Object { Write-Host ('  Sensor {0}: {1:N1} °C' -f $_.InstanceName, (($_.CurrentTemperature / 10) - 273.15)) }
            Write-Host "`n  Observacao: estes sensores geralmente refletem zonas ACPI, nao necessariamente a CPU."
        } else {
            Write-Host '  Nenhum sensor ACPI foi disponibilizado pelo firmware.' -ForegroundColor Yellow
            Write-Host '  Para temperaturas precisas de CPU/GPU, use a ferramenta do fabricante ou HWiNFO.'
        }
    } 'Diagnostico de temperatura'
}

function Show-CleanMenu {
    while ($true) {
        Show-Header 'LIMPEZA E ARMAZENAMENTO'
        Write-Host '   [1]  Limpar arquivos temporarios do usuario e Windows'
        Write-Host '   [2]  Abrir Limpeza de Disco'
        Write-Host '   [3]  Limpar componentes substituidos do Windows (DISM)'
        Write-Host '   [4]  Abrir Gerenciamento de Disco'
        Write-Host '   [0]  Voltar ao menu principal'
        Show-Line; $op = Read-Option
        switch ($op) {
            '0' { return }
            '1' {
                Show-Header 'LIMPEZA DE TEMPORARIOS'
                if (Confirm 'Remover arquivos temporarios que nao estejam em uso?') {
                    Invoke-Tool {
                        $paths = @($env:TEMP, "$env:WINDIR\Temp") | Where-Object { Test-Path $_ }
                        $count = 0
                        foreach ($path in $paths) {
                            Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                            $count++
                        }
                        Write-Host "  Limpeza concluida em $count local(is). Arquivos em uso foram preservados."
                    } 'Limpeza de arquivos temporarios'
                }
            }
            '2' { Invoke-Tool { Start-Process cleanmgr.exe } 'Abertura da Limpeza de Disco' }
            '3' { Invoke-Tool { DISM.exe /Online /Cleanup-Image /StartComponentCleanup } 'Limpeza de componentes DISM' }
            '4' { Invoke-Tool { Start-Process diskmgmt.msc } 'Abertura do Gerenciamento de Disco' }
            default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
        }
    }
}

function Show-RepairMenu {
    while ($true) {
        Show-Header 'REPAROS E RECUPERACAO'
        Write-Host '   [1]  Verificar arquivos do sistema (SFC)'
        Write-Host '   [2]  Verificar disco (CHKDSK, leitura)'
        Write-Host '   [3]  Verificar imagem do Windows (DISM CheckHealth)'
        Write-Host '   [4]  Analisar imagem do Windows (DISM ScanHealth)'
        Write-Host '   [5]  Reparar imagem do Windows (DISM RestoreHealth)'
        Write-Host '   [6]  Criar ponto de restauracao'
        Write-Host '   [0]  Voltar ao menu principal'
        Show-Line; $op = Read-Option
        switch ($op) {
            '0' { return }
            '1' { Invoke-Tool { sfc.exe /scannow } 'SFC /scannow' }
            '2' { Invoke-Tool { chkdsk.exe } 'CHKDSK' }
            '3' { Invoke-Tool { DISM.exe /Online /Cleanup-Image /CheckHealth } 'DISM CheckHealth' }
            '4' { Invoke-Tool { DISM.exe /Online /Cleanup-Image /ScanHealth } 'DISM ScanHealth' }
            '5' { Invoke-Tool { DISM.exe /Online /Cleanup-Image /RestoreHealth } 'DISM RestoreHealth' }
            '6' {
                Show-Header 'PONTO DE RESTAURACAO'
                $name = Read-Host '  Descricao do ponto (ENTER para usar a data atual)'
                if ([string]::IsNullOrWhiteSpace($name)) { $name = "Ferramentas Digitais - $(Get-Date -Format 'yyyy-MM-dd HH-mm')" }
                Invoke-Tool { Enable-ComputerRestore -Drive "$env:SystemDrive\"; Checkpoint-Computer -Description $name -RestorePointType MODIFY_SETTINGS; Write-Host '  Ponto de restauracao criado.' } "Criacao de ponto de restauracao: $name"
            }
            default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
        }
    }
}

function Show-NetworkMenu {
    while ($true) {
        Show-Header 'REDE E CONECTIVIDADE'
        Write-Host '   [1]  Exibir configuracao detalhada de rede'
        Write-Host '   [2]  Testar conectividade com o gateway'
        Write-Host '   [3]  Testar internet e latencia (Cloudflare)'
        Write-Host '   [4]  Teste de velocidade de download (~10 MB)'
        Write-Host '   [5]  Limpar cache DNS'
        Write-Host '   [6]  Renovar endereco IP'
        Write-Host '   [7]  Liberar endereco IP'
        Write-Host '   [0]  Voltar ao menu principal'
        Show-Line; $op = Read-Option
        switch ($op) {
            '0' { return }
            '1' { Invoke-Tool { ipconfig.exe /all } 'Consulta de configuracao de rede' }
            '2' { Invoke-Tool { $g = Get-Gateway; if ($g) { Write-Host "  Gateway detectado: $g"; Test-Connection -ComputerName $g -Count 4 | Format-Table -AutoSize } else { Write-Host '  Nenhum gateway IPv4 padrao foi encontrado.' -ForegroundColor Yellow } } 'Teste do gateway' }
            '3' { Invoke-Tool { Test-Connection -ComputerName '1.1.1.1' -Count 4 | Format-Table -AutoSize; Resolve-DnsName 'cloudflare.com' | Select-Object -First 3 Name,IPAddress | Format-Table -AutoSize } 'Teste de internet e DNS' }
            '4' { Invoke-Tool { $url='https://speed.cloudflare.com/__down?bytes=10000000'; $sw=[Diagnostics.Stopwatch]::StartNew(); $response=Invoke-WebRequest -Uri $url -UseBasicParsing; $sw.Stop(); $mbps=(($response.Content.Length*8/1MB)/$sw.Elapsed.TotalSeconds); Write-Host ('  Download: {0:N2} Mbps em {1:N2} s' -f $mbps,$sw.Elapsed.TotalSeconds) } 'Teste de velocidade de download' }
            '5' { Invoke-Tool { Clear-DnsClientCache; Write-Host '  Cache DNS limpo.' } 'Limpeza de cache DNS' }
            '6' { Invoke-Tool { ipconfig.exe /renew } 'Renovacao de endereco IP' }
            '7' { if (Confirm 'Liberar o endereco IP atual? A rede pode desconectar temporariamente') { Invoke-Tool { ipconfig.exe /release } 'Liberacao de endereco IP' } }
            default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
        }
    }
}

function Show-BackupMenu {
    Show-Header 'BACKUP DE ARQUIVOS'
    Write-Host '  Informe uma pasta de origem e uma pasta de destino.'
    Write-Host '  O backup copia arquivos novos e atualizados; nada no destino sera excluido.'
    $source = Read-Host '  Origem (ENTER para cancelar)'
    if ([string]::IsNullOrWhiteSpace($source)) { return }
    $destination = Read-Host '  Destino'
    if (-not (Test-Path -LiteralPath $source) -or [string]::IsNullOrWhiteSpace($destination)) { Write-Host '  Origem ou destino invalido.' -ForegroundColor Red; Wait-Return; return }
    if (-not (Test-Path -LiteralPath $destination)) { New-Item -ItemType Directory -Force -Path $destination | Out-Null }
    if (Confirm "Copiar '$source' para '$destination'?") {
        Invoke-Tool { robocopy.exe $source $destination /E /COPY:DAT /DCOPY:DAT /R:2 /W:2 /FFT; if ($LASTEXITCODE -gt 7) { throw "Robocopy terminou com codigo $LASTEXITCODE" }; Write-Host '  Backup concluido.' } "Backup de $source para $destination"
    }
}

function Show-PrintersMenu {
    while ($true) {
        Show-Header 'IMPRESSORAS'
        Write-Host '   [1]  Listar impressoras e status'
        Write-Host '   [2]  Abrir fila de uma impressora'
        Write-Host '   [3]  Enviar pagina de teste'
        Write-Host '   [4]  Reiniciar servico de impressao'
        Write-Host '   [5]  Abrir configuracoes de impressoras'
        Write-Host '   [0]  Voltar ao menu principal'
        Show-Line; $op = Read-Option
        switch ($op) {
            '0' { return }
            '1' { Invoke-Tool { Get-CimInstance Win32_Printer | Select-Object Name,Default,PrinterStatus,WorkOffline | Format-Table -AutoSize } 'Consulta de impressoras' }
            '2' { $n=Read-Host '  Nome da impressora'; if($n){ Invoke-Tool { Start-Process rundll32.exe -ArgumentList @('printui.dll,PrintUIEntry','/o',('/n "{0}"' -f $n)) } "Abertura da fila de impressao: $n" } }
            '3' { $n=Read-Host '  Nome exato da impressora'; if($n){ Invoke-Tool { $p=Get-CimInstance Win32_Printer -Filter "Name='$($n.Replace("'","''"))'"; if(-not $p){throw 'Impressora nao encontrada'}; Invoke-CimMethod -InputObject $p -MethodName PrintTestPage | Out-Null; Write-Host '  Pagina de teste enviada.' } "Pagina de teste: $n" } }
            '4' { if(Confirm 'Reiniciar o servico de impressao? Trabalhos em andamento podem ser afetados'){ Invoke-Tool { Restart-Service Spooler; Write-Host '  Servico reiniciado.' } 'Reinicio do Spooler' } }
            '5' { Invoke-Tool { Start-Process 'ms-settings:printers' } 'Abertura das configuracoes de impressora' }
            default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
        }
    }
}

function Show-HardwareMenu {
    while ($true) {
        Show-Header 'DIAGNOSTICO DE HARDWARE'
        Write-Host '   [1]  Informacoes de CPU, RAM e armazenamento'
        Write-Host '   [2]  Diagnostico de temperatura'
        Write-Host '   [3]  Verificar estado SMART dos discos'
        Write-Host '   [4]  Abrir Diagnostico de Memoria do Windows'
        Write-Host '   [5]  Abrir DxDiag'
        Write-Host '   [6]  Abrir Gerenciador de Dispositivos'
        Write-Host '   [0]  Voltar ao menu principal'
        Show-Line; $op = Read-Option
        switch ($op) {
            '0' { return }
            '1' { Show-SystemInfo }
            '2' { Show-Temperature }
            '3' { Invoke-Tool { Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,Size | Format-Table -AutoSize } 'Consulta de estado SMART dos discos' }
            '4' { Invoke-Tool { Start-Process mdsched.exe } 'Abertura do Diagnostico de Memoria' }
            '5' { Invoke-Tool { Start-Process dxdiag.exe } 'Abertura do DxDiag' }
            '6' { Invoke-Tool { Start-Process devmgmt.msc } 'Abertura do Gerenciador de Dispositivos' }
            default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
        }
    }
}

function Show-PowerMenu {
    Show-Header 'ENERGIA'
    Write-Host '   [1]  Reiniciar computador agora'
    Write-Host '   [2]  Desligar computador agora'
    Write-Host '   [0]  Cancelar'
    Show-Line; $op = Read-Option
    if ($op -eq '1' -and (Confirm 'Reiniciar agora? Salve todo o seu trabalho antes')) { Write-Log 'Reinicializacao solicitada'; Restart-Computer -Force }
    if ($op -eq '2' -and (Confirm 'Desligar agora? Salve todo o seu trabalho antes')) { Write-Log 'Desligamento solicitado'; Stop-Computer -Force }
}

Start-AsAdministrator
Write-Log "Aplicacao iniciada por $env:USERNAME"
while ($true) {
    Show-Header
    Write-Host '   [1]  LIMPEZA                 Arquivos temporarios e disco'
    Write-Host '   [2]  REPAROS                  SFC, DISM, CHKDSK e restauracao'
    Write-Host '   [3]  REDE                     Conectividade e velocidade'
    Write-Host '   [4]  COMPUTADOR               Resumo de sistema'
    Write-Host '   [5]  HARDWARE                 Sensores, memoria e discos'
    Write-Host '   [6]  IMPRESSORAS              Filas e diagnostico'
    Write-Host '   [7]  BACKUP                   Copiar arquivos com seguranca'
    Write-Host '   [8]  ENERGIA                  Reiniciar ou desligar'
    Write-Host '   [9]  ABRIR LOGS               Historico de operacoes'
    Write-Host '   [0]  SAIR'
    Show-Line; $op = Read-Option 'Ir para'
    switch ($op) {
        '0' { if (Confirm 'Deseja realmente sair?') { Write-Log 'Aplicacao encerrada'; break } }
        '1' { Show-CleanMenu }; '2' { Show-RepairMenu }; '3' { Show-NetworkMenu }
        '4' { Show-SystemInfo }; '5' { Show-HardwareMenu }; '6' { Show-PrintersMenu }
        '7' { Show-BackupMenu }; '8' { Show-PowerMenu }
        '9' { Invoke-Tool { Start-Process notepad.exe $LogFile } 'Abertura do arquivo de log' }
        default { Write-Host '  Opcao invalida.' -ForegroundColor Yellow; Start-Sleep 1 }
    }
}
