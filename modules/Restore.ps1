function Restore-Backup {

    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupPath,
        [bool]$BackupCurrentFirst = $true
    )

    if(!(Test-Path $BackupPath)){
        Write-ErrorText "Backup nao encontrado: $BackupPath"
        return $false
    }

    # Remove-Item -Recurse no ServerDir enquanto o processo do Java ainda
    # tem arquivos abertos (mundo, logs, jar) pode falhar por arquivos
    # travados ou deixar o servidor num estado inconsistente. Bloqueia a
    # restauracao ate o servidor ser parado.
    if(Test-ServerRunning){
        Write-ErrorText "O servidor esta em execucao. Pare-o (opcao [8] > [1]) antes de restaurar um backup."
        Write-Log "Restauracao abortada: servidor em execucao."
        return $false
    }

    $Root = Join-Path $PSScriptRoot ".."
    $ServerDir = Join-Path $Root "server"

    if($BackupCurrentFirst){
        Write-Info "Salvando estado atual antes de restaurar..."
        New-Backup "pre_restore" | Out-Null
    }

    Write-Info "Restaurando backup: $(Split-Path $BackupPath -Leaf)..."

    try{

        if(Test-Path $ServerDir){
            Remove-Item $ServerDir -Recurse -Force
        }

        New-Item -ItemType Directory -Path $ServerDir | Out-Null

        Expand-Archive -Path $BackupPath -DestinationPath $ServerDir -Force

    }
    catch{
        Write-ErrorText "Falha ao restaurar backup: $_"
        Write-Log "Falha ao restaurar backup ($BackupPath): $_"
        return $false
    }

    Write-Success "Backup restaurado com sucesso."
    Write-Log "Backup restaurado: $(Split-Path $BackupPath -Leaf)"

    return $true

}

function Invoke-AutoRestore {

    param(
        [string]$BackupPath
    )

    if([string]::IsNullOrWhiteSpace($BackupPath) -or !(Test-Path $BackupPath)){
        Write-WarningText "Nenhum backup disponivel para restauracao automatica."
        Write-Log "Restauracao automatica pulada: sem backup disponivel."
        return $false
    }

    Write-Host ""
    Write-WarningText "Falha detectada durante a atualizacao. Restaurando estado anterior automaticamente..."
    Write-Log "Iniciando restauracao automatica apos falha."

    return Restore-Backup -BackupPath $BackupPath -BackupCurrentFirst $false

}

function Show-RestoreMenu {

    $Backups = Get-BackupList

    if(!$Backups -or $Backups.Count -eq 0){
        Write-WarningText "Nenhum backup disponivel."
        return
    }

    Write-Host ""
    Write-Host "Backups disponiveis:" -ForegroundColor DarkCyan
    Write-Host ""

    for($i = 0; $i -lt $Backups.Count; $i++){
        $B = $Backups[$i]
        Write-Host (" [{0}] {1}   {2}   {3}" -f ($i + 1), $B.Name, (Format-Bytes $B.Length), $B.LastWriteTime)
    }

    Write-Host ""

    $Choice = Read-Host "Escolha o numero do backup para restaurar (ENTER = voltar)"

    if([string]::IsNullOrWhiteSpace($Choice)){
        Write-Info "Voltando ao menu."
        return
    }

    $Index = 0

    if(![int]::TryParse($Choice, [ref]$Index) -or $Index -lt 1 -or $Index -gt $Backups.Count){
        Write-ErrorText "Opcao invalida."
        return
    }

    $Selected = $Backups[$Index - 1]

    if(!(Read-YesNo "Confirma a restauracao de '$($Selected.Name)'? O estado atual sera salvo antes." $false)){
        Write-Info "Restauracao cancelada."
        return
    }

    Restore-Backup -BackupPath $Selected.FullName -BackupCurrentFirst $true | Out-Null

}
