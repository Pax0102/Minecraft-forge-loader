function Get-ServerProperties {

    $Path = Join-Path $PSScriptRoot "..\server\server.properties"

    if(!(Test-Path $Path)){
        return @{}
    }

    $Map = @{}

    Get-Content $Path | ForEach-Object {
        if($_ -match "^\s*([^#=\s][^=]*)=(.*)$"){
            $Map[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }

    return $Map

}

function Set-ServerProperty {

    param(
        [string]$Key,
        [string]$Value,
        [switch]$Silent
    )

    $Path = Join-Path $PSScriptRoot "..\server\server.properties"

    if(!(Test-Path $Path)){
        if(!$Silent){
            Write-WarningText "server.properties nao encontrado. Inicie o servidor ao menos uma vez para gera-lo."
        }
        return $false
    }

    $Found = $false

    $NewLines = Get-Content $Path | ForEach-Object {

        if($_ -match "^\s*$([regex]::Escape($Key))\s*="){
            $Found = $true
            "$Key=$Value"
        }
        else{
            $_
        }

    }

    if(!$Found){
        $NewLines += "$Key=$Value"
    }

    # UTF8 sem BOM: um BOM na primeira linha do server.properties pode
    # corromper a leitura da primeira propriedade pelo parser do Java.
    $NewLines | Set-Utf8NoBom -Path $Path

    if(!$Silent){
        Write-Success "$Key definido como '$Value'."
    }

    Write-Log "server.properties: $Key=$Value"

    return $true

}

function Sync-RconSettings {

    if(!$Config.rconEnabled -or [string]::IsNullOrWhiteSpace($Config.rconPassword)){
        return
    }

    $Path = Join-Path $PSScriptRoot "..\server\server.properties"

    if(!(Test-Path $Path)){
        return
    }

    Set-ServerProperty -Key "enable-rcon" -Value "true" -Silent | Out-Null
    Set-ServerProperty -Key "rcon.port" -Value "$($Config.rconPort)" -Silent | Out-Null
    Set-ServerProperty -Key "rcon.password" -Value $Config.rconPassword -Silent | Out-Null

    Write-Log "RCON sincronizado com server.properties (porta $($Config.rconPort))."

}

function Show-PropertiesMenu {

    $Editable = @(
        @{ Key = "motd"; Label = "Mensagem do servidor (MOTD)" },
        @{ Key = "max-players"; Label = "Maximo de jogadores" },
        @{ Key = "difficulty"; Label = "Dificuldade (peaceful/easy/normal/hard)" },
        @{ Key = "gamemode"; Label = "Modo de jogo (survival/creative/adventure/spectator)" },
        @{ Key = "pvp"; Label = "PvP habilitado (true/false)" },
        @{ Key = "view-distance"; Label = "Distancia de renderizacao (chunks)" },
        @{ Key = "white-list"; Label = "Whitelist habilitada (true/false)" },
        @{ Key = "online-mode"; Label = "Autenticacao Mojang / online-mode (true/false)" },
        @{ Key = "enable-command-block"; Label = "Blocos de comando (true/false)" }
    )

    $Current = Get-ServerProperties

    Write-Host ""
    Write-Host "----------- server.properties -----------"

    for($i = 0; $i -lt $Editable.Count; $i++){

        $K = $Editable[$i].Key
        $V = if($Current.ContainsKey($K)){ $Current[$K] } else { "(nao definido)" }

        Write-Host (" [{0}] {1,-22} = {2}" -f ($i + 1), $K, $V)

    }

    Write-Host " [0] Voltar"
    Write-Host "-------------------------------------------"
    Write-Host ""

    $Choice = Read-Host "Escolha uma propriedade para editar"

    if($Choice -eq "0" -or [string]::IsNullOrWhiteSpace($Choice)){
        return
    }

    $Index = 0

    if(![int]::TryParse($Choice, [ref]$Index) -or $Index -lt 1 -or $Index -gt $Editable.Count){
        Write-ErrorText "Opcao invalida."
        return
    }

    $Selected = $Editable[$Index - 1]

    $NewValue = Read-Host "Novo valor para '$($Selected.Label)' (ENTER = cancelar)"

    if([string]::IsNullOrWhiteSpace($NewValue)){
        Write-Info "Nenhuma alteracao feita."
        return
    }

    Set-ServerProperty -Key $Selected.Key -Value $NewValue | Out-Null

}
