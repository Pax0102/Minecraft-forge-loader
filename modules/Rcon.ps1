function Send-RconPacket {

    param($Stream, [int]$Type, [string]$Payload, [int]$RequestId = 1)

    try{

        $PayloadBytes = [System.Text.Encoding]::ASCII.GetBytes($Payload)
        $Length = 4 + 4 + $PayloadBytes.Length + 2
        $Buffer = New-Object byte[] ($Length + 4)

        [BitConverter]::GetBytes($Length).CopyTo($Buffer, 0)
        [BitConverter]::GetBytes($RequestId).CopyTo($Buffer, 4)
        [BitConverter]::GetBytes($Type).CopyTo($Buffer, 8)
        $PayloadBytes.CopyTo($Buffer, 12)

        $Stream.Write($Buffer, 0, $Buffer.Length)
        $Stream.Flush()

        return $true

    }
    catch{
        return $false
    }

}

function Read-RconPacket {

    param($Stream)

    try{

        $LenBytes = New-Object byte[] 4
        $Stream.Read($LenBytes, 0, 4) | Out-Null
        $Length = [BitConverter]::ToInt32($LenBytes, 0)

        $Body = New-Object byte[] $Length
        $Read = 0

        while($Read -lt $Length){
            $Read += $Stream.Read($Body, $Read, $Length - $Read)
        }

        $RequestId = [BitConverter]::ToInt32($Body, 0)
        $PayloadLength = $Length - 10
        $Payload = ""

        if($PayloadLength -gt 0){
            $Payload = [System.Text.Encoding]::ASCII.GetString($Body, 8, $PayloadLength)
        }

        return @{ RequestId = $RequestId; Payload = $Payload }

    }
    catch{
        return $null
    }

}

function Connect-Rcon {

    param(
        [string]$HostName = "127.0.0.1",
        [int]$Port,
        [string]$Password
    )

    try{

        $Client = New-Object System.Net.Sockets.TcpClient
        $Client.ReceiveTimeout = 3000
        $Client.SendTimeout = 3000
        $Client.Connect($HostName, $Port)

        $Stream = $Client.GetStream()

        Send-RconPacket -Stream $Stream -Type 3 -Payload $Password -RequestId 1 | Out-Null

        $Response = Read-RconPacket -Stream $Stream

        if(!$Response -or $Response.RequestId -eq -1){
            $Client.Close()
            return $null
        }

        return @{ Client = $Client; Stream = $Stream }

    }
    catch{
        Write-Log "Falha ao conectar via RCON: $_"
        return $null
    }

}

function Send-RconCommand {

    param($Session, [string]$Command)

    if(!$Session){ return $null }

    Send-RconPacket -Stream $Session.Stream -Type 2 -Payload $Command -RequestId 2 | Out-Null

    $Response = Read-RconPacket -Stream $Session.Stream

    if($Response){
        return $Response.Payload
    }

    return $null

}

function Disconnect-Rcon {

    param($Session)

    if($Session -and $Session.Client){
        try{ $Session.Client.Close() } catch{}
    }

}

function Invoke-RconCommand {

    param([string]$Command)

    if(!$Config.rconEnabled -or [string]::IsNullOrWhiteSpace($Config.rconPassword)){
        return $null
    }

    $Session = Connect-Rcon -Port $Config.rconPort -Password $Config.rconPassword

    if(!$Session){
        return $null
    }

    $Result = Send-RconCommand -Session $Session -Command $Command

    Disconnect-Rcon $Session

    return $Result

}

function Show-RconMenu {

    if(!$Config.rconEnabled -or [string]::IsNullOrWhiteSpace($Config.rconPassword)){
        Write-WarningText "RCON desativado. Defina 'rconEnabled': true e 'rconPassword' no config.json."
        return
    }

    if(!(Test-ServerRunning)){
        Write-WarningText "O servidor nao esta em execucao (nesta maquina/sessao)."
        return
    }

    Write-Host ""
    Write-Host "------------ CONTROLE REMOTO (RCON) ------------"
    Write-Host " [1] Parar servidor (stop)"
    Write-Host " [2] Reiniciar servidor (stop + start)"
    Write-Host " [3] Salvar mundo agora (save-all)"
    Write-Host " [4] Listar jogadores online (list)"
    Write-Host " [5] Anunciar mensagem (say)"
    Write-Host " [6] Comando livre"
    Write-Host " [0] Voltar"
    Write-Host "---------------------------------------------------"
    Write-Host ""

    $Choice = Read-Host "Escolha uma opcao"

    switch($Choice){

        "1" {
            if(Read-YesNo "Confirma o desligamento do servidor?" $false){
                Stop-MinecraftServer -WarnSeconds 10 | Out-Null
            }
        }

        "2" {
            Restart-MinecraftServer -WarnSeconds 10
        }

        "3" {
            $Result = Invoke-RconCommand "save-all"
            if($Result){ Write-Host $Result } else { Write-Success "Mundo salvo." }
        }

        "4" {
            $Result = Invoke-RconCommand "list"
            if($Result){ Write-Host $Result }
        }

        "5" {

            $Msg = Read-Host "Mensagem para anunciar (ENTER = cancelar)"

            if(![string]::IsNullOrWhiteSpace($Msg)){
                Invoke-RconCommand "say $Msg" | Out-Null
                Write-Success "Mensagem enviada."
            }

        }

        "6" {

            $Command = Read-Host "Comando para enviar ao servidor (ENTER = voltar)"

            if(![string]::IsNullOrWhiteSpace($Command)){

                $Result = Invoke-RconCommand $Command

                if($null -eq $Result){
                    Write-ErrorText "Falha ao enviar comando via RCON."
                }
                else{
                    Write-Host ""
                    Write-Host $Result
                    Write-Log "RCON> $Command => $Result"
                }

            }

        }

    }

}
