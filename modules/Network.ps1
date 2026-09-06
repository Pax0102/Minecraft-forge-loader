function Test-Internet {

    try{
        $null = Invoke-WebRequest -Uri "https://files.minecraftforge.net" -UseBasicParsing -TimeoutSec 5
        return $true
    }
    catch{
        return $false
    }

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
