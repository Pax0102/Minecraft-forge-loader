function Write-Log
{
    param(
        [string]$Message
    )

    $date = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

    Add-Content `
        -Path "$PSScriptRoot\..\update.log" `
        -Value "[$date] $Message"
}

function Log-Java {

    param($Java)

    Write-Log "========== JAVA =========="

    Write-Log "Installed : $($Java.Installed)"
    Write-Log "Version   : $($Java.Version)"
    Write-Log "Path      : $($Java.Path)"
    Write-Log "JAVA_HOME : $($Java.Home)"

}

function Log-Forge {

    param($Forge)

    Write-Log ""

    Write-Log "========== FORGE =========="

    Write-Log "Installed : $($Forge.Installed)"

    Write-Log "Versao : $($Forge.Version)"

    Write-Log "Modo : $($Forge.LaunchMode)"

    Write-Log "Jar/Args : $(if($Forge.LaunchMode -eq 'modern'){ $Forge.ArgsFile } else { $Forge.ServerJar })"

}

function Log-Version {

    param(

        $Name,

        $Installed,

        $Latest

    )

    Write-Log ""

    Write-Log "[$Name]"

    Write-Log "Installed : $Installed"

    Write-Log "Latest    : $Latest"

}
