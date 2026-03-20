Set-StrictMode -Version Latest

function Test-NvidiaGpuPresent {
    $controllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
    return ($controllers | Where-Object { $_.Name -match "NVIDIA" }).Count -gt 0
}

function Get-NvidiaAppDownloadUrl {
    [CmdletBinding()]
    param()

    $landingPage = "https://www.nvidia.com/en-us/software/nvidia-app/"
    Write-Log "Получаю актуальную ссылку NVIDIA App с официальной страницы: $landingPage"

    $response = Invoke-WebRequest -Uri $landingPage -UseBasicParsing
    $match = [regex]::Match($response.Content, 'https://us\.download\.nvidia\.com/nvapp/client/[^"]+?\.exe')

    if (-not $match.Success) {
        throw "Не удалось извлечь ссылку на установщик NVIDIA App."
    }

    return $match.Value
}

function Install-NvidiaApp {
    [CmdletBinding()]
    param()

    Write-Section "NVIDIA App"

    if (-not (Test-NvidiaGpuPresent)) {
        Write-Log "NVIDIA GPU не обнаружен. Установка пропущена." "WARN"
        return
    }

    $downloadUrl = Get-NvidiaAppDownloadUrl
    $downloadsDirectory = Join-Path (Get-FirstSetupRoot) "Downloads"

    if (-not (Test-Path $downloadsDirectory)) {
        New-Item -Path $downloadsDirectory -ItemType Directory | Out-Null
    }

    $installerPath = Join-Path $downloadsDirectory "NVIDIA-App-Installer.exe"

    Invoke-LoggedAction -Name "Скачать NVIDIA App" -Action {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
    }

    Write-Log "Запускаю установщик NVIDIA App. После установки обновите драйвер внутри приложения."
    Start-Process -FilePath $installerPath
}

Export-ModuleMember -Function @(
    "Get-NvidiaAppDownloadUrl",
    "Install-NvidiaApp",
    "Test-NvidiaGpuPresent"
)
