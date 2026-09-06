function Invoke-Download {

    param(
        [string]$Url,
        [string]$Output
    )

    try{

        $OutDir = Split-Path $Output -Parent

        if($OutDir -and !(Test-Path $OutDir)){
            New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
        }

        Write-Info "Baixando $(Split-Path $Output -Leaf)..."

        Invoke-WebRequest `
            -Uri $Url `
            -OutFile $Output `
            -UseBasicParsing

        if(!(Test-Path $Output)){
            throw "Falha no download."
        }

        Write-Success "Download concluido."

        return $true

    }
    catch{
        Write-ErrorText $_
        Write-Log "Falha ao baixar $Url : $_"
        return $false
    }

}
