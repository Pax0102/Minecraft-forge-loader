function Normalize-Version {

    param(
        [string]$Version
    )

    if([string]::IsNullOrWhiteSpace($Version)){
        return @()
    }

    $Version = $Version.ToLower()

    $Version = $Version `
        -replace "snapshot","" `
        -replace "pre","." `
        -replace "rc","." `
        -replace "[^0-9.]",""

    return $Version.Split(".") |
        Where-Object { $_ -ne "" } |
        ForEach-Object { [int]$_ }

}

function Compare-Version {

    param(
        [string]$Current,
        [string]$Latest
    )

    $A = Normalize-Version $Current
    $B = Normalize-Version $Latest

    $Max = [Math]::Max($A.Count, $B.Count)

    for($i = 0; $i -lt $Max; $i++){

        $VA = 0
        $VB = 0

        if($i -lt $A.Count){
            $VA = $A[$i]
        }

        if($i -lt $B.Count){
            $VB = $B[$i]
        }

        if($VA -lt $VB){
            return -1
        }

        if($VA -gt $VB){
            return 1
        }

    }

    return 0

}

function Get-MinecraftVersion {

    $Forge = Get-ForgeInfo

    if($Forge.Installed -and $Forge.MinecraftVersion){
        return $Forge.MinecraftVersion
    }

    return $null

}

function Get-LatestMinecraftVersion {

    try{

        $Manifest = Invoke-RestMethod "https://launchermeta.mojang.com/mc/game/version_manifest.json"

        return $Manifest.latest.release

    }
    catch{
        return $null
    }

}

function Get-LatestForgeVersion {

    param($MinecraftVersion)

    try{

        $Promotions = Invoke-RestMethod "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json"

        $RecommendedKey = "$MinecraftVersion-recommended"
        $LatestKey = "$MinecraftVersion-latest"

        $Recommended = $Promotions.promos.$RecommendedKey

        if($Recommended){
            return $Recommended
        }

        return $Promotions.promos.$LatestKey

    }
    catch{
        return $null
    }

}
