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
        ($Config | ConvertTo-Json -Depth 5) | Set-Utf8NoBom -Path $Path
        return $true
    }
    catch{
        Write-Log "Falha ao salvar config.json ($Key=$Value): $_"
        return $false
    }

}
