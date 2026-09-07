[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

$Root = Split-Path $MyInvocation.MyCommand.Path

$Modules = Join-Path $Root "modules"

Get-ChildItem $Modules -Filter *.ps1 |
ForEach-Object {

    . $_.FullName

}

Set-DownloadProgressPreference

# config.json "language": por enquanto so pt-BR e suportado - todas as
# mensagens do script sao fixas em portugues. Avisa uma vez no inicio em
# vez de deixar a chave parecer configuravel sem fazer nada.
if($Config -and $Config.language -and $Config.language -ne "pt-BR"){
    Write-WarningText "'language' = '$($Config.language)' ainda nao e suportado; todas as mensagens continuam em pt-BR."
}

function Read-RamChoice {

    param([int]$CurrentRam)

    Write-Host ""

    $Input = Read-Host "Quanta RAM deseja alocar para o servidor, em GB? (ENTER = ${CurrentRam}GB)"

    if([string]::IsNullOrWhiteSpace($Input)){
        return $CurrentRam
    }

    $Value = 0

    if(![int]::TryParse($Input.Trim(), [ref]$Value) -or $Value -le 0){
        Write-WarningText "Valor invalido. Mantendo ${CurrentRam}GB."
        return $CurrentRam
    }

    if(!(Set-ConfigValue -Key "ram" -Value $Value)){
        Write-WarningText "Nao foi possivel salvar a RAM no config.json. Usando ${Value}GB so nesta execucao."
        return $Value
    }

    Write-Success "RAM configurada para ${Value}GB (salvo no config.json)."

    return $Value

}

function Invoke-ServerFlow {

    Write-Log "Inicializando"

    Write-Host ""
    Write-Info "Verificando Forge..."

    $Forge = Get-ForgeInfo

    Show-Forge $Forge
    Log-Forge $Forge

    $PrimeiraInstalacao = $false

    if(!$Forge.Installed){

        $PrimeiraInstalacao = $true

        if(!$Config.autoInstallForge){
            Write-WarningText "Forge nao instalado e a instalacao automatica esta desativada no config.json."
            return
        }

        Write-Host ""

        if(!(Read-YesNo "Forge nao encontrado. Deseja instalar?")){
            Write-Info "Voltando ao menu."
            return
        }

        $MinecraftVersion = Read-Host "Digite a versao do Minecraft (ENTER = ultima versao, 0 = voltar)"

        if($MinecraftVersion -eq "0"){
            Write-Info "Voltando ao menu."
            return
        }

        if([string]::IsNullOrWhiteSpace($MinecraftVersion)){

            $MinecraftVersion = Get-LatestMinecraftVersion

            if(!$MinecraftVersion){
                Write-ErrorText "Nao foi possivel obter a ultima versao do Minecraft."
                return
            }

        }

        Write-Info "Versao selecionada: $MinecraftVersion"

        # Mostra qual Java e necessario para a versao escolhida
        Show-JavaRequirement $MinecraftVersion

        Read-RamChoice -CurrentRam $Config.ram | Out-Null

        Write-Info "Verificando Java..."

        # Resolve o Java UMA vez e passa adiante — evita multiplos downloads
        $Java = Get-WorkingJava $MinecraftVersion

        Show-Java $Java
        Log-Java $Java

        if($Config.checkJava){
            if(!(Test-JavaCompatibility $Java $MinecraftVersion)){
                Write-ErrorText "Instalacao abortada: Java incompativel."
                return
            }
        }

        # Passa o Java ja resolvido para Install-Forge (sem resolver de novo)
        if(!(Install-Forge $MinecraftVersion -JavaOverride $Java)){
            Write-ErrorText "Nao foi possivel instalar o Forge."
            return
        }

        # Atualiza Forge apos instalacao
        $Forge = Get-ForgeInfo

    }

    # Determina versao do Minecraft a partir do Forge instalado (ja lido acima)
    $MinecraftVersion = if($Forge.MinecraftVersion){ $Forge.MinecraftVersion } else { (Get-VersionState).minecraft }

    # So resolve o Java de novo se ainda nao foi resolvido nesta execucao
    # (na primeira instalacao ja resolvemos e mostramos acima) - evita um
    # "java -version" extra desnecessario.
    if(!$PrimeiraInstalacao){
        $Java = Get-WorkingJava $MinecraftVersion
        Show-Java $Java
        Log-Java $Java
    }

    if($Config.checkJava){

        if(!(Test-JavaCompatibility $Java $MinecraftVersion)){
            Write-ErrorText "Java incompativel. Corrija o Java antes de iniciar o servidor (veja o aviso acima)."
            return
        }

    }

    Write-Host ""

    $Status = Invoke-UpdateCheck

    Invoke-Updates $Status -JavaResolvido $Java | Out-Null

    # Re-le Forge e versao apos possiveis atualizacoes
    $Forge = Get-ForgeInfo
    $MinecraftVersion = if($Forge.MinecraftVersion){ $Forge.MinecraftVersion } else { (Get-VersionState).minecraft }

    if($Config.deleteTemporaryFiles){
        Clear-TempFiles
    }

    if($Config.backupBeforeUpdate){
        Remove-OldBackups -Days $Config.backupRetentionDays
    }

    Show-Summary -Java $Java -Forge $Forge -MinecraftVersion $MinecraftVersion

    if(!$Forge.Installed){
        return
    }

    Write-Host ""

    if(Read-YesNo "Deseja iniciar o servidor agora?"){
        Start-MinecraftServer
    }

}

$Running = $true

while($Running){

    Clear-Host

    Write-Host ""
    Write-Host "=========================================" -ForegroundColor DarkCyan
    Write-Host "      Minecraft Server Manager"
    Write-Host "=========================================" -ForegroundColor DarkCyan

    Invoke-SafeAction {

        if(!(Test-Internet)){
            Write-WarningText "Sem conexao com a internet. Algumas funcoes podem falhar."
        }

    }

    $Choice = Show-MainMenu

    switch($Choice){

        "1" { Invoke-SafeAction { Invoke-ServerFlow } }
        "2" { Invoke-SafeAction { Show-RestoreMenu } }
        "3" { Invoke-SafeAction { Clear-TempFiles } }
        "4" { Invoke-SafeAction { Show-ModManager } }
        "5" { Invoke-SafeAction { Show-PropertiesMenu } }
        "6" { Invoke-SafeAction { Invoke-Diagnostics } }
        "7" { Invoke-SafeAction { Show-ServerLog } }
        "8" { Invoke-SafeAction { Show-RconMenu } }
        "9" { $Running = $false }
        "10" { Invoke-SafeAction { Read-RamChoice -CurrentRam $Config.ram | Out-Null } }
        default { Write-WarningText "Opcao invalida." }

    }

    if($Running){
        Write-Host ""
        Pause
    }

}
