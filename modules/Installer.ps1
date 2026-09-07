function Install-Forge {

    param(
        [string]$MinecraftVersion,
        $JavaOverride = $null
    )

    $DownloadsDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\downloads"))
    $Installer    = Join-Path $DownloadsDir "forge-installer.jar"
    $ServerDir    = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\server"))

    foreach($Dir in @($DownloadsDir, $ServerDir)){
        if(!(Test-Path $Dir)){
            New-Item -ItemType Directory -Path $Dir | Out-Null
        }
    }

    $ForgeVersion = Get-LatestForgeVersion $MinecraftVersion

    if(!$ForgeVersion){
        Write-ErrorText "Nao foi possivel obter a versao do Forge para Minecraft $MinecraftVersion."
        return $false
    }

    $FullVersion = "$MinecraftVersion-$ForgeVersion"

    # Verifica se o Forge ja esta instalado nessa versao exata antes de baixar
    $ForgeAtual = Get-ForgeInfo
    if($ForgeAtual.Installed -and $ForgeAtual.Version -eq $ForgeVersion -and $ForgeAtual.MinecraftVersion -eq $MinecraftVersion){
        Write-Info "Forge $FullVersion ja esta instalado. Pulando download."
        Write-Log "Forge $FullVersion ja instalado, sem necessidade de reinstalar."
        return $true
    }

    # Remove installer anterior se existir (evita usar jar corrompido de execucao anterior)
    if(Test-Path $Installer){
        Remove-Item $Installer -Force -ErrorAction SilentlyContinue
    }

    $JarURL = "https://maven.minecraftforge.net/net/minecraftforge/forge/$FullVersion/forge-$FullVersion-installer.jar"

    if(!(Invoke-VerifiedDownload -Url $JarURL -Output $Installer)){
        Write-ErrorText "Falha ao baixar o Forge Installer."
        return $false
    }

    # Reutiliza o Java ja resolvido pelo caller (evita segundo download/busca)
    # SE ele ainda for compativel com a versao alvo desta instalacao/update.
    # Sem essa checagem, uma atualizacao que pula de major (ex.: 1.20.x com
    # Java 17 -> 26.x com Java 25) reaproveitaria o Java antigo e o Forge
    # Installer rodaria com um runtime incompativel.
    $RequiredMajor = Get-RequiredJavaMajor $MinecraftVersion

    $Java = if($JavaOverride -and $JavaOverride.Installed -and $JavaOverride.Major -ge $RequiredMajor){
        $JavaOverride
    }
    else{

        if($JavaOverride -and $JavaOverride.Installed){
            Write-Log "Java resolvido anteriormente (major=$($JavaOverride.Major)) nao atende ao requisito de $MinecraftVersion (major=$RequiredMajor). Resolvendo novamente."
        }

        Get-WorkingJava $MinecraftVersion

    }

    if(!$Java.Installed){
        Write-ErrorText "Nao foi possivel obter um Java compativel para instalar o Forge (mesmo apos tentar baixar automaticamente)."
        Write-Log "Instalacao do Forge abortada: nenhum Java compativel disponivel."
        return $false
    }

    Write-Info "Instalando Forge $FullVersion (usando Java $($Java.Major) em '$($Java.Path)')..."

    & $Java.Path -jar $Installer --installServer $ServerDir

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

    # Remove o installer apos uso bem-sucedido
    Remove-Item $Installer -Force -ErrorAction SilentlyContinue

    Set-VersionState `
        -Minecraft $MinecraftVersion `
        -ForgeVersion $ForgeVersion `
        -Java "$($Java.Major)" `
        | Out-Null

    Write-Success "Forge instalado (versao $ForgeVersion)."
    Write-Log "Forge instalado: MC=$MinecraftVersion Forge=$ForgeVersion Modo=$($Forge.LaunchMode) Java=$($Java.Major)"

    Ensure-Eula | Out-Null

    return $true

}
