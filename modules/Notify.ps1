function Send-DiscordNotification {

    param(
        [string]$Message,
        [string]$Title = "ServerManager"
    )

    if([string]::IsNullOrWhiteSpace($Config.discordWebhookUrl)){
        return
    }

    try{

        $Body = @{
            embeds = @(@{
                title = $Title
                description = $Message
                color = 3066993
                timestamp = (Get-Date).ToUniversalTime().ToString("o")
            })
        } | ConvertTo-Json -Depth 5

        Invoke-RestMethod -Uri $Config.discordWebhookUrl -Method Post -Body $Body -ContentType "application/json" -TimeoutSec 5 | Out-Null

    }
    catch{
        Write-Log "Falha ao enviar notificacao Discord: $_"
    }

}
