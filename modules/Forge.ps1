function Get-ForgeInfo {

    $Result = @{
        Installed = $false
        Version = ""
        MinecraftVersion = ""
        LaunchMode = ""
        ServerJar = ""
        ArgsFile = ""
    }

    $Server = Join-Path $PSScriptRoot "..\server"

    if(!(Test-Path $Server)){
        return $Result
    }

    $ForgeLibDir = Join-Path $Server "libraries\net\minecraftforge\forge"

    if(Test-Path $ForgeLibDir){

        $VersionFolder = Get-ChildItem $ForgeLibDir -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            Select-Object -First 1

        if($VersionFolder){

            $ArgsFile = Get-ChildItem $VersionFolder.FullName -Filter "win_args.txt" -ErrorAction SilentlyContinue |
                Select-Object -First 1

            if($ArgsFile){

                $Result.Installed = $true
                $Result.LaunchMode = "modern"
                $Result.ArgsFile = $ArgsFile.FullName

                if($VersionFolder.Name -match "^(.+)-([^-]+)$"){
                    $Result.MinecraftVersion = $Matches[1]
                    $Result.Version = $Matches[2]
                }
                else{
                    $Result.Version = $VersionFolder.Name
                }

            }

        }

    }

    if(!$Result.Installed){

        $Jar = Get-ChildItem $Server -Filter "forge-*.jar" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "installer" } |
            Select-Object -First 1

        if($Jar){

            $Result.Installed = $true
            $Result.LaunchMode = "legacy"
            $Result.ServerJar = $Jar.FullName

            if($Jar.Name -match "^forge-([0-9][0-9a-zA-Z\.]*)-([0-9][0-9a-zA-Z\.]*?)(-universal)?\.jar$"){
                $Result.MinecraftVersion = $Matches[1]
                $Result.Version = $Matches[2]
            }

        }

    }

    $State = Get-VersionState

    if([string]::IsNullOrWhiteSpace($Result.Version) -and $State.forgeVersion){
        $Result.Version = $State.forgeVersion
    }

    if([string]::IsNullOrWhiteSpace($Result.MinecraftVersion) -and $State.minecraft){
        $Result.MinecraftVersion = $State.minecraft
    }

    return $Result

}
