Set-StrictMode -Version Latest

function Set-RegistryValueSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [object]$Value,
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }

    $existingProperty = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -ne $existingProperty) {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -ErrorAction Stop
        return
    }

    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
}

function Try-RegistryValueSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [object]$Value,
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )

    try {
        Set-RegistryValueSafe -Path $Path -Name $Name -Value $Value -Type $Type
        return $true
    }
    catch {
        Write-Log "Не удалось применить реестровый параметр $Path :: $Name. $($_.Exception.Message)" "WARN"
        return $false
    }
}

function Get-TaskbarAlignmentValue {
    [CmdletBinding()]
    param()

    Write-Host "Выберите положение кнопок панели задач:"
    Write-Host "1. Слева"
    Write-Host "2. По центру"

    $choice = Read-Host "Введите номер"
    switch ($choice) {
        "2" { return 1 }
        default { return 0 }
    }
}

function Remove-AppxPackageByPattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    $packages = Get-AppxPackage -AllUsers -Name $Pattern -ErrorAction SilentlyContinue
    foreach ($package in $packages) {
        Write-Log "Удаление Appx package: $($package.Name)"

        try {
            $currentUserPackage = Get-AppxPackage -Name $package.Name -ErrorAction SilentlyContinue | Where-Object { $_.PackageFullName -eq $package.PackageFullName } | Select-Object -First 1
            if ($currentUserPackage) {
                Remove-AppxPackage -Package $currentUserPackage.PackageFullName -ErrorAction Stop
            }
        }
        catch {
            Write-Log "Не удалось удалить пакет $($package.Name) для текущего пользователя: $($_.Exception.Message)" "WARN"
        }

        try {
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
        }
        catch {
            Write-Log "Не удалось удалить пакет $($package.Name) для всех пользователей: $($_.Exception.Message)" "WARN"
        }
    }

    $provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $Pattern }
    foreach ($item in $provisioned) {
        Write-Log "Удаление provisioned package: $($item.DisplayName)"
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $item.PackageName -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Log "Не удалось удалить provisioned package $($item.DisplayName): $($_.Exception.Message)" "WARN"
        }
    }
}

function Invoke-WindowsOptimizationPreset {
    [CmdletBinding()]
    param()

    Write-Section "Оптимизация Windows"

    Invoke-LoggedAction -Name "Показать расширения файлов" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    }

    Invoke-LoggedAction -Name "Показать скрытые файлы" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 1
    }

    Invoke-LoggedAction -Name "Открывать Проводник на 'Этот компьютер'" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1
    }

    Invoke-LoggedAction -Name "Отключить Widgets" -Action {
        [void](Try-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0)
    }

    Invoke-LoggedAction -Name "Отключить Microsoft Teams Chat" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0
    }

    Invoke-LoggedAction -Name "Отключить веб-поиск в Start Menu" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1
    }

    Invoke-LoggedAction -Name "Отключить персонализированные consumer features" -Action {
        Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 0
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0
    }

    Invoke-LoggedAction -Name "Отключить телеметрию на базовом уровне политик" -Action {
        Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
    }

    Invoke-LoggedAction -Name "Отключить Delivery Optimization из интернета" -Action {
        Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 0
    }

    Invoke-LoggedAction -Name "Показывать в Alt+Tab только окно браузера, а не все вкладки" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "MultiTaskingAltTabFilter" -Value 3
    }

    Invoke-LoggedAction -Name "Включить историю буфера обмена Win+V" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Clipboard" -Name "EnableClipboardHistory" -Value 1
    }

    Invoke-LoggedAction -Name "Включить высокий план электропитания" -Action {
        Invoke-NativeCommand -FilePath "powercfg.exe" -ArgumentList @("/S", "SCHEME_MIN")
    }

    Restart-ExplorerShell
}

function Set-ConvenienceLoginPreset {
    [CmdletBinding()]
    param()

    Write-Section "Быстрый вход в систему"

    Invoke-LoggedAction -Name "Отключить экран блокировки" -Action {
        Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoLockScreen" -Value 1
    }

    Invoke-LoggedAction -Name "Отключить требование пароля после сна" -Action {
        Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0E796BDB-100D-47D6-A2D5-F7D2DAA51F51" -Name "DCSettingIndex" -Value 0
        Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0E796BDB-100D-47D6-A2D5-F7D2DAA51F51" -Name "ACSettingIndex" -Value 0
    }

    Invoke-LoggedAction -Name "Полностью отключить UAC" -Action {
        Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0
        Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 0
        Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Value 0
    }

    Write-Log "Для применения отключения UAC и части параметров входа требуется перезагрузка." "WARN"
}

function Disable-FirewallOffNotifications {
    [CmdletBinding()]
    param()

    Write-Section "Отключение уведомлений о Брандмауэре"

    Invoke-LoggedAction -Name "Скрыть уведомления Windows Security" -Action {
        Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Name "DisableNotifications" -Value 1
    }

    foreach ($profile in @("DomainProfile", "PrivateProfile", "PublicProfile", "StandardProfile")) {
        Invoke-LoggedAction -Name "Отключить firewall notifications для профиля $profile" -Action {
            Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\$profile" -Name "DisableNotifications" -Value 1
        }
    }

    Write-Log "Уведомление о выключенном Брандмауэре больше не должно постоянно появляться. Может потребоваться выход из сеанса или перезагрузка." "WARN"
}

function Invoke-GamingOptimizationPreset {
    [CmdletBinding()]
    param()

    Write-Section "Оптимизация Windows под игры"

    Invoke-LoggedAction -Name "Включить Game Mode" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1
    }

    Invoke-LoggedAction -Name "Отключить Game DVR для снижения overhead" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
        Set-RegistryValueSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0
        Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
    }

    Invoke-LoggedAction -Name "Отключить Xbox Game Bar overlay" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\GameBar" -Name "ShowStartupPanel" -Value 0
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AudioCaptureEnabled" -Value 0
    }

    Invoke-LoggedAction -Name "Отключить pointer precision для gaming-профиля" -Action {
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0"
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0"
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0"
    }

    Invoke-LoggedAction -Name "Отключить fullscreen optimization notifications" -Action {
        Set-RegistryValueSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2
        Set-RegistryValueSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1
        Set-RegistryValueSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1
    }

    Invoke-LoggedAction -Name "Включить Hardware Accelerated GPU Scheduling" -Action {
        Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2
    }

    Invoke-LoggedAction -Name "Включить высокий план электропитания" -Action {
        Invoke-NativeCommand -FilePath "powercfg.exe" -ArgumentList @("/S", "SCHEME_MIN")
    }

    Write-Log "Если на системе используется ноутбук, высокий план питания увеличит расход батареи." "WARN"
}

function Set-GamingMousePreset {
    [CmdletBinding()]
    param()

    Write-Section "Настройка мышки"

    Invoke-LoggedAction -Name "Отключить Enhance Pointer Precision" -Action {
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0"
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0"
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0"
    }

    Invoke-LoggedAction -Name "Установить стандартную скорость курсора" -Action {
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSensitivity" -Value "10"
    }

    Invoke-LoggedAction -Name "Установить стандартную прокрутку колесом" -Action {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WheelScrollLines" -Value "3"
    }

    Write-Log "Для применения части параметров может потребоваться выход из сеанса." "WARN"
}

function Disable-OptionalFeatureIfEnabled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureName
    )

    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue

    if (-not $feature) {
        Write-Log "Компонент не найден: $FeatureName" "WARN"
        return
    }

    if ($feature.State -eq "Disabled") {
        Write-Log "Компонент уже отключен: $FeatureName"
        return
    }

    Disable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart | Out-Null
}

function Enable-OptionalFeatureIfAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureName
    )

    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue

    if (-not $feature) {
        Write-Log "Компонент недоступен на этой системе: $FeatureName" "WARN"
        return $false
    }

    if ($feature.State -eq "Enabled") {
        Write-Log "Компонент уже включен: $FeatureName"
        return $true
    }

    Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart | Out-Null
    return $true
}

function Disable-UnneededWindowsComponents {
    [CmdletBinding()]
    param()

    Write-Section "Отключение ненужных компонентов Windows"

    $features = @(
        "FaxServicesClientPackage",
        "Printing-XPSServices-Features",
        "WorkFolders-Client",
        "MicrosoftWindowsPowerShellV2",
        "MicrosoftWindowsPowerShellV2Root"
    )

    foreach ($featureName in $features) {
        Invoke-LoggedAction -Name "Отключить optional-feature $featureName" -Action {
            Disable-OptionalFeatureIfEnabled -FeatureName $featureName
        }
    }

    Write-Log "Список сделан консервативным. Если нужен более агрессивный debloat, лучше вынести его в отдельный профиль." "WARN"
}

function Remove-BloatwareApps {
    [CmdletBinding()]
    param()

    Write-Section "Удаление встроенного мусора Windows"

    $patterns = @(
        "Microsoft.Xbox*",
        "Microsoft.GamingApp",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.549981C3F5F10",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.MixedReality.Portal",
        "Microsoft.People",
        "Microsoft.SkypeApp",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo",
        "Clipchamp.Clipchamp",
        "Microsoft.Todos",
        "Microsoft.BingNews"
    )

    foreach ($pattern in $patterns) {
        Invoke-LoggedAction -Name "Удалить встроенное приложение $pattern" -Action {
            Remove-AppxPackageByPattern -Pattern $pattern
        }
    }
}

function Set-BluetoothPreset {
    [CmdletBinding()]
    param()

    Write-Section "Настройка Bluetooth"

    Invoke-LoggedAction -Name "Перевести Bluetooth Support Service в Automatic" -Action {
        Set-Service -Name "bthserv" -StartupType Automatic
    }

    Invoke-LoggedAction -Name "Запустить Bluetooth Support Service" -Action {
        Start-Service -Name "bthserv"
    }

    Write-Log "Открываю страницу Bluetooth для ручного спаривания устройств."
    Start-Process "ms-settings:bluetooth"
}

function Enable-DeveloperFeatures {
    [CmdletBinding()]
    param()

    Write-Section "Включение WSL / Hyper-V"

    Invoke-LoggedAction -Name "Включить Windows Subsystem for Linux" -Action {
        [void](Enable-OptionalFeatureIfAvailable -FeatureName "Microsoft-Windows-Subsystem-Linux")
    }

    Invoke-LoggedAction -Name "Включить Virtual Machine Platform" -Action {
        [void](Enable-OptionalFeatureIfAvailable -FeatureName "VirtualMachinePlatform")
    }

    Invoke-LoggedAction -Name "Включить Hyper-V" -Action {
        [void](Enable-OptionalFeatureIfAvailable -FeatureName "Microsoft-Hyper-V-All")
    }

    Write-Log "Компоненты включены. После завершения всех шагов рекомендуется перезагрузка." "WARN"
}

function Set-WindowsAppearancePreset {
    [CmdletBinding()]
    param()

    Write-Section "Тема и отображение Windows"

    $taskbarAlignment = Get-TaskbarAlignmentValue

    Invoke-LoggedAction -Name "Включить темную тему приложений" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
    }

    Invoke-LoggedAction -Name "Включить темную тему Windows" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0
    }

    Invoke-LoggedAction -Name "Включить прозрачность" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 1
    }

    Invoke-LoggedAction -Name "Настроить положение кнопок панели задач" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value $taskbarAlignment
    }

    Invoke-LoggedAction -Name "Отключить мини-приложения" -Action {
        [void](Try-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0)
    }

    Invoke-LoggedAction -Name "Включить 'Завершить задачу' в контекстном меню панели задач" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarEndTask" -Value 1
    }

    Invoke-LoggedAction -Name "Отключить snap suggestions" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "SnapAssistFlyoutEnabled" -Value 0
    }

    Invoke-LoggedAction -Name "Отключить рекомендации в Start" -Action {
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_IrisRecommendations" -Value 0
    }

    Restart-ExplorerShell
}

function Set-EdgeDefaultSearchGoogle {
    [CmdletBinding()]
    param()

    Write-Section "Поиск Edge: Google вместо Bing"

    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

    Invoke-LoggedAction -Name "Включить кастомный поисковик Edge" -Action {
        Set-RegistryValueSafe -Path $policyPath -Name "DefaultSearchProviderEnabled" -Value 1
        Set-RegistryValueSafe -Path $policyPath -Name "DefaultBrowserSettingsCampaignEnabled" -Value 0
    }

    Invoke-LoggedAction -Name "Установить Google как поисковик по умолчанию" -Action {
        Set-RegistryValueSafe -Path $policyPath -Name "DefaultSearchProviderName" -Value "Google" -Type ([Microsoft.Win32.RegistryValueKind]::String)
        Set-RegistryValueSafe -Path $policyPath -Name "DefaultSearchProviderKeyword" -Value "google.com" -Type ([Microsoft.Win32.RegistryValueKind]::String)
        Set-RegistryValueSafe -Path $policyPath -Name "DefaultSearchProviderSearchURL" -Value "{google:baseURL}search?q={searchTerms}&{google:RLZ}{google:originalQueryForSuggestion}{google:assistedQueryStats}{google:searchFieldtrialParameter}{google:searchClient}{google:sourceId}ie={inputEncoding}" -Type ([Microsoft.Win32.RegistryValueKind]::String)
        Set-RegistryValueSafe -Path $policyPath -Name "DefaultSearchProviderSuggestURL" -Value "{google:baseURL}complete/search?output=chrome&q={searchTerms}" -Type ([Microsoft.Win32.RegistryValueKind]::String)
    }

    Write-Log "Закройте и откройте Microsoft Edge, чтобы политика применилась."
}

function Restart-ExplorerShell {
    [CmdletBinding()]
    param()

    Invoke-LoggedAction -Name "Перезапустить Explorer" -Action {
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 2
        Start-Process "explorer.exe"
    }
}

Export-ModuleMember -Function @(
    "Disable-FirewallOffNotifications",
    "Enable-DeveloperFeatures",
    "Disable-UnneededWindowsComponents",
    "Invoke-GamingOptimizationPreset",
    "Invoke-WindowsOptimizationPreset",
    "Remove-BloatwareApps",
    "Set-BluetoothPreset",
    "Set-ConvenienceLoginPreset",
    "Set-EdgeDefaultSearchGoogle",
    "Set-GamingMousePreset",
    "Set-WindowsAppearancePreset"
)
