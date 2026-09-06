function New-Backup {

    param(
        [string]$Reason = "manual"
    )

    $Root = Join-Path $PSScriptRoot ".."
    $ServerDir = Join-Path $Root "server"
    $BackupsDir = Join-Path $Root "backups"

    if(!(Test-Path $BackupsDir)){
        New-Item -ItemType Directory -Path $BackupsDir | Out-Null
    }

    if(!(Test-Path $ServerDir) -or ((Get-ChildItem $ServerDir -Force -ErrorAction SilentlyContinue).Count -eq 0)){
        Write-Info "Nada para fazer backup ainda (pasta server vazia)."
        return $null
    }

    $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Name = "backup_${Stamp}_$Reason.zip"
    $Path = Join-Path $BackupsDir $Name

    $Exclude = @()
    if($Config.backupExclude){ $Exclude = $Config.backupExclude }

    $Live = Test-ServerRunning

    if($Live){
        Invoke-RconCommand "save-off" | Out-Null
        Invoke-RconCommand "save-all" | Out-Null
        Start-Sleep -Seconds 1
    }

    Write-Info "Criando backup ($Reason)..."

    try{

        Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        $ZipStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
        $Archive = New-Object System.IO.Compression.ZipArchive($ZipStream, [System.IO.Compression.ZipArchiveMode]::Create)
        $BaseLen = $ServerDir.Length

        Get-ChildItem $ServerDir -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object {

            $Relative = $_.FullName.Substring($BaseLen + 1) -replace '\\', '/'

            $Skip = $false

            foreach($Pattern in $Exclude){
                if($Relative -like "$Pattern*" -or $_.Name -like $Pattern){
                    $Skip = $true
                    break
                }
            }

            if(!$Skip){
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $Archive, $_.FullName, $Relative, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
            }

        }

        $Archive.Dispose()
        $ZipStream.Dispose()

    }
    catch{

        Write-ErrorText "Falha ao criar backup: $_"
        Write-Log "Falha ao criar backup: $_"

        if($Live){ Invoke-RconCommand "save-on" | Out-Null }

        return $null

    }

    if($Live){
        Invoke-RconCommand "save-on" | Out-Null
    }

    $Size = (Get-Item $Path).Length

    Write-Success "Backup criado: $Name ($(Format-Bytes $Size))"
    Write-Log "Backup criado: $Name (motivo: $Reason, tamanho: $(Format-Bytes $Size))"
    Send-DiscordNotification -Title "Backup criado" -Message "$Name ($(Format-Bytes $Size))"

    return $Path

}

function Remove-OldBackups {

    param(
        [int]$Days = 7
    )

    $BackupsDir = Join-Path $PSScriptRoot "..\backups"

    if(!(Test-Path $BackupsDir)){
        return
    }

    $Limit = (Get-Date).AddDays(-$Days)

    $Old = Get-ChildItem $BackupsDir -Filter "*.zip" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $Limit }

    if(!$Old -or $Old.Count -eq 0){
        Write-Info "Nenhum backup com mais de $Days dias."
        return
    }

    foreach($File in $Old){
        Remove-Item $File.FullName -Force -ErrorAction SilentlyContinue
        Write-Log "Backup removido (expirado, > $Days dias): $($File.Name)"
    }

    Write-Success "$($Old.Count) backup(s) antigo(s) removido(s)."

}

function Get-BackupList {

    $BackupsDir = Join-Path $PSScriptRoot "..\backups"

    if(!(Test-Path $BackupsDir)){
        return @()
    }

    return Get-ChildItem $BackupsDir -Filter "*.zip" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

}
