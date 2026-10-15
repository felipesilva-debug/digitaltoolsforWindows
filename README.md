# 🛠️ Ferramentas Digitais - Painel de Manutenção Windows

Painel de manutenção para Windows, desenvolvido em PowerShell e Batch, organizado em menus interativos. O projeto reúne verificações de sistema, limpeza, reparo, rede, backup, impressoras e diagnósticos de hardware em uma única interface de terminal.

> ⚠️ **Atenção:** Algumas funções alteram o sistema, a rede ou os arquivos do computador. Leia as confirmações exibidas pelo programa e salve seu trabalho antes de usar limpeza, reparos, rede, energia ou formatação.

## 📂 Arquivos do Projeto

O projeto possui duas versões principais que você pode escolher usar dependendo da sua necessidade:

| Arquivo | Finalidade | 
| ----- | ----- | 
| `Iniciar-FerramentasDigitais.cmd` | Iniciador da versão principal. Abre o painel PowerShell com elevação automática de administrador. | 
| `FerramentasDigitais.ps1` | Código-fonte principal da aplicação em PowerShell (Mais completo e avançado). | 
| `ferramentasdigitais.bat` | Versão alternativa escrita em Batch puro. Mais simples e leve, focada em comandos diretos do CMD. | 

## 🚀 Como Executar

Não é necessário instalar módulos adicionais. Certifique-se de estar usando Windows 10 ou 11.

### Opção 1: Versão Principal (PowerShell - Recomendado)
1. Mantenha os arquivos `.cmd` e `.ps1` na mesma pasta.
2. Clique duas vezes em `Iniciar-FerramentasDigitais.cmd`.
3. Quando o Windows solicitar, permita a execução como administrador (UAC).
4. O programa verifica automaticamente se está em modo administrador e reabre o painel com as permissões necessárias caso precise.

### Opção 2: Versão Alternativa (Batch Puro)
1. Clique com o botão direito sobre o arquivo `ferramentasdigitais.bat`.
2. Selecione **Executar como administrador** (necessário para comandos como SFC, DISM e formatação).
3. O menu será aberto diretamente no Prompt de Comando clássico (CMD).

---

## ⚙️ Funcionalidades da Versão Principal (PowerShell)

### Menu principal

| Opção | Área | Principais recursos |
|---:|---|---|
| 1 | Limpeza | Temporários, Lixeira, Limpeza de Disco, DISM e Gerenciamento de Disco. |
| 2 | Reparos | SFC, CHKDSK, DISM e ponto de restauração. |
| 3 | Rede | IPConfig, testes, DNS, renovação de IP, velocidade e reset TCP/IP. |
| 4 | Programas | Atualizações pelo Winget, inicialização e Programas e Recursos. |
| 5 | Computador | Resumo do Windows, CPU, RAM, GPU, discos e adaptadores ativos. |
| 6 | Hardware | Temperatura, discos, bateria, memória, DxDiag e dispositivos. |
| 7 | Impressoras | Status, fila, página de teste e Spooler. |
| 8 | Backup | Cópia incremental segura com Robocopy. |
| 9 | Energia | Reinício, desligamento, UEFI/BIOS e Desempenho Máximo. |
| L | Abrir logs | Abre o histórico de operações do dia. |
| 0 | Sair | Fecha o painel após confirmação. |

### 🧹 1. Limpeza e Armazenamento
* Remoção de arquivos temporários (`%TEMP%`, `C:\Windows\Temp` e cache de download do Windows Update). Itens em uso são ignorados e registrados.
* Esvaziamento da Lixeira após confirmação.
* Limpeza de Disco nativa (`cleanmgr`).
* Limpeza de componentes substituídos do Windows (`DISM`).
* Acesso rápido ao Gerenciamento de Disco.

> A versão PowerShell não apaga a pasta Prefetch. Ela é gerenciada pelo Windows e a limpeza recorrente pode prejudicar a abertura de programas.

### 🔧 2. Reparos e Recuperação
* Verificação e reparo de arquivos do sistema (`SFC /scannow`).
* Verificação de erros no disco (`CHKDSK`).
* Restauração da integridade da imagem do Windows (`DISM CheckHealth / ScanHealth / RestoreHealth`).
* Criação rápida de Pontos de Restauração.

O reparo completo de disco (`CHKDSK /F /R`) é agendado para a próxima reinicialização e requer confirmação.

### 🌐 3. Rede e Conectividade
* Exibição de IP, DNS, gateway e adaptadores.
* Testes de conectividade (Ping) e latência de DNS (Cloudflare).
* Teste integrado de velocidade de download (\~10 MB).
* Ferramentas de renovação/liberação de IP e limpeza de cache DNS (`ipconfig`).
* Redefinição de Winsock e TCP/IP; reinicie o computador após usar essa opção.

O teste de velocidade transfere aproximadamente 10 MB da Cloudflare. O resultado é estimativo e pode variar com a rota, o servidor e outras atividades da rede.

### 📦 4. Programas e Atualizações
* Lista atualizações disponíveis pelo `winget`.
* Atualiza todos os programas detectados pelo Winget após confirmação.
* Lista programas configurados para iniciar com o Windows.
* Abre **Programas e Recursos**.

Se o Winget não estiver disponível, o painel apresenta o aviso e continua funcionando nas demais áreas.

### 💻 5. Computador e Hardware
* Informações detalhadas do computador (CPU, RAM, uso de armazenamento).
* Diagnóstico de temperatura (via sensores ACPI).
* Leitura do estado de saúde SMART dos discos físicos.
* Acesso rápido ao DxDiag, Gerenciador de Dispositivos e Diagnóstico de Memória.

### 🖨️ 5. Impressoras e 💾 6. Backup Seguro
* Gestão e teste de fila de impressão e reinício do *Spooler*.
* Limpeza profunda da fila do Spooler, que cancela todos os documentos pendentes após confirmação.
* Ferramenta guiada utilizando `robocopy` para cópia incremental segura.

O backup transfere arquivos novos e alterados sem remover itens que já existam no destino. A versão PowerShell bloqueia destino igual à origem ou situado dentro dela, evitando cópias recursivas acidentais. Códigos 0 a 7 do Robocopy são tratados como resultados normais; códigos maiores são reportados como falha.

### ⚡ 9. Energia e desempenho
* Reinicia ou desliga o computador somente após confirmação.
* Reinicia diretamente na UEFI/BIOS em equipamentos compatíveis.
* Adiciona o plano **Desempenho Máximo** às opções de energia.

---

## 💻 Sobre a Versão `.bat` (ferramentasdigitais.bat)

O arquivo `ferramentasdigitais.bat` oferece uma interface simplificada e direta, ideal para técnicos que precisam de execução ultrarrápida sem depender das políticas de execução do PowerShell. 

**Seus menus incluem:**
* **Limpeza:** Acesso rápido ao `cleanmgr`, limpeza do DISM e gerenciador `diskpart`.
* **Módulo de Formatação:** Conta com um sistema de formatação de unidades via terminal com travas de segurança rigorosas (impede a formatação da unidade `C:`). Permite formatação rápida e completa.
* **Reparos:** Atalhos diretos para os clássicos `sfc /scannow`, `chkdsk` e a suíte de recuperação de imagem do `DISM`.
* **Rede:** Opções rápidas de `ipconfig` (flushdns, renew, release) e testes de Ping.

---

## 📝 Sistema de Logs (Versão PS1)

Todas as operações iniciadas pelo painel em PowerShell são registradas automaticamente em arquivos diários localizados em:
`C:\ProgramData\FerramentasDigitais\Logs`

Os logs classificam as ações em `INFO` (iniciado/concluído), `AVISO` (requer atenção) e `ERRO` (falha). Você pode visualizar o log do dia diretamente pela opção **L** do menu principal.

## 🛡️ Segurança e Boas Práticas

* Execute o projeto somente em computadores que você administra ou tem autorização para manter.
* Ambos os scripts contêm travas de segurança para evitar danos críticos (como bloquear formatação do disco C: no Batch).
* Não interrompa processos críticos como SFC, DISM ou CHKDSK enquanto estiverem em execução.
* Para usar o `DISM RestoreHealth` ou testes de rede, certifique-se de ter uma conexão ativa com a internet.
* Um ponto de restauração não substitui cópias de segurança dos seus arquivos importantes.
* Em notebooks, conecte o carregador antes de executar reparos demorados.

*Desenvolvido para automatizar e simplificar o dia a dia de manutenção no Windows.*

<img width="706" height="560" alt="Captura de tela 2026-10-14 232351" src="https://github.com/user-attachments/assets/cca62aeb-725a-4e41-a9a3-4b6851c449d6" />
<img width="871" height="741" alt="Captura de tela 2026-10-14 232327" src="https://github.com/user-attachments/assets/f815869d-c840-46bc-9614-70c2bb0dbd79" />
