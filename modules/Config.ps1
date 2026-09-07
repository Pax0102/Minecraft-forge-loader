$Config = Get-Content `
    "$PSScriptRoot\..\config.json" `
    -Raw |
    ConvertFrom-Json

function Set-ConfigValue {

    param(
        [string]$Key,
        $Value
    )

    $Path = Join-Path $PSScriptRoot "..\config.json"

    $Config | Add-Member -MemberType NoteProperty -Name $Key -Value $Value -Force

    try{
        # UTF8 sem BOM (ver Set-Utf8NoBom em Utils.ps1) - evita corromper a
        # leitura do config.json em execucoes futuras.
        ($Config | ConvertTo-Json -Depth 5) | Set-Utf8NoBom -Path $Path
        return $true
    }
    catch{
        Write-Log "Falha ao salvar config.json ($Key=$Value): $_"
        return $false
    }

}
