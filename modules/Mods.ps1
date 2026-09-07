function Get-ModsManifestPath {

    return (Join-Path $PSScriptRoot "..\server\mods\.mods-manifest.json")

}

function Get-ModsManifest {

    # Mapeia slug -> nome do arquivo jar instalado. O nome real do arquivo
    # ($File.filename retornado pela API do Modrinth) nao e garantido
    # comecar com o slug (ex.: slug "jei" pode virar
    # "jei-1.20.1-forge-15.2.0.27.jar" ou algo totalmente diferente,
    # dependendo de como o autor nomeia o release). Sem esse manifesto,
    # Install-ModrinthMod nao tem como saber com certeza qual arquivo
    # antigo remover ao atualizar/trocar de versao, e jars antigos ficam
    # "pendurados" na pasta mods.
    $Path = Get-ModsManifestPath

    if(!(Test-Path $Path)){
        return @{}
    }

    try{

        $Raw = Get-Content $Path -Raw | ConvertFrom-Json

        $Map = @{}
        $Raw.PSObject.Properties | ForEach-Object { $Map[$_.Name] = $_.Value }

        return $Map

    }
    catch{
        return @{}
    }

}

function Set-ModsManifestEntry {

    param(
        [string]$Slug,
        [string]$FileName
    )

    $Manifest = Get-ModsManifest
    $Manifest[$Slug] = $FileName

    $Path = Get-ModsManifestPath
    $Dir = Split-Path $Path -Parent

    if(!(Test-Path $Dir)){
        New-Item -ItemType Directory -Path $Dir | Out-Null
    }

    ($Manifest | ConvertTo-Json) | Set-Utf8NoBom -Path $Path

}

function Get-ModrinthVersions {

    param(
        [string]$Slug,
        [string]$MinecraftVersion,
        [string[]]$Loaders = @("forge")
    )

    try{

        $LoadersJson = ($Loaders | ForEach-Object { "`"$_`"" }) -join ","
        $Url = "https://api.modrinth.com/v2/project/$Slug/version?game_versions=[`"$MinecraftVersion`"]&loaders=[$LoadersJson]"

        return Invoke-RestMethod -Uri $Url -UseBasicParsing

    }
    catch{
        Write-Log "Falha ao consultar mod '$Slug' no Modrinth (loaders=$($Loaders -join ',')): $_"
        return $null
    }

}

function Install-ModrinthMod {

    param(
        [string]$Slug,
        [string]$MinecraftVersion,
        [switch]$Silent
    )

    $Versions = Get-ModrinthVersions -Slug $Slug -MinecraftVersion $MinecraftVersion -Loaders @("forge")

    if(!$Versions -or $Versions.Count -eq 0){

        # Boa parte do ecossistema de mods migrou de Forge para NeoForge em
        # versoes recentes. Uma busca "forge" vazia pode significar que o
        # mod so existe pra NeoForge nesta versao do MC - avisa o usuario
        # em vez de simplesmente dizer "nao encontrado" (o que sugeriria,
        # erroneamente, que o mod nao existe de jeito nenhum).
        $NeoForgeVersions = Get-ModrinthVersions -Slug $Slug -MinecraftVersion $MinecraftVersion -Loaders @("neoforge")

        if($NeoForgeVersions -and $NeoForgeVersions.Count -gt 0){
            if(!$Silent){
                Write-WarningText "'$Slug' nao tem build para Forge em $MinecraftVersion - so existe para NeoForge, que este ServerManager nao instala (o servidor e Forge)."
            }
        }
        elseif(!$Silent){
            Write-WarningText "Nenhuma versao de '$Slug' encontrada para $MinecraftVersion (nem Forge, nem NeoForge)."
        }

        return $null

    }

    $Latest = $Versions[0]
    $File = $Latest.files | Where-Object { $_.primary } | Select-Object -First 1
    if(!$File){ $File = $Latest.files | Select-Object -First 1 }
    if(!$File){ return $null }

    $ModsDir = Join-Path $PSScriptRoot "..\server\mods"

    if(!(Test-Path $ModsDir)){
        New-Item -ItemType Directory -Path $ModsDir | Out-Null
    }

    # Remove a versao antiga deste mod antes de baixar a nova. Usa o
    # manifesto (nome exato gravado na instalacao anterior) quando
    # disponivel; cai no filtro por prefixo do slug so como fallback pra
    # instalacoes feitas antes desta correcao existir.
    $Manifest = Get-ModsManifest

    if($Manifest.ContainsKey($Slug)){

        $OldFile = Join-Path $ModsDir $Manifest[$Slug]

        if(Test-Path $OldFile){
            Remove-Item $OldFile -Force -ErrorAction SilentlyContinue
        }

    }
    else{

        Get-ChildItem $ModsDir -Filter "$Slug-*.jar" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue

    }

    $Output = Join-Path $ModsDir $File.filename
    $ExpectedHash = if($File.hashes -and $File.hashes.sha512){ $File.hashes.sha512 } else { "" }

    if(!(Invoke-VerifiedDownload -Url $File.url -Output $Output -ExpectedHash $ExpectedHash -HashAlgorithm "SHA512")){
        if(!$Silent){ Write-ErrorText "Falha ao instalar '$Slug'." }
        return $null
    }

    Set-ModsManifestEntry -Slug $Slug -FileName $File.filename

    if(!$Silent){
        Write-Success "$Slug $($Latest.version_number) instalado."
    }

    Write-Log "Mod instalado: $Slug $($Latest.version_number) ($($File.filename))"

    return $Latest.version_number

}

function Search-ModrinthMods {

    param(
        [string]$Query,
        [string]$MinecraftVersion
    )

    try{
        $Facets = "[[`"project_type:mod`"],[`"categories:forge`"],[`"versions:$MinecraftVersion`"]]"
        $Url = "https://api.modrinth.com/v2/search?query=$([uri]::EscapeDataString($Query))&facets=$Facets&limit=8"
        $Result = Invoke-RestMethod -Uri $Url -UseBasicParsing
        return $Result.hits
    }
    catch{
        Write-Log "Falha ao buscar mods '$Query': $_"
        return @()
    }

}

function Show-ModManager {

    $MinecraftVersion = Get-MinecraftVersion

    if([string]::IsNullOrWhiteSpace($MinecraftVersion)){
        $MinecraftVersion = (Get-VersionState).minecraft
    }

    if([string]::IsNullOrWhiteSpace($MinecraftVersion)){
        Write-WarningText "Instale o Forge primeiro."
        return
    }

    Write-Host ""
    Write-Host "------------- GERENCIADOR DE MODS -------------"
    Write-Host " [1] Buscar e instalar mod"
    Write-Host " [2] Listar mods instalados"
    Write-Host " [0] Voltar"
    Write-Host "-------------------------------------------------"
    Write-Host ""

    $Choice = Read-Host "Escolha uma opcao"

    switch($Choice){

        "1" {

            $Query = Read-Host "Buscar mod pelo nome (ENTER = cancelar)"

            if([string]::IsNullOrWhiteSpace($Query)){ return }

            $Hits = Search-ModrinthMods -Query $Query -MinecraftVersion $MinecraftVersion

            if(!$Hits -or $Hits.Count -eq 0){
                Write-WarningText "Nenhum mod encontrado (busca restrita a mods com build Forge para $MinecraftVersion)."
                return
            }

            Write-Host ""

            for($i = 0; $i -lt $Hits.Count; $i++){
                Write-Host (" [{0}] {1} - {2}" -f ($i + 1), $Hits[$i].title, $Hits[$i].description)
            }

            Write-Host ""

            $Pick = Read-Host "Numero do mod para instalar (ENTER = cancelar)"
            $Index = 0

            if([string]::IsNullOrWhiteSpace($Pick) -or ![int]::TryParse($Pick, [ref]$Index) -or $Index -lt 1 -or $Index -gt $Hits.Count){
                Write-Info "Cancelado."
                return
            }

            Install-ModrinthMod -Slug $Hits[$Index - 1].slug -MinecraftVersion $MinecraftVersion | Out-Null

        }

        "2" {

            $ModsDir = Join-Path $PSScriptRoot "..\server\mods"

            $Jars = if(Test-Path $ModsDir){ Get-ChildItem $ModsDir -Filter "*.jar" -ErrorAction SilentlyContinue } else { @() }

            if(!$Jars -or $Jars.Count -eq 0){
                Write-Info "Nenhum mod instalado."
                return
            }

            Write-Host ""

            foreach($Jar in $Jars){
                Write-Host " - $($Jar.Name)  ($(Format-Bytes $Jar.Length))"
            }

        }

    }

}
