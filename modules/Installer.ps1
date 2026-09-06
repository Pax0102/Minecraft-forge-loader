function Install-Forge {

    param(
        [string]$MinecraftVersion
    )

    $DownloadsDir = Join-Path $PSScriptRoot "..\downloads"
    $Installer = Join-Path $DownloadsDir "forge-installer.jar"

    if(!(Test-Path $DownloadsDir)){
        New-Item -ItemType Directory -Path $DownloadsDir | Out-Null
    }

    $ForgeVersion = Get-LatestForgeVersion $MinecraftVersion

    if(!$ForgeVersion){
        Write-ErrorText "Nao foi possivel obter a versao do Forge para Minecraft $MinecraftVersion."
        return $false
    }

    $FullVersion = "$MinecraftVersion-$ForgeVersion"

    $JarURL = "https://maven.minecraftforge.net/net/minecraftforge/forge/$FullVersion/forge-$FullVersion-installer.jar"

    if(!(Invoke-VerifiedDownload -Url $JarURL -Output $Installer)){
        Write-ErrorText "Falha ao baixar o Forge Installer."
        return $false
    }

    $ServerDir = Join-Path $PSScriptRoot "..\server"

    if(!(Test-Path $ServerDir)){
        New-Item -ItemType Directory -Path $ServerDir | Out-Null
    }

    Write-Info "Instalando Forge $FullVersion..."

    & java -jar $Installer --installServer $ServerDir

    if($LASTEXITCODE -ne 0){
        Write-ErrorText "Forge Installer retornou codigo de erro $LASTEXITCODE."
        Write-Log "Forge Installer falhou (exit $LASTEXITCODE) para MC $MinecraftVersion."
        return $false
    }

    $Forge = Get-ForgeInfo

    if(!$Forge.Installed){
        Write-ErrorText "Falha ao instalar Forge (arquivos de execucao ausentes)."
        Write-Log "Instalacao do Forge falhou: nem run.bat/win_args.txt nem jar executavel foram encontrados."
        return $false
    }

    if($Forge.LaunchMode -eq "legacy" -and !(Test-JarIntegrity $Forge.ServerJar)){
        Write-ErrorText "Falha ao instalar Forge (jar do servidor ausente ou invalido)."
        Write-Log "Instalacao do Forge falhou: jar invalido."
        return $false
    }

    Set-VersionState `
        -Minecraft $MinecraftVersion `
        -ForgeVersion $ForgeVersion `
        | Out-Null

    Write-Success "Forge instalado (versao $ForgeVersion)."
    Write-Log "Forge instalado: MC=$MinecraftVersion Forge=$ForgeVersion Modo=$($Forge.LaunchMode)"

    Ensure-Eula | Out-Null

    return $true

}
