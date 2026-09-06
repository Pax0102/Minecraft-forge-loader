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

function Invoke-ServerFlow {

    Write-Log "Inicializando"

    Write-Host ""
    Write-Info "Verificando Java..."

    $Java = Get-JavaInfo

    Show-Java $Java
    Log-Java $Java

    Write-Info "Verificando Forge..."

    $Forge = Get-ForgeInfo

    Show-Forge $Forge
    Log-Forge $Forge

    if(!$Forge.Installed){

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

        if($Config.checkJava){
            Test-JavaCompatibility $Java $MinecraftVersion | Out-Null
        }

        if(!(Install-Forge $MinecraftVersion)){
            Write-ErrorText "Nao foi possivel instalar o Forge."
            return
        }

        $Forge = Get-ForgeInfo

    }

    $MinecraftVersion = Get-MinecraftVersion

    if([string]::IsNullOrWhiteSpace($MinecraftVersion)){
        $MinecraftVersion = (Get-VersionState).minecraft
    }

    if($Config.checkJava){
        Test-JavaCompatibility $Java $MinecraftVersion | Out-Null
    }

    Write-Host ""

    $Status = Invoke-UpdateCheck

    Invoke-Updates $Status | Out-Null

    $Forge = Get-ForgeInfo
    $MinecraftVersion = Get-MinecraftVersion

    if([string]::IsNullOrWhiteSpace($MinecraftVersion)){
        $MinecraftVersion = (Get-VersionState).minecraft
    }

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

    if(!(Test-Internet)){
        Write-WarningText "Sem conexao com a internet. Algumas funcoes podem falhar."
    }

    $Choice = Show-MainMenu

    switch($Choice){

        "1" { Invoke-ServerFlow }
        "2" { Show-RestoreMenu }
        "3" { Clear-TempFiles }
        "4" { Show-ModManager }
        "5" { Show-PropertiesMenu }
        "6" { Invoke-Diagnostics }
        "7" { Show-ServerLog }
        "8" { Show-RconMenu }
        "9" { $Running = $false }
        default { Write-WarningText "Opcao invalida." }

    }

    if($Running){
        Write-Host ""
        Pause
    }

}
