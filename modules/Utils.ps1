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

    $TempDir = Join-Path $PSScriptRoot "..\temp"

    if(!(Test-Path $TempDir)){
        New-Item -ItemType Directory -Path $TempDir | Out-Null
        Write-Info "Pasta temp criada."
        return
    }

    $Items = Get-ChildItem $TempDir -Force -ErrorAction SilentlyContinue

    if(!$Items -or $Items.Count -eq 0){
        Write-Info "Nenhum arquivo temporario para limpar."
        return
    }

    $Removed = 0

    foreach($Item in $Items){

        try{
            Remove-Item $Item.FullName -Recurse -Force -ErrorAction Stop
            $Removed++
        }
        catch{
            Write-WarningText "Nao foi possivel remover: $($Item.FullName)"
        }

    }

    Write-Success "$Removed arquivo(s) temporario(s) removido(s)."
    Write-Log "Temporarios limpos ($Removed itens)."

}
