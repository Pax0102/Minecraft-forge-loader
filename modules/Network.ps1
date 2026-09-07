function Test-Internet {

    # Testar so contra um host (ex.: files.minecraftforge.net) da falso
    # negativo se esse site especifico estiver fora do ar mas o resto da
    # internet estiver OK. Tenta alguns hosts distintos e so reporta "sem
    # internet" se TODOS falharem.
    $Hosts = @(
        "https://files.minecraftforge.net",
        "https://launchermeta.mojang.com/mc/game/version_manifest.json",
        "https://api.modrinth.com/v2"
    )

    foreach($Url in $Hosts){

        try{
            $null = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
            return $true
        }
        catch{
            # tenta o proximo host
        }

    }

    return $false

}

function Get-JsonParallel {

    param([hashtable]$Urls)

    Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

    $Client = New-Object System.Net.Http.HttpClient
    $Client.Timeout = [TimeSpan]::FromSeconds(8)

    $Tasks = @{}

    foreach($Key in $Urls.Keys){
        $Tasks[$Key] = $Client.GetStringAsync($Urls[$Key])
    }

    try{
        [System.Threading.Tasks.Task]::WaitAll(@($Tasks.Values), 10000) | Out-Null
    }
    catch{
        # Falhas individuais sao tratadas abaixo, por chave
    }

    $Results = @{}

    foreach($Key in $Urls.Keys){

        try{
            $Results[$Key] = $Tasks[$Key].Result | ConvertFrom-Json
        }
        catch{
            Write-Log "Falha na requisicao paralela ($Key): $_"
            $Results[$Key] = $null
        }

    }

    $Client.Dispose()

    return $Results

}

function Invoke-WithRetry {

    param(
        [scriptblock]$Action,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 2
    )

    for($i = 1; $i -le $MaxAttempts; $i++){

        try{
            return & $Action
        }
        catch{

            Write-WarningText "Tentativa $i/$MaxAttempts falhou: $_"
            Write-Log "Tentativa $i/$MaxAttempts falhou: $_"

            if($i -lt $MaxAttempts){
                Start-Sleep -Seconds $DelaySeconds
            }
            else{
                throw
            }

        }

    }

}
