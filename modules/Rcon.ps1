function Send-RconPacket {

    param($Stream, [int]$Type, [string]$Payload, [int]$RequestId = 1)

    try{

        # UTF8 (nao ASCII): comandos como "say" frequentemente contem
        # acentuacao (pt-BR: "nao", "e", "sera"); ASCII corromperia
        # qualquer caractere fora do intervalo 0-127.
        $PayloadBytes = [System.Text.Encoding]::UTF8.GetBytes($Payload)
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

        # Le exatamente 4 bytes do prefixo de tamanho - Stream.Read pode
        # devolver menos do que o pedido numa unica chamada (TCP nao
        # garante que os bytes cheguem tudo de uma vez), entao precisamos
        # dar loop aqui tambem, nao so no corpo do pacote.
        $LenBytes = New-Object byte[] 4
        $LenRead = 0

        while($LenRead -lt 4){
            $Chunk = $Stream.Read($LenBytes, $LenRead, 4 - $LenRead)
            if($Chunk -le 0){ return $null }
            $LenRead += $Chunk
        }

        $Length = [BitConverter]::ToInt32($LenBytes, 0)

        if($Length -lt 10){
            return $null
        }

        $Body = New-Object byte[] $Length
        $Read = 0

        while($Read -lt $Length){
            $Chunk = $Stream.Read($Body, $Read, $Length - $Read)
            if($Chunk -le 0){ return $null }
            $Read += $Chunk
        }

        $RequestId = [BitConverter]::ToInt32($Body, 0)
        $Type = [BitConverter]::ToInt32($Body, 4)
        $PayloadLength = $Length - 10
        $Payload = ""

        if($PayloadLength -gt 0){
            # UTF8 (nao ASCII): ver comentario em Send-RconPacket.
            $Payload = [System.Text.Encoding]::UTF8.GetString($Body, 8, $PayloadLength)
        }

        return @{ RequestId = $RequestId; Type = $Type; Payload = $Payload }

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

        # O protocolo RCON do Minecraft as vezes manda um SERVERDATA_RESPONSE
        # (Type 0) vazio ANTES do SERVERDATA_AUTH_RESPONSE (Type 2) de
        # verdade. Se lermos so um pacote e assumirmos que e a resposta de
        # auth, podemos pegar esse pacote vazio e reportar falha de login
        # mesmo com senha correta. Por isso lemos ate achar um pacote
        # Type 2 (ou o socket fechar/der timeout).
        $AuthOk = $false

        for($i = 0; $i -lt 3; $i++){

            $Response = Read-RconPacket -Stream $Stream

            if(!$Response){
                break
            }

            if($Response.Type -eq 2){
                $AuthOk = ($Response.RequestId -ne -1)
                break
            }

            # Pacote Type 0 (SERVERDATA_RESPONSE) vazio - ignora e continua
            # esperando o Type 2 de verdade.
        }

        if(!$AuthOk){
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

    $RequestId  = 2
    $EndMarkId  = 3

    Send-RconPacket -Stream $Session.Stream -Type 2 -Payload $Command -RequestId $RequestId | Out-Null

    # Respostas longas (ex.: "list" com muitos jogadores) podem vir
    # fragmentadas em varios pacotes com o mesmo RequestId. Truque padrao
    # do protocolo Source RCON (tambem usado pelo Minecraft): logo em
    # seguida mandamos um segundo pacote "marcador" com um RequestId
    # diferente; quando ele voltar, sabemos que ja lemos tudo do comando
    # anterior e paramos.
    Send-RconPacket -Stream $Session.Stream -Type 2 -Payload "" -RequestId $EndMarkId | Out-Null

    $Payload = ""
    $GotAny  = $false

    for($i = 0; $i -lt 200; $i++){

        $Response = Read-RconPacket -Stream $Session.Stream

        if(!$Response){
            break
        }

        if($Response.RequestId -eq $EndMarkId){
            break
        }

        if($Response.RequestId -eq $RequestId){
            $Payload += $Response.Payload
            $GotAny = $true
        }

    }

    if($GotAny){
        return $Payload
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

    Write-WarningText "Lembrete: rconPassword fica em texto puro no config.json e no server.properties. Nao versione esses arquivos num repositorio publico."

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
