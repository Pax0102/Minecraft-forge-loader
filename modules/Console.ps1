function Write-Info
{
    param([string]$Text)

    Write-Host "[INFO] $Text" -ForegroundColor Cyan
}

function Write-WarningText
{
    param([string]$Text)

    Write-Host "[WARN] $Text" -ForegroundColor Yellow
}

function Write-ErrorText
{
    param([string]$Text)

    Write-Host "[ERRO] $Text" -ForegroundColor Red
}

function Write-Success
{
    param([string]$Text)

    Write-Host "[ OK ] $Text" -ForegroundColor Green
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
