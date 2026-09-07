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

    # Forge moderno (1.17+): instalado via run.bat/run.sh + arquivo de argumentos (@win_args.txt)
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

                # Nome da pasta = "<minecraft>-<forge>"
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

    # Forge legado (<= 1.16.5): jar executavel direto na pasta do servidor
    if(!$Result.Installed){

        $Jar = Get-ChildItem $Server -Filter "forge-*.jar" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "installer" } |
            Select-Object -First 1

        if($Jar){

            $Result.Installed = $true
            $Result.LaunchMode = "legacy"
            $Result.ServerJar = $Jar.FullName

            # Padrao classico usado por builds Forge <= 1.16.5:
            # forge-<mc>-<forge>[-universal].jar. Versoes "modernas" (1.17+)
            # nao chegam aqui (sao pegas pelo bloco run.bat/win_args.txt
            # acima). Se algum jar tiver nome fora desse padrao, o regex
            # simplesmente nao casa e Version/MinecraftVersion ficam vazios
            # aqui - sem problema, ha fallback logo abaixo para os valores
            # gravados em version.json.
            if($Jar.Name -match "^forge-([0-9][0-9a-zA-Z\.]*)-([0-9][0-9a-zA-Z\.]*?)(-universal)?\.jar$"){
                $Result.MinecraftVersion = $Matches[1]
                $Result.Version = $Matches[2]
            }

        }

    }

    # A versao instalada tambem fica registrada em version.json como fonte de verdade / fallback.
    $State = Get-VersionState

    if([string]::IsNullOrWhiteSpace($Result.Version) -and $State.forgeVersion){
        $Result.Version = $State.forgeVersion
    }

    if([string]::IsNullOrWhiteSpace($Result.MinecraftVersion) -and $State.minecraft){
        $Result.MinecraftVersion = $State.minecraft
    }

    return $Result

}
