function Get-RootPath {

    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

}

function Format-Bytes {

    param([long]$Bytes)

    if($Bytes -ge 1GB){ return "{0:N2} GB" -f ($Bytes / 1GB) }
    if($Bytes -ge 1MB){ return "{0:N2} MB" -f ($Bytes / 1MB) }
    if($Bytes -ge 1KB){ return "{0:N2} KB" -f ($Bytes / 1KB) }

    return "$Bytes B"

}

function Set-Utf8NoBom {

    # -Encoding UTF8 no Windows PowerShell 5.1 SEMPRE grava um BOM
    # (EF BB BF) no inicio do arquivo. Isso corrompe a primeira linha de
    # arquivos que o Java le diretamente (server.properties) ou que sao
    # comparados/parseados como texto puro (config.json, version.json).
    # Esta funcao centraliza a gravacao em UTF8 SEM BOM para esses casos.

    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Content
    )

    begin{
        $Lines = @()
    }
    process{
        $Lines += $Content
    }
    end{
        $Text = ($Lines -join "`r`n")
        $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($Path, $Text + "`r`n", $Utf8NoBom)
    }

}

function Read-YesNo {

    param(
        [string]$Prompt,
        [bool]$DefaultYes = $true
    )

    $Suffix = if($DefaultYes){ "(S/n)" } else { "(s/N)" }

    $Resp = Read-Host "$Prompt $Suffix"

    if([string]::IsNullOrWhiteSpace($Resp)){
        return $DefaultYes
    }

    return $Resp.Trim().ToUpper() -eq "S"

}

function Clear-TempFiles {

    # Nenhum download real e escrito em ..\temp (fica tudo em ..\downloads,
    # que normalmente se autolimpa dentro de Install-Java/Install-Forge).
    # Ainda assim, downloads podem ficar "penduradas" ali quando uma
    # instalacao falha no meio (ex.: Forge Installer retorna erro antes do
    # bloco que remove o instalador). Por isso esta opcao agora limpa as
    # DUAS pastas, para deixar de ser decorativa.
    $TempDir      = Join-Path $PSScriptRoot "..\temp"
    $DownloadsDir = Join-Path $PSScriptRoot "..\downloads"

    $Removed = 0
    $AnyDir  = $false

    foreach($Dir in @($TempDir, $DownloadsDir)){

        if(!(Test-Path $Dir)){
            New-Item -ItemType Directory -Path $Dir | Out-Null
            continue
        }

        $AnyDir = $true

        $Items = Get-ChildItem $Dir -Force -ErrorAction SilentlyContinue

        foreach($Item in $Items){

            try{
                Remove-Item $Item.FullName -Recurse -Force -ErrorAction Stop
                $Removed++
            }
            catch{
                Write-WarningText "Nao foi possivel remover: $($Item.FullName)"
            }

        }

    }

    if(!$AnyDir -or $Removed -eq 0){
        Write-Info "Nenhum arquivo temporario para limpar."
        return
    }

    Write-Success "$Removed arquivo(s) temporario(s) removido(s) (temp + downloads)."
    Write-Log "Temporarios limpos ($Removed itens, incluindo downloads pendentes)."

}

function Invoke-SafeAction {

    param([scriptblock]$Action)

    try{
        & $Action
    }
    catch{

        Write-Host ""
        Write-ErrorText "Ocorreu um erro inesperado: $($_.Exception.Message)"
        Write-Log "ERRO NAO TRATADO: $($_.Exception.Message)"

        if($_.ScriptStackTrace){
            Write-Log $_.ScriptStackTrace
        }

        Write-Host "Detalhes foram salvos no log (opcao [7] nao mostra este log de erros; veja update.log)."

    }

}
