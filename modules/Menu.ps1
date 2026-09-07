function Show-MainMenu {

    Write-Host ""
    Write-Host "-----------------------------------------"
    Write-Host " [1] Verificar / instalar / atualizar e iniciar servidor"
    Write-Host " [2] Restaurar backup manualmente"
    Write-Host " [3] Limpar temporarios"
    Write-Host " [4] Gerenciar mods"
    Write-Host " [5] Editar server.properties"
    Write-Host " [6] Diagnostico do sistema"
    Write-Host " [7] Ver log do servidor"
    Write-Host " [8] Controle remoto do servidor (parar/reiniciar/RCON)"
    Write-Host " [9] Sair"
    Write-Host " [10] Alterar RAM alocada"
    Write-Host "-----------------------------------------"
    Write-Host ""

    return Read-Host "Escolha uma opcao"

}

function Show-Summary {

    param(
        $Java,
        $Forge,
        [string]$MinecraftVersion
    )

    $ServerDir = Join-Path $PSScriptRoot "..\server"
    $ModsDir = Join-Path $ServerDir "mods"

    $ModsCount = 0

    if(Test-Path $ModsDir){
        $ModsCount = (Get-ChildItem $ModsDir -Filter "*.jar" -ErrorAction SilentlyContinue).Count
    }

    $WorldSize = "0 B"
    $WorldDir = Join-Path $ServerDir "world"

    if(Test-Path $WorldDir){

        $Bytes = (Get-ChildItem $WorldDir -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum

        if($Bytes){
            $WorldSize = Format-Bytes $Bytes
        }

    }

    Write-Host ""
    Write-Host "----------------- RESUMO -----------------"
    Write-Host " Minecraft        : $MinecraftVersion"
    Write-Host " Forge            : $($Forge.Version)"
    Write-Host " Java             : $($Java.Version)"
    Write-Host " RAM configurada  : $($Config.ram) GB"
    Write-Host " Mods instalados  : $ModsCount"
    Write-Host " Tamanho do mundo : $WorldSize"
    Write-Host "-------------------------------------------"

    Write-Log "===== RESUMO ====="
    Write-Log "Minecraft=$MinecraftVersion Forge=$($Forge.Version) Java=$($Java.Version) RAM=$($Config.ram)GB Mods=$ModsCount Mundo=$WorldSize"

}
