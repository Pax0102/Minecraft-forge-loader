function Invoke-JavaVersionProbe {

    param([string]$JavaPath)

    $Result = @{ Major = 0; Version = "Desconhecida" }

    if([string]::IsNullOrWhiteSpace($JavaPath) -or !(Test-Path $JavaPath)){
        return $Result
    }

    $PreviousEap = $ErrorActionPreference

    try{

        # "java -version" escreve no stderr (sempre foi assim). Com
        # $ErrorActionPreference = "Stop" (definido globalmente no Main.ps1),
        # redirecionar stderr de um processo nativo (2>&1) faz a primeira
        # linha virar um erro terminante e interromper a leitura antes da
        # hora - por isso relaxamos isso so durante esta chamada.
        $ErrorActionPreference = "SilentlyContinue"

        $Output = & $JavaPath -version 2>&1 | Out-String

        if($Output -match 'version\s+"([^"]+)"'){

            $Result.Version = $Matches[1]

            if($Output -match 'version\s+"([0-9]+)(\.[0-9]+)*[^"]*"'){

                $Major = [int]$Matches[1]

                # Java 8 e anteriores reportam como "1.8.0_xxx"
                if($Major -eq 1 -and $Output -match '"1\.(\d+)'){
                    $Major = [int]$Matches[1]
                }

                $Result.Major = $Major

            }

        }

    }
    catch{
        Write-Log "Falha ao consultar versao do Java em '$JavaPath': $_"
    }
    finally{
        $ErrorActionPreference = $PreviousEap
    }

    return $Result

}

function Get-JavaMajorFromExe {

    param([string]$JavaPath)

    return (Invoke-JavaVersionProbe $JavaPath).Major

}

function Get-BundledJavaPath {

    param([int]$RequiredMajor)

    if($RequiredMajor -le 0){
        return $null
    }

    # Resolve o caminho com ..\ expandido para evitar falhas de probe
    # causadas por caminhos relativos com PSScriptRoot de modulos
    $RuntimeDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\runtime"))
    $Exe        = Join-Path $RuntimeDir "jdk-$RequiredMajor\bin\java.exe"

    if(Test-Path $Exe){
        return $Exe
    }

    return $null

}

function Install-Java {

    param([int]$RequiredMajor = 21)

    $Arch = if($env:PROCESSOR_ARCHITECTURE -eq "ARM64"){ "aarch64" } else { "x64" }

    $DownloadsDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\downloads"))
    $RuntimeDir   = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\runtime"))

    foreach($Dir in @($DownloadsDir, $RuntimeDir)){
        if(!(Test-Path $Dir)){
            New-Item -ItemType Directory -Path $Dir | Out-Null
        }
    }

    $ZipPath = Join-Path $DownloadsDir "jdk-$RequiredMajor-$Arch.zip"

    # API oficial da Eclipse Adoptium (Temurin) - sempre aponta pro build GA mais recente
    # daquela versao major, sem precisar saber o numero exato de antemao.
    $Url = "https://api.adoptium.net/v3/binary/latest/$RequiredMajor/ga/windows/$Arch/jdk/hotspot/normal/eclipse?project=jdk"

    Write-Info "Java $RequiredMajor nao encontrado. Baixando um JDK portatil automaticamente (Eclipse Temurin)..."
    Write-Log "Baixando JDK $RequiredMajor ($Arch) via Adoptium: $Url"

    try{

        if(!(Invoke-VerifiedDownload -Url $Url -Output $ZipPath)){
            Write-ErrorText "Falha ao baixar o Java $RequiredMajor automaticamente."
            Write-Log "Falha ao baixar JDK $RequiredMajor via Adoptium."
            return $null
        }

        $ExtractDir = Join-Path $RuntimeDir "_extract_tmp_$RequiredMajor"

        if(Test-Path $ExtractDir){
            Remove-Item $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        Expand-Archive -Path $ZipPath -DestinationPath $ExtractDir -Force

        # O zip do Adoptium contem uma unica pasta raiz, ex.: "jdk-21.0.4+7"
        $ExtractedFolder = Get-ChildItem $ExtractDir -Directory -ErrorAction SilentlyContinue | Select-Object -First 1

        if(!$ExtractedFolder){
            throw "Estrutura inesperada no pacote do Java baixado (pasta raiz nao encontrada)."
        }

        $FinalDir = Join-Path $RuntimeDir "jdk-$RequiredMajor"

        if(Test-Path $FinalDir){
            Remove-Item $FinalDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        Move-Item $ExtractedFolder.FullName $FinalDir -Force

        $JavaExe = Join-Path $FinalDir "bin\java.exe"

        if(!(Test-Path $JavaExe)){
            throw "java.exe nao encontrado apos a extracao em '$FinalDir'."
        }

        Write-Success "Java $RequiredMajor instalado em .\runtime\jdk-$RequiredMajor (uso interno do ServerManager, nao afeta o resto do sistema)."
        Write-Log "JDK $RequiredMajor instalado com sucesso em $FinalDir."

        return $JavaExe

    }
    catch{

        Write-ErrorText "Falha ao instalar o Java $RequiredMajor automaticamente: $_"
        Write-Log "Falha ao instalar JDK $RequiredMajor : $_"
        return $null

    }
    finally{

        Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue

        $LeftoverExtract = Join-Path $RuntimeDir "_extract_tmp_$RequiredMajor"
        if(Test-Path $LeftoverExtract){
            Remove-Item $LeftoverExtract -Recurse -Force -ErrorAction SilentlyContinue
        }

    }

}

function Get-JavaInfo {

    param(
        [int]$RequiredMajor = 0,
        [switch]$AutoInstall
    )

    $Result = @{
        Installed = $false
        Version   = ""
        Path      = ""
        Home      = ""
        Major     = 0
        Bundled   = $false
    }

    $JavaPath = $null

    # 1) Java bundled pelo proprio ServerManager
    # A pasta se chama "jdk-$RequiredMajor", entao se o exe existe, a versao
    # ja e exatamente a que foi pedida — nao precisamos rodar java -version
    # para confirmar (o probe falha em alguns ambientes por restricoes de PATH
    # ou encoding, e causaria um re-download desnecessario).
    if($RequiredMajor -gt 0){

        $Candidate = Get-BundledJavaPath -RequiredMajor $RequiredMajor

        if($Candidate){
            $JavaPath          = $Candidate
            $Result.Bundled    = $true
            # Major e certo pela convencao do nome da pasta; probe so para obter
            # a versao completa (ex: "21.0.7+6") — se falhar, usamos o major da pasta.
            $ProbeResult       = Invoke-JavaVersionProbe $Candidate
            $Result.Major      = if($ProbeResult.Major -gt 0){ $ProbeResult.Major } else { $RequiredMajor }
            $Result.Version    = if($ProbeResult.Major -gt 0){ $ProbeResult.Version } else { "$RequiredMajor (bundled)" }
            $Result.Installed  = $true
            $Result.Path       = $Candidate
            $Result.Home       = Split-Path (Split-Path $Candidate -Parent) -Parent
            Write-Log "Java bundled encontrado: pasta jdk-$RequiredMajor, major=$($Result.Major), path=$Candidate"
            return $Result
        }

    }

    # 2) Java ja instalado no sistema (PATH) - so usa se nao achou bundled
    if(!$JavaPath){

        $Cmd = Get-Command java.exe -ErrorAction SilentlyContinue

        if($null -eq $Cmd){
            $Cmd = Get-Command java -ErrorAction SilentlyContinue
        }

        if($Cmd){
            $SysPath = $Cmd.Source
            # Verifica se a versao do sistema e compativel com o requerido
            if($RequiredMajor -gt 0){
                $SysMajor = Get-JavaMajorFromExe $SysPath
                if($SysMajor -ge $RequiredMajor){
                    $JavaPath = $SysPath
                }
            }
            else{
                $JavaPath = $SysPath
            }
        }

    }

    # 3) Nenhum compativel encontrado: baixa JDK portatil (apenas uma vez)
    if(!$JavaPath -and $RequiredMajor -gt 0 -and $AutoInstall){

        $Downloaded = Install-Java -RequiredMajor $RequiredMajor

        if($Downloaded){
            $JavaPath = $Downloaded
            $Result.Bundled = $true
        }

    }

    if(!$JavaPath -or !(Test-Path $JavaPath)){
        return $Result
    }

    $Result.Installed = $true
    $Result.Path      = $JavaPath
    $Result.Home      = Split-Path (Split-Path $JavaPath -Parent) -Parent

    $Probe = Invoke-JavaVersionProbe $JavaPath
    $Result.Major   = $Probe.Major
    $Result.Version = $Probe.Version

    return $Result

}

function Get-WorkingJava {

    param([string]$MinecraftVersion)

    $Required    = Get-RequiredJavaMajor $MinecraftVersion
    $AutoInstall = !$Config -or $Config.autoInstallJava -ne $false

    return Get-JavaInfo -RequiredMajor $Required -AutoInstall:$AutoInstall

}

function Get-RequiredJavaMajor {

    param([string]$MinecraftVersion)

    # Ultimo requisito de Java conhecido para o esquema de versao por ano
    # (26.1+, formato YY.drop.hotfix). Se o Mojang exigir uma versao ainda
    # mais nova no futuro, atualize este numero.
    $UltimoConhecido = 25

    if([string]::IsNullOrWhiteSpace($MinecraftVersion)){
        return $UltimoConhecido
    }

    $Parts = Normalize-Version $MinecraftVersion

    if($Parts.Count -lt 1){
        return $UltimoConhecido
    }

    # A partir da 26.1 (lancada em 24/03/2026, "Tiny Takeover") o Minecraft
    # passou a usar o novo esquema de versionamento por ano (YY.drop.hotfix,
    # ex.: 26.1, 26.2) e exige Java 25+ (o launcher oficial ja embute o
    # Microsoft build do OpenJDK 25). Nao existiu um esquema "25.x" - o
    # ano-base do novo formato comeca em 26.
    if($Parts[0] -ge 26){
        return 25
    }

    # Esquema classico 1.X.Y
    if($Parts[0] -ne 1 -or $Parts.Count -lt 2){
        return $UltimoConhecido
    }

    $Minor = $Parts[1]
    $Patch = if($Parts.Count -ge 3){ $Parts[2] } else { 0 }

    # Regras oficiais de requisito de Java por versao do Minecraft (esquema 1.X.Y)
    if($Minor -ge 21)                      { return 21 }
    if($Minor -eq 20 -and $Patch -ge 5)   { return 21 }
    if($Minor -ge 18)                      { return 17 }
    if($Minor -eq 17)                      { return 16 }

    return 8

}

function Show-JavaRequirement {

    param([string]$MinecraftVersion)

    $Required = Get-RequiredJavaMajor $MinecraftVersion

    Write-Info "Minecraft $MinecraftVersion requer Java $Required ou superior."

}

function Test-JavaCompatibility {

    param(
        $Java,
        [string]$MinecraftVersion
    )

    $Required = Get-RequiredJavaMajor $MinecraftVersion

    if(!$Java.Installed){
        Write-ErrorText "Java nao esta disponivel. Esta versao do Minecraft requer Java $Required ou superior."
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

    Write-Success "Java $($Java.Major) compativel com Minecraft $MinecraftVersion (requer $Required+)."

    return $true

}
