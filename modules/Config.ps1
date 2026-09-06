$Config = Get-Content `
    "$PSScriptRoot\..\config.json" `
    -Raw |
    ConvertFrom-Json
