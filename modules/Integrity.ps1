function Test-JarIntegrity {

    param([string]$Path)

    if(!(Test-Path $Path)){
        Write-ErrorText "Arquivo nao encontrado: $Path"
        return $false
    }

    $Info = Get-Item $Path

    if($Info.Length -le 0){
        Write-ErrorText "Arquivo vazio: $Path"
        return $false
    }

    try{

        $Stream = [System.IO.File]::OpenRead($Path)
        $Bytes  = New-Object byte[] 4
        $Stream.Read($Bytes, 0, 4) | Out-Null
        $Stream.Close()

        # Assinatura padrao de arquivos ZIP/JAR: 'PK'
        if($Bytes[0] -ne 0x50 -or $Bytes[1] -ne 0x4B){
            Write-ErrorText "Arquivo corrompido (assinatura invalida): $(Split-Path $Path -Leaf)"
            Write-Log "Integridade FALHOU (assinatura invalida): $Path"
            return $false
        }

    }
    catch{
        Write-ErrorText "Falha ao verificar integridade: $_"
        Write-Log "Falha ao verificar integridade de $Path : $_"
        return $false
    }

    Write-Success "Integridade verificada: $(Split-Path $Path -Leaf) ($(Format-Bytes $Info.Length))"
    Write-Log "Integridade OK: $Path ($(Format-Bytes $Info.Length))"

    return $true

}

function Invoke-VerifiedDownload {

    param(
        [string]$Url,
        [string]$Output,
        [string]$ExpectedHash  = "",
        [string]$HashAlgorithm = "SHA256"
    )

    $VerifyDownloads = !$Config -or $Config.verifyDownloads -ne $false

    # Se o arquivo ja existe, valido e com hash correto, nao baixa de novo
    if(Test-Path $Output){

        $AlreadyGood = $true

        if($VerifyDownloads){
            $AlreadyGood = Test-JarIntegrity $Output
        }

        if($AlreadyGood -and ![string]::IsNullOrWhiteSpace($ExpectedHash) -and $VerifyDownloads){
            $AlreadyGood = Test-FileHash -Path $Output -ExpectedHash $ExpectedHash -Algorithm $HashAlgorithm
        }

        if($AlreadyGood){
            Write-Info "$(Split-Path $Output -Leaf) ja existe e esta integro. Pulando download."
            Write-Log "Download pulado (arquivo ja presente e valido): $Output"
            return $true
        }

        # Arquivo existente invalido: remove e baixa novamente
        Write-WarningText "Arquivo existente invalido. Baixando novamente: $(Split-Path $Output -Leaf)"
        Remove-Item $Output -Force -ErrorAction SilentlyContinue

    }

    if(!(Invoke-Download $Url $Output)){
        return $false
    }

    if($VerifyDownloads){

        if(!(Test-JarIntegrity $Output)){
            Remove-Item $Output -Force -ErrorAction SilentlyContinue
            return $false
        }

    }
    else{
        Write-Info "Verificacao de integridade desativada (verifyDownloads=false)."
    }

    if(![string]::IsNullOrWhiteSpace($ExpectedHash) -and $VerifyDownloads){

        if(!(Test-FileHash -Path $Output -ExpectedHash $ExpectedHash -Algorithm $HashAlgorithm)){
            Write-ErrorText "Hash nao confere para: $(Split-Path $Output -Leaf)"
            Write-Log "Hash invalido para $Output"
            Remove-Item $Output -Force -ErrorAction SilentlyContinue
            return $false
        }

        Write-Success "Hash $HashAlgorithm verificado."

    }

    return $true

}
