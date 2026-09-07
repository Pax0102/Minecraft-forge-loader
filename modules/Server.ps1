function Ensure-Eula {

    $Path = Join-Path $PSScriptRoot "..\server\eula.txt"

    if(Test-Path $Path){

        $Content = Get-Content $Path -Raw -ErrorAction SilentlyContinue

        if($Content -match "eula\s*=\s*true"){
            return $true
        }

    }

    Write-Host ""
    Write-WarningText "E necessario aceitar o EULA da Mojang para iniciar o servidor."
    Write-Host "Leia em: https://aka.ms/MinecraftEULA"
    Write-Host ""

    if(!(Read-YesNo "Voce concorda com o EULA?" $false)){
        Write-ErrorText "EULA nao aceito. O servidor nao pode ser iniciado."
        Write-Log "EULA recusado pelo usuario."
        return $false
    }

    "eula=true" | Set-Content -Path $Path -Encoding ASCII

    Write-Success "EULA aceito e salvo."
    Write-Log "EULA aceito pelo usuario."

    return $true

}

function Get-ServerPidPath {

    return (Join-Path $PSScriptRoot "..\server\.running.pid")

}

function Test-ServerRunning {

    $PidPath = Get-ServerPidPath

    if(!(Test-Path $PidPath)){
        return $false
    }

    $Id = Get-Content $PidPath -ErrorAction SilentlyContinue

    if(!$Id){
        return $false
    }

    return [bool](Get-Process -Id $Id -ErrorAction SilentlyContinue)

}

function Show-ServerLog {

    param([int]$Lines = 40)

    $LogPath = Join-Path $PSScriptRoot "..\server\logs\latest.log"

    if(!(Test-Path $LogPath)){
        Write-WarningText "Nenhum log encontrado ainda. Inicie o servidor primeiro."
        return
    }

    Write-Host ""
    Write-Host "-------- Ultimas $Lines linhas (latest.log) --------"
    Get-Content $LogPath -Tail $Lines
    Write-Host "------------------------------------------------------"

}

function Get-SafeArgsFile {

    param([string]$OriginalPath)

    if([string]::IsNullOrWhiteSpace($OriginalPath) -or !(Test-Path $OriginalPath)){
        return $OriginalPath
    }

    try{

        $Bytes = [System.IO.File]::ReadAllBytes($OriginalPath)

        $HasBom = $Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF

        if(!$HasBom){
            return $OriginalPath
        }

        # Um BOM UTF-8 no inicio do arquivo de argumentos "gruda" no primeiro
        # parametro e quebra o parser do Java (@arquivo), entao geramos uma
        # copia limpa e usamos ela para iniciar o servidor.
        Write-Log "BOM detectado em '$OriginalPath'. Gerando copia sem BOM para o launch."

        $CleanBytes = $Bytes[3..($Bytes.Length - 1)]
        $SafePath = Join-Path (Split-Path $OriginalPath -Parent) "win_args.clean.txt"

        [System.IO.File]::WriteAllBytes($SafePath, $CleanBytes)

        return $SafePath

    }
    catch{
        Write-Log "Falha ao higienizar arquivo de argumentos '$OriginalPath': $_"
        return $OriginalPath
    }

}

function Start-MinecraftServer {

    $ServerDir = Join-Path $PSScriptRoot "..\server"
    $Forge = Get-ForgeInfo

    if(!$Forge.Installed){
        Write-ErrorText "Forge nao encontrado. Instale o Forge primeiro."
        return
    }

    $Java = Get-WorkingJava $Forge.MinecraftVersion

    if(!$Java.Installed){
        Write-ErrorText "Nao foi possivel obter um Java compativel para iniciar o servidor (mesmo apos tentar baixar automaticamente)."
        return
    }

    if(!(Ensure-Eula)){
        return
    }

    $Ram = $Config.ram
    if(!$Ram -or $Ram -le 0){ $Ram = 4 }

    $MaxAttempts = if($Config.autoRestart){ [Math]::Max(1, $Config.maxRestartAttempts) } else { 1 }
    $BackupIntervalMin = $Config.liveBackupIntervalMinutes
    $PidPath = Get-ServerPidPath
    $Attempt = 0

    $ArgsFile = if($Forge.LaunchMode -eq "modern"){ Get-SafeArgsFile $Forge.ArgsFile } else { $null }

    Sync-RconSettings

    Push-Location $ServerDir

    try{

        while($Attempt -lt $MaxAttempts){

            $Attempt++

            Write-Host ""
            Write-Info "Iniciando servidor com ${Ram}GB de RAM... (tentativa $Attempt/$MaxAttempts)"
            Write-Log "Iniciando servidor (RAM=${Ram}GB, tentativa $Attempt, java=$($Java.Path))"
            Send-DiscordNotification -Title "Servidor iniciando" -Message "Tentativa $Attempt/$MaxAttempts"

            if($Forge.LaunchMode -eq "modern"){

                # Forge 1.17+ nao gera mais um jar unico: a classpath fica em um
                # arquivo de argumentos (@win_args.txt) gerado pelo instalador.
                $Process = Start-Process -FilePath $Java.Path `
                    -ArgumentList "-Xms${Ram}G", "-Xmx${Ram}G", "@$ArgsFile", "nogui" `
                    -NoNewWindow -PassThru

            }
            else{

                $JarName = Split-Path $Forge.ServerJar -Leaf

                $Process = Start-Process -FilePath $Java.Path `
                    -ArgumentList "-Xms${Ram}G", "-Xmx${Ram}G", "-jar", $JarName, "nogui" `
                    -NoNewWindow -PassThru

            }

            $Process.Id | Set-Content -Path $PidPath -Encoding ASCII

            $LastBackup = Get-Date

            while(!$Process.HasExited){

                Start-Sleep -Seconds 5

                if($BackupIntervalMin -gt 0 -and ((Get-Date) - $LastBackup).TotalMinutes -ge $BackupIntervalMin){
                    Write-Host ""
                    Write-Info "Executando backup automatico periodico..."
                    New-Backup "auto" | Out-Null
                    $LastBackup = Get-Date
                }

            }

            Remove-Item $PidPath -Force -ErrorAction SilentlyContinue

            Write-Host ""

            if($Process.ExitCode -eq 0){
                Write-Info "Servidor encerrado normalmente."
                Write-Log "Servidor encerrado normalmente (exit 0)."
                Send-DiscordNotification -Title "Servidor parado" -Message "Encerrado normalmente."
                break
            }

            Write-WarningText "Servidor encerrou com codigo $($Process.ExitCode)."
            Write-Log "Servidor encerrou com erro (exit $($Process.ExitCode))."
            Send-DiscordNotification -Title "Servidor caiu" -Message "Codigo $($Process.ExitCode) (tentativa $Attempt/$MaxAttempts)"

            if(!$Config.autoRestart -or $Attempt -ge $MaxAttempts){
                break
            }

            Write-Info "Reiniciando em 5 segundos..."
            Start-Sleep -Seconds 5

        }

    }
    finally{
        Pop-Location
        Remove-Item $PidPath -Force -ErrorAction SilentlyContinue
    }

}

function Stop-MinecraftServer {

    param([int]$WarnSeconds = 10)

    if(!(Test-ServerRunning)){
        Write-WarningText "O servidor nao esta em execucao."
        return $false
    }

    if(!$Config.rconEnabled -or [string]::IsNullOrWhiteSpace($Config.rconPassword)){
        Write-WarningText "RCON desativado: nao e possivel desligar remotamente. Digite 'stop' no console do servidor, ou ative o RCON no config.json."
        return $false
    }

    if($WarnSeconds -gt 0){
        Invoke-RconCommand "say Servidor sera desligado em $WarnSeconds segundos..." | Out-Null
        Start-Sleep -Seconds $WarnSeconds
    }

    Write-Info "Salvando o mundo e desligando..."

    Invoke-RconCommand "save-all" | Out-Null
    Invoke-RconCommand "stop" | Out-Null

    $Id = Get-Content (Get-ServerPidPath) -ErrorAction SilentlyContinue
    $Timeout = 60
    $Waited = 0

    while($Id -and (Get-Process -Id $Id -ErrorAction SilentlyContinue) -and $Waited -lt $Timeout){
        Start-Sleep -Seconds 2
        $Waited += 2
    }

    Write-Success "Servidor desligado."
    Write-Log "Servidor desligado remotamente via RCON (stop)."
    Send-DiscordNotification -Title "Servidor parado" -Message "Desligado manualmente via RCON."

    return $true

}

function Restart-MinecraftServer {

    param([int]$WarnSeconds = 10)

    if(!(Test-ServerRunning)){
        Write-WarningText "O servidor nao esta em execucao. Use a opcao [1] do menu para inicia-lo."
        return
    }

    Write-WarningText "Isso ira parar e reiniciar o servidor. Os jogadores serao avisados com $WarnSeconds segundos de antecedencia."

    if(!(Read-YesNo "Confirma o reinicio?" $false)){
        Write-Info "Cancelado."
        return
    }

    if(!(Stop-MinecraftServer -WarnSeconds $WarnSeconds)){
        return
    }

    Write-Info "Reiniciando o servidor..."
    Write-Log "Reinicio remoto solicitado pelo usuario."

    Start-MinecraftServer

}
