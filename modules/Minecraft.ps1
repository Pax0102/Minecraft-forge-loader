function Get-VersionState {

    $Path = Join-Path $PSScriptRoot "..\version.json"

    if(!(Test-Path $Path)){
        return [PSCustomObject]@{
            minecraft    = ""
            forgeVersion = ""
            java         = ""
        }
    }

    try{
        return Get-Content $Path -Raw | ConvertFrom-Json
    }
    catch{
        return [PSCustomObject]@{
            minecraft    = ""
            forgeVersion = ""
            java         = ""
        }
    }

}

function Set-VersionState {

    param(
        [string]$Minecraft    = "",
        [string]$ForgeVersion = "",
        [string]$Java         = ""
    )

    $State = Get-VersionState

    if(![string]::IsNullOrWhiteSpace($Minecraft))   { $State.minecraft    = $Minecraft }
    if(![string]::IsNullOrWhiteSpace($ForgeVersion)){ $State.forgeVersion = $ForgeVersion }
    if(![string]::IsNullOrWhiteSpace($Java))         { $State.java         = $Java }

    $Path = Join-Path $PSScriptRoot "..\version.json"

    # UTF8 sem BOM (ver Set-Utf8NoBom em Utils.ps1).
    ($State | ConvertTo-Json) | Set-Utf8NoBom -Path $Path

    return $State

}
