function Get-ModrinthVersions {

    param(
        [string]$Slug,
        [string]$MinecraftVersion
    )

    try{
        $Url = "https://api.modrinth.com/v2/project/$Slug/version?game_versions=[`"$MinecraftVersion`"]&loaders=[`"forge`"]"
        return Invoke-RestMethod -Uri $Url -UseBasicParsing
    }
    catch{
        Write-Log "Falha ao consultar mod '$Slug' no Modrinth: $_"
        return $null
    }

}

function Install-ModrinthMod {

    param(
        [string]$Slug,
        [string]$MinecraftVersion,
        [switch]$Silent
    )

    $Versions = Get-ModrinthVersions -Slug $Slug -MinecraftVersion $MinecraftVersion

    if(!$Versions -or $Versions.Count -eq 0){
        if(!$Silent){ Write-WarningText "Nenhuma versao de '$Slug' encontrada para $MinecraftVersion." }
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

    Get-ChildItem $ModsDir -Filter "$Slug-*.jar" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    $Output = Join-Path $ModsDir $File.filename
    $ExpectedHash = if($File.hashes -and $File.hashes.sha512){ $File.hashes.sha512 } else { "" }

    if(!(Invoke-VerifiedDownload -Url $File.url -Output $Output -ExpectedHash $ExpectedHash -HashAlgorithm "SHA512")){
        if(!$Silent){ Write-ErrorText "Falha ao instalar '$Slug'." }
        return $null
    }

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
                Write-WarningText "Nenhum mod encontrado."
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
