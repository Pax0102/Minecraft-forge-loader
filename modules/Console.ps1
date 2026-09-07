function Write-ColorLine {

    # config.json "coloredConsole": false imprime sem -ForegroundColor.
    # Antes essa chave existia no config.json mas nada no codigo lia ela.
    param(
        [string]$Text,
        [System.ConsoleColor]$Color
    )

    if($Config -and $Config.coloredConsole -eq $false){
        Write-Host $Text
    }
    else{
        Write-Host $Text -ForegroundColor $Color
    }

}

function Write-Info
{
    param([string]$Text)

    Write-ColorLine "[INFO] $Text" Cyan
}

function Write-WarningText
{
    param([string]$Text)

    Write-ColorLine "[WARN] $Text" Yellow
}

function Write-ErrorText
{
    param([string]$Text)

    Write-ColorLine "[ERRO] $Text" Red
}

function Write-Success
{
    param([string]$Text)

    Write-ColorLine "[ OK ] $Text" Green
}

function Show-Java {

    param($Java)

    if(!$Java.Installed){
        Write-ErrorText "Java nao encontrado."
        return
    }

    Write-Success "Java $($Java.Version)  ($($Java.Path))"

}

function Show-Forge {

    param($Forge)

    if(!$Forge.Installed){
        Write-WarningText "Forge nao instalado."
        return
    }

    Write-Success "Forge $($Forge.Version)"

}

function Show-VersionStatus {

    param(
        [string]$Name,
        [string]$Current,
        [string]$Latest
    )

    if([string]::IsNullOrWhiteSpace($Latest)){
        Write-WarningText "$Name : nao foi possivel consultar a versao mais recente."
        return
    }

    $Result = Compare-Version $Current $Latest

    switch($Result){

        0  { Write-Success "$Name atualizado ($Current)" }
        -1 { Write-WarningText "$Name desatualizado ($Current -> $Latest)" }
        1  { Write-WarningText "$Name possui versao superior ($Current)" }

    }

}
