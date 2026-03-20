Set-StrictMode -Version Latest

function Get-DeepCoolDigitalDevices {
    [CmdletBinding()]
    param()

    $devices = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FriendlyName -match "DeepCool|DIGITAL|AK400" -or
            $_.InstanceId -match "VID_3633"
        } |
        Select-Object Status, Class, FriendlyName, InstanceId

    return @($devices)
}

function Test-DeepCoolDigitalDetected {
    [CmdletBinding()]
    param()

    return (Get-DeepCoolDigitalDevices).Count -gt 0
}

function Install-DeepCoolDigitalSoftware {
    [CmdletBinding()]
    param()

    $downloadUrl = "https://www.deepcool.com/download/DeepCool_DIGITAL_Setup.zip"
    $downloadsDirectory = Join-Path (Get-FirstSetupRoot) "Downloads"
    $extractDirectory = Join-Path $downloadsDirectory "DeepCool-DIGITAL"

    if (-not (Test-Path $downloadsDirectory)) {
        New-Item -Path $downloadsDirectory -ItemType Directory | Out-Null
    }

    if (-not (Test-Path $extractDirectory)) {
        New-Item -Path $extractDirectory -ItemType Directory | Out-Null
    }

    $archivePath = Join-Path $downloadsDirectory "DeepCool-DIGITAL-Setup.zip"

    Invoke-LoggedAction -Name "Скачать официальный DeepCool DIGITAL Setup" -Action {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath
    }

    Invoke-LoggedAction -Name "Распаковать DeepCool DIGITAL Setup" -Action {
        Expand-Archive -Path $archivePath -DestinationPath $extractDirectory -Force
    }

    $installer = Get-ChildItem -Path $extractDirectory -Recurse -Include *.exe | Select-Object -First 1
    if (-not $installer) {
        throw "Не найден исполняемый файл установщика DeepCool DIGITAL в архиве."
    }

    Write-Log "Запускаю установщик DeepCool DIGITAL: $($installer.FullName)"
    Start-Process -FilePath $installer.FullName
}

function Invoke-DeepCoolDigitalDiagnostics {
    [CmdletBinding()]
    param()

    Write-Section "DeepCool DIGITAL Diagnostics"

    $devices = Get-DeepCoolDigitalDevices

    if ($devices.Count -gt 0) {
        Write-Log "Устройство DeepCool DIGITAL обнаружено:"
        $devices | Format-Table -AutoSize | Out-Host
        Write-Log "Если дисплей все еще не работает, проблема вероятнее в софте или конфликте USB enumeration."
        return
    }

    Write-Log "Windows не видит устройство DeepCool DIGITAL / AK400 DIGITAL." "WARN"
    Write-Log "По официальной странице AK400 DIGITAL дисплей управляется приложением и требует подключение к открытому USB 2.0 header." "WARN"
    Write-Log "Проверьте физически: 9-pin USB 2.0 кабель от кулера должен быть подключен в F_USB на материнской плате, а ARGB - в 5V 3-pin ARGB header, не в 12V RGB." "WARN"
    Write-Log "Если кулер охлаждает, но не работает именно экран, драйверы Windows обычно не при чем: устройство просто не доходит до шины USB." "WARN"
}

Export-ModuleMember -Function @(
    "Get-DeepCoolDigitalDevices",
    "Install-DeepCoolDigitalSoftware",
    "Invoke-DeepCoolDigitalDiagnostics",
    "Test-DeepCoolDigitalDetected"
)
