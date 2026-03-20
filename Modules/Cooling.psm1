Set-StrictMode -Version Latest

function Get-DeepCoolCompanionProjectPath {
    [CmdletBinding()]
    param()

    return (Join-Path (Get-FirstSetupRoot) "Tools\DeepCoolCompanion\DeepCoolCompanion.csproj")
}

function Get-DeepCoolCompanionPublishPath {
    [CmdletBinding()]
    param()

    return (Join-Path (Get-FirstSetupRoot) "Tools\DeepCoolCompanion\publish")
}

function Get-DeepCoolCompanionExecutablePath {
    [CmdletBinding()]
    param()

    return (Join-Path (Get-DeepCoolCompanionPublishPath) "DeepCoolCompanion.exe")
}

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

function Reset-DeepCoolDigitalDevice {
    [CmdletBinding()]
    param()

    $devices = @(Get-DeepCoolDigitalDevices)
    if ($devices.Count -eq 0) {
        throw "Устройство DeepCool DIGITAL не найдено."
    }

    foreach ($device in $devices) {
        Invoke-LoggedAction -Name "Перезапустить устройство $($device.InstanceId)" -Action {
            Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 2
            Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop
        }
    }

    Invoke-LoggedAction -Name "Пересканировать PnP-устройства" -Action {
        Invoke-NativeCommand -FilePath "pnputil.exe" -ArgumentList @("/scan-devices")
    }
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

function Install-DeepCoolCompanion {
    [CmdletBinding()]
    param(
        [switch]$LaunchAfterInstall
    )

    $projectPath = Get-DeepCoolCompanionProjectPath
    if (-not (Test-Path $projectPath)) {
        throw "Не найден проект DeepCool Companion: $projectPath"
    }

    $publishDirectory = Get-DeepCoolCompanionPublishPath
    if (-not (Test-Path $publishDirectory)) {
        New-Item -Path $publishDirectory -ItemType Directory | Out-Null
    }

    Invoke-LoggedAction -Name "Собрать и опубликовать DeepCool Companion" -Action {
        $command = @(
            "publish",
            $projectPath,
            "-c", "Release",
            "-r", "win-x64",
            "--self-contained", "false",
            "-o", $publishDirectory
        )

        Invoke-NativeCommand -FilePath "dotnet" -ArgumentList $command
    }

    if ($LaunchAfterInstall) {
        Start-DeepCoolCompanion
    }
}

function Start-DeepCoolCompanion {
    [CmdletBinding()]
    param()

    $executablePath = Get-DeepCoolCompanionExecutablePath
    if (-not (Test-Path $executablePath)) {
        Install-DeepCoolCompanion
    }

    Invoke-LoggedAction -Name "Остановить официальный DeepCool DIGITAL перед запуском companion" -Action {
        Get-Process -Name "deepcool-digital" -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }

    Invoke-LoggedAction -Name "Запустить DeepCool Companion" -Action {
        Start-Process -FilePath (Get-DeepCoolCompanionExecutablePath)
    }
}

function Restart-DeepCoolDigitalClean {
    [CmdletBinding()]
    param()

    Write-Section "DeepCool DIGITAL Clean Restart"

    $processes = @(Get-Process -Name "deepcool-digital" -ErrorAction SilentlyContinue)
    foreach ($process in $processes) {
        Invoke-LoggedAction -Name "Остановить процесс deepcool-digital [$($process.Id)]" -Action {
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
        }
    }

    if ($processes.Count -gt 0) {
        Start-Sleep -Seconds 2
    }

    $lockfilePath = Join-Path $env:APPDATA "deepcool-digital\lockfile"
    if (Test-Path $lockfilePath) {
        Invoke-LoggedAction -Name "Удалить lockfile DeepCool DIGITAL" -Action {
            $removed = $false

            for ($attempt = 1; $attempt -le 5; $attempt++) {
                try {
                    Remove-Item -Path $lockfilePath -Force -ErrorAction Stop
                    $removed = $true
                    break
                }
                catch {
                    if ($attempt -eq 5) {
                        throw
                    }

                    Write-Log "lockfile пока занят, повторная попытка $($attempt + 1) из 5" "WARN"
                    Start-Sleep -Seconds 1
                }
            }

            if (-not $removed -and (Test-Path $lockfilePath)) {
                throw "Не удалось удалить lockfile DeepCool DIGITAL."
            }
        }
    }

    $appPath = "C:\Program Files\deepcool-digital\deepcool-digital.exe"
    if (-not (Test-Path $appPath)) {
        throw "Приложение DeepCool DIGITAL не найдено: $appPath"
    }

    Invoke-LoggedAction -Name "Запустить один чистый экземпляр DeepCool DIGITAL" -Action {
        Start-Process -FilePath $appPath
    }

    Write-Log "Если экран снова тухнет после clean restart, проблема почти наверняка в самом приложении DeepCool или в цифровом модуле кулера." "WARN"
}

function Set-DeepCoolDigitalStabilityPreset {
    [CmdletBinding()]
    param()

    Write-Section "DeepCool DIGITAL Stability Fix"

    Invoke-LoggedAction -Name "Отключить USB selective suspend (AC)" -Action {
        & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_USB USBSELECTIVE SUSPEND 0 2>$null
        if ($LASTEXITCODE -ne 0) {
            & powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_USB 2a737441-1930-4402-8d77-b2bebba308a3 0
        }
    }

    Invoke-LoggedAction -Name "Отключить USB selective suspend (DC)" -Action {
        & powercfg.exe /SETDCVALUEINDEX SCHEME_CURRENT SUB_USB USBSELECTIVE SUSPEND 0 2>$null
        if ($LASTEXITCODE -ne 0) {
            & powercfg.exe /SETDCVALUEINDEX SCHEME_CURRENT SUB_USB 2a737441-1930-4402-8d77-b2bebba308a3 0
        }
    }

    Invoke-LoggedAction -Name "Применить текущую схему питания" -Action {
        & powercfg.exe /SETACTIVE SCHEME_CURRENT
        if ($LASTEXITCODE -ne 0) {
            throw "Не удалось повторно активировать текущую схему питания."
        }
    }

    Invoke-LoggedAction -Name "Создать delayed single-instance старт DeepCool DIGITAL" -Action {
        $taskName = "DeepCoolDigitalDelayedStart"
        $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -WindowStyle Hidden -Command "Get-Process deepcool-digital -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 10; Start-Process ''C:\Program Files\deepcool-digital\deepcool-digital.exe''"'
        $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

        Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Force | Out-Null
    }

    Restart-DeepCoolDigitalClean
    Write-Log "Применен stability fix для DeepCool DIGITAL. Если ошибка останется, следующий подозреваемый - физический USB header/шлейф или баг самого приложения." "WARN"
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
    "Install-DeepCoolCompanion",
    "Invoke-DeepCoolDigitalDiagnostics",
    "Reset-DeepCoolDigitalDevice",
    "Restart-DeepCoolDigitalClean",
    "Start-DeepCoolCompanion",
    "Set-DeepCoolDigitalStabilityPreset",
    "Test-DeepCoolDigitalDetected"
)
