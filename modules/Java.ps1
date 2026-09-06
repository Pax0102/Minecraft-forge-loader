function Get-JavaInfo {

    $Result = @{
        Installed = $false
        Version = ""
        Path = ""
        Home = ""
        Major = 0
    }

    $Java = Get-Command java.exe -ErrorAction SilentlyContinue

    if($null -eq $Java){
        $Java = Get-Command java -ErrorAction SilentlyContinue
    }

    if($null -eq $Java){
        return $Result
    }

    $Result.Installed = $true
    $Result.Path = $Java.Source
    $Result.Home = $env:JAVA_HOME

    try{

        $Output = & $Java.Source -version 2>&1 | Out-String

        if($Output -match 'version\s+"([0-9]+)(\.[0-9]+)*[^"]*"'){

            $Result.Version = $Matches[0] -replace 'version\s+',''
            $Result.Version = $Result.Version.Trim('"')

            $Major = [int]$Matches[1]

            # Java 8 e anteriores reportam como "1.8.0_xxx"
            if($Major -eq 1 -and $Output -match '"1\.(\d+)'){
                $Major = [int]$Matches[1]
            }

            $Result.Major = $Major

        }
        else{
            $Result.Version = "Desconhecida"
        }

    }
    catch{
        $Result.Version = "Desconhecida"
    }

    return $Result

}

function Get-RequiredJavaMajor {

    param([string]$MinecraftVersion)

    if([string]::IsNullOrWhiteSpace($MinecraftVersion)){
        return 21
    }

    $Parts = Normalize-Version $MinecraftVersion

    if($Parts.Count -lt 2){
        return 21
    }

    $Minor = $Parts[1]
    $Patch = if($Parts.Count -ge 3){ $Parts[2] } else { 0 }

    # Regras oficiais (aproximadas) de requisito de Java por versao do Minecraft
    if($Minor -ge 21){ return 21 }
    if($Minor -eq 20 -and $Patch -ge 5){ return 21 }
    if($Minor -ge 18){ return 17 }
    if($Minor -eq 17){ return 16 }

    return 8

}

function Test-JavaCompatibility {

    param(
        $Java,
        [string]$MinecraftVersion
    )

    $Required = Get-RequiredJavaMajor $MinecraftVersion

    if(!$Java.Installed){
        Write-ErrorText "Java nao esta instalado. Esta versao do Minecraft requer Java $Required ou superior."
        Write-Log "Java ausente. Requerido: $Required"
        return $false
    }

    if($Java.Major -eq 0){
        Write-WarningText "Nao foi possivel determinar a versao major do Java instalado."
        return $true
    }

    if($Java.Major -lt $Required){
        Write-WarningText "Java $($Java.Major) detectado, porem o Minecraft $MinecraftVersion requer Java $Required ou superior."
        Write-Log "Java incompativel: instalado=$($Java.Major) requerido=$Required"
        return $false
    }

    Write-Success "Java $($Java.Major) e compativel (requer $Required+)."

    return $true

}
