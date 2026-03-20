Set-StrictMode -Version Latest

function Repair-WindowsImage {
    [CmdletBinding()]
    param()

    Write-Section "Repair Windows Image"

    Invoke-LoggedAction -Name "DISM ScanHealth" -Action {
        Invoke-NativeCommand -FilePath "DISM.exe" -ArgumentList @("/Online", "/Cleanup-Image", "/ScanHealth")
    }

    Invoke-LoggedAction -Name "DISM RestoreHealth" -Action {
        Invoke-NativeCommand -FilePath "DISM.exe" -ArgumentList @("/Online", "/Cleanup-Image", "/RestoreHealth")
    }

    Invoke-LoggedAction -Name "SFC /SCANNOW" -Action {
        Invoke-NativeCommand -FilePath "sfc.exe" -ArgumentList @("/scannow")
    }
}

function Reset-WindowsUpdateComponents {
    [CmdletBinding()]
    param()

    Write-Section "Reset Windows Update"

    Invoke-LoggedAction -Name "Остановить службы обновления" -Action {
        foreach ($service in @("bits", "wuauserv", "appidsvc", "cryptsvc")) {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        }
    }

    Invoke-LoggedAction -Name "Очистить SoftwareDistribution и catroot2" -Action {
        $softwareDistribution = Join-Path $env:SystemRoot "SoftwareDistribution"
        $catroot2 = Join-Path $env:SystemRoot "System32\catroot2"

        if (Test-Path $softwareDistribution) {
            Remove-Item -Path (Join-Path $softwareDistribution "*") -Recurse -Force -ErrorAction SilentlyContinue
        }

        if (Test-Path $catroot2) {
            Remove-Item -Path $catroot2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Invoke-LoggedAction -Name "Запустить службы обновления" -Action {
        foreach ($service in @("cryptsvc", "appidsvc", "wuauserv", "bits")) {
            Start-Service -Name $service -ErrorAction SilentlyContinue
        }
    }
}

function Reset-NetworkStack {
    [CmdletBinding()]
    param()

    Write-Section "Reset Network Stack"

    Invoke-LoggedAction -Name "Сброс Winsock" -Action {
        Invoke-NativeCommand -FilePath "netsh.exe" -ArgumentList @("winsock", "reset")
    }

    Invoke-LoggedAction -Name "Сброс IP stack" -Action {
        Invoke-NativeCommand -FilePath "netsh.exe" -ArgumentList @("int", "ip", "reset")
    }

    Invoke-LoggedAction -Name "Очистить DNS cache" -Action {
        Invoke-NativeCommand -FilePath "ipconfig.exe" -ArgumentList @("/flushdns")
    }
}

function Invoke-SystemFixesPreset {
    [CmdletBinding()]
    param()

    Repair-WindowsImage
    Reset-WindowsUpdateComponents
    Reset-NetworkStack
}

Export-ModuleMember -Function @(
    "Invoke-SystemFixesPreset",
    "Repair-WindowsImage",
    "Reset-NetworkStack",
    "Reset-WindowsUpdateComponents"
)
