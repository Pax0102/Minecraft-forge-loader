function Get-VersionState {

    $Path = Join-Path $PSScriptRoot "..\version.json"

    if(!(Test-Path $Path)){
        return [PSCustomObject]@{
            minecraft = ""
            forgeVersion = ""
            java = ""
        }
    }

    try{
        return Get-Content $Path -Raw | ConvertFrom-Json
    }
    catch{
        return [PSCustomObject]@{
            minecraft = ""
            forgeVersion = ""
            java = ""
        }
    }

}

function Set-VersionState {

    param(
        [string]$Minecraft,
        [string]$ForgeVersion,
        [string]$Java
    )

    $State = Get-VersionState

    if($Minecraft){ $State.minecraft = $Minecraft }
    if($ForgeVersion){ $State.forgeVersion = $ForgeVersion }
    if($Java){ $State.java = $Java }

    $Path = Join-Path $PSScriptRoot "..\version.json"

    $State | ConvertTo-Json | Set-Content -Path $Path -Encoding UTF8

    return $State

}
