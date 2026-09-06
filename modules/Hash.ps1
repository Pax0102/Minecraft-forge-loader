function Get-FileHashValue {

    param(
        [string]$Path,
        [string]$Algorithm = "SHA256"
    )

    if(!(Test-Path $Path)){
        return $null
    }

    return (Get-FileHash -Path $Path -Algorithm $Algorithm).Hash

}

function Test-FileHash {

    param(
        [string]$Path,
        [string]$ExpectedHash,
        [string]$Algorithm = "SHA256"
    )

    if([string]::IsNullOrWhiteSpace($ExpectedHash)){
        return $true
    }

    $Actual = Get-FileHashValue -Path $Path -Algorithm $Algorithm

    if(!$Actual){
        return $false
    }

    return $Actual.ToLower() -eq $ExpectedHash.ToLower()

}
