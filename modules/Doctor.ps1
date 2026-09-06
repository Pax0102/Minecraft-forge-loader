function Test-PortFree {

    param([int]$Port)

    try{

        $Listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
        $Listener.Start()
        $Listener.Stop()

        return $true

    }
    catch{
        return $false
    }

}

function Invoke-Diagnostics {

    Write-Host ""
    Write-Host "-------------- DIAGNOSTICO --------------"

    $Java = Get-JavaInfo

    if($Java.Installed){
        Write-Success "Java $($Java.Major) detectado ($($Java.Path))."
    }
    else{
        Write-ErrorText "Java nao encontrado no PATH."
    }

    try{

        $Os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $FreeGb = [Math]::Round($Os.FreePhysicalMemory / 1MB, 1)
        $TotalGb = [Math]::Round($Os.TotalVisibleMemorySize / 1MB, 1)

        if($FreeGb -lt $Config.ram){
            Write-WarningText "RAM livre: ${FreeGb}GB de ${TotalGb}GB (configurado: $($Config.ram)GB - pode faltar memoria)."
        }
        else{
            Write-Success "RAM livre: ${FreeGb}GB de ${TotalGb}GB."
        }

    }
    catch{
        Write-WarningText "Nao foi possivel checar a memoria do sistema."
    }

    try{

        $RootPath = Get-RootPath
        $Drive = (Get-Item $RootPath).PSDrive
        $FreeText = Format-Bytes $Drive.Free

        if($Drive.Free -lt 2GB){
            Write-WarningText "Espaco livre em disco baixo: $FreeText."
        }
        else{
            Write-Success "Espaco livre em disco: $FreeText."
        }

    }
    catch{
        Write-WarningText "Nao foi possivel checar o espaco em disco."
    }

    $Port = 25565
    $Props = Get-ServerProperties

    if($Props.ContainsKey("server-port")){
        $Port = [int]$Props["server-port"]
    }

    if(Test-ServerRunning){
        Write-Success "Servidor em execucao (porta $Port)."
    }
    elseif(Test-PortFree -Port $Port){
        Write-Success "Porta $Port livre."
    }
    else{
        Write-WarningText "Porta $Port ja esta em uso por outro processo."
    }

    if(Test-Internet){
        Write-Success "Conexao com a internet OK."
    }
    else{
        Write-ErrorText "Sem conexao com a internet."
    }

    $EulaPath = Join-Path $PSScriptRoot "..\server\eula.txt"

    if((Test-Path $EulaPath) -and ((Get-Content $EulaPath -Raw -ErrorAction SilentlyContinue) -match "eula\s*=\s*true")){
        Write-Success "EULA aceito."
    }
    else{
        Write-WarningText "EULA ainda nao foi aceito."
    }

    if($Config.rconEnabled -and $Config.rconPassword){
        Write-Success "RCON configurado (porta $($Config.rconPort))."
    }
    else{
        Write-Info "RCON desativado."
    }

    if($Config.discordWebhookUrl){
        Write-Success "Notificacoes Discord ativas."
    }
    else{
        Write-Info "Notificacoes Discord desativadas."
    }

    Write-Host "-------------------------------------------"

}
