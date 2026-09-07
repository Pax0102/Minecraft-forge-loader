function Invoke-UpdateCheck {

    $State = Get-VersionState

    # Determina versao instalada a partir do Forge (fonte primaria)
    $Forge = Get-ForgeInfo
    $InstalledMinecraft = if($Forge.MinecraftVersion){ $Forge.MinecraftVersion } else { $State.minecraft }
    $InstalledForge     = if($Forge.Version){ $Forge.Version } else { $State.forgeVersion }

    Write-Info "Consultando versoes mais recentes (em paralelo)..."

    $Urls = @{
        minecraft = "https://launchermeta.mojang.com/mc/game/version_manifest.json"
        forge     = "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json"
    }

    $Results = Get-JsonParallel -Urls $Urls

    $LatestMinecraft = if($Results.minecraft){ $Results.minecraft.latest.release } else { $null }

    $LatestForge = $null

    if($Results.forge -and ![string]::IsNullOrWhiteSpace($InstalledMinecraft)){

        $RecommendedKey = "$InstalledMinecraft-recommended"
        $LatestKey      = "$InstalledMinecraft-latest"

        $LatestForge = $Results.forge.promos.$RecommendedKey

        if(!$LatestForge){
            $LatestForge = $Results.forge.promos.$LatestKey
        }

    }

    $NeedsMinecraftUpdate = $false
    if($Config.checkMinecraft -and $LatestMinecraft -and ![string]::IsNullOrWhiteSpace($InstalledMinecraft)){
        $NeedsMinecraftUpdate = ((Compare-Version $InstalledMinecraft $LatestMinecraft) -lt 0)
    }
    Show-VersionStatus "Minecraft" $InstalledMinecraft $LatestMinecraft
    Log-Version "Minecraft" $InstalledMinecraft $LatestMinecraft

    $NeedsForgeUpdate = $false
    if($Config.checkForgeVersion -and $LatestForge -and ![string]::IsNullOrWhiteSpace($InstalledForge)){
        $NeedsForgeUpdate = ((Compare-Version $InstalledForge $LatestForge) -lt 0)
    }
    Show-VersionStatus "Forge" $InstalledForge $LatestForge
    Log-Version "Forge" $InstalledForge $LatestForge

    return @{
        MinecraftVersion      = $InstalledMinecraft
        LatestMinecraft       = $LatestMinecraft
        NeedsMinecraftUpdate  = $NeedsMinecraftUpdate
        NeedsForgeUpdate      = $NeedsForgeUpdate
    }

}

function Invoke-Updates {

    param(
        $Status,
        $JavaResolvido = $null
    )

    $AnyUpdate = $Status.NeedsMinecraftUpdate -or $Status.NeedsForgeUpdate

    if(!$AnyUpdate){
        Write-Success "Tudo atualizado."
        return $true
    }

    $Items = @()
    if($Status.NeedsMinecraftUpdate){ $Items += "Minecraft" }
    if($Status.NeedsForgeUpdate)    { $Items += "Forge" }

    Write-WarningText "Atualizacoes disponiveis: $($Items -join ', ')"

    if(!(Read-YesNo "Deseja aplicar as atualizacoes agora?")){
        Write-Info "Atualizacao adiada."
        Write-Log "Atualizacoes disponiveis, mas adiadas pelo usuario."
        return $true
    }

    $BackupPath = $null

    if($Config.backupBeforeUpdate){
        $BackupPath = New-Backup "pre_update"
    }

    $Success = $true

    try{

        $TargetVersion = if($Status.NeedsMinecraftUpdate){ $Status.LatestMinecraft } else { $Status.MinecraftVersion }

        # Reutiliza o Java ja resolvido (evita novo download/busca)
        if(!(Install-Forge $TargetVersion -JavaOverride $JavaResolvido)){
            throw "Falha ao atualizar Forge/Minecraft."
        }

    }
    catch{

        Write-ErrorText "$_"
        Write-Log "Erro durante atualizacao: $_"
        $Success = $false

        if($Config.backupBeforeUpdate){
            Invoke-AutoRestore $BackupPath | Out-Null
        }

    }

    if($Success){
        Send-DiscordNotification -Title "Atualizacao concluida" -Message ($Items -join ', ')
    }

    return $Success

}
