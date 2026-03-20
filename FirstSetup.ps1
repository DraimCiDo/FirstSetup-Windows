[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$Run,
    [string]$BackupConfigPath,
    [switch]$Backup,
    [switch]$Restore
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module (Join-Path $scriptRoot "Modules\Common.psm1") -Force
Import-Module (Join-Path $scriptRoot "Modules\Installers.psm1") -Force
Import-Module (Join-Path $scriptRoot "Modules\SystemSetup.psm1") -Force
Import-Module (Join-Path $scriptRoot "Modules\Nvidia.psm1") -Force
Import-Module (Join-Path $scriptRoot "Modules\Fixes.psm1") -Force
Import-Module (Join-Path $scriptRoot "Modules\Automation.psm1") -Force
Import-Module (Join-Path $scriptRoot "Modules\HardwareProfile.psm1") -Force
Import-Module (Join-Path $scriptRoot "Modules\Cooling.psm1") -Force
Import-Module (Join-Path $scriptRoot "Modules\Backup.psm1") -Force
Import-Module (Join-Path $scriptRoot "Modules\Storage.psm1") -Force

if (-not (Test-RunningAsAdministrator)) {
    throw "Скрипт нужно запускать из PowerShell от имени администратора."
}
Initialize-FirstSetupEnvironment -RootPath $scriptRoot

function Show-MainMenu {
    Write-Section "FirstSetup Windows"
    Write-Host "1. Автоматически определить ПК и применить нужный профиль"
    Write-Host "2. Выбрать программы из required-профиля"
    Write-Host "3. Выбрать программы из optional-профиля"
    Write-Host "4. Выбрать приложения вручную"
    Write-Host "5. Применить оптимизацию Windows"
    Write-Host "6. Оптимизировать Windows под игры"
    Write-Host "7. Удалить встроенный мусор Windows"
    Write-Host "8. Отключить ненужные компоненты Windows"
    Write-Host "9. Настроить мышку"
    Write-Host "10. Настроить Bluetooth"
    Write-Host "11. Включить WSL / VirtualMachinePlatform / Hyper-V"
    Write-Host "12. Настроить тему и отображение Windows"
    Write-Host "13. Установить NVIDIA App"
    Write-Host "14. Заменить поиск Edge с Bing на Google"
    Write-Host "15. Отключить lock screen / пароль после сна / UAC"
    Write-Host "16. Убрать уведомление о выключенном Брандмауэре"
    Write-Host "17. Запустить системные fixes"
    Write-Host "18. Анализ дисков"
    Write-Host "19. Оптимизация дисков"
    Write-Host "20. Проверка состояния дисков"
    Write-Host "21. Обновить все установленные winget-пакеты"
    Write-Host "22. Экспортировать шаблон конфигурации"
    Write-Host "23. Показать рекомендации под это железо"
    Write-Host "24. Диагностика DeepCool AK400 Digital"
    Write-Host "25. Clean restart DeepCool DIGITAL"
    Write-Host "26. DeepCool DIGITAL stability fix"
    Write-Host "27. Сбросить HID-устройство DeepCool"
    Write-Host "28. Собрать и установить DeepCool Companion"
    Write-Host "29. Запустить DeepCool Companion"
    Write-Host "30. Установить DeepCool DIGITAL Software"
    Write-Host "31. Создать backup по BackupTemplate.json"
    Write-Host "32. Восстановить backup по BackupTemplate.json"
    Write-Host "33. Экспортировать шаблон backup-конфига"
    Write-Host "34. Выполнить полный рекомендуемый сценарий"
    Write-Host "0. Выход"
}

if ($Run) {
    $configuration = Get-HardwareAdaptiveSetupConfiguration -Path $ConfigPath
    Invoke-SetupConfiguration -Configuration $configuration
    return
}

if ($Backup) {
    $resolvedBackupConfigPath = if ($BackupConfigPath) { $BackupConfigPath } else { Get-DefaultBackupConfigPath }
    $backupConfiguration = Get-BackupConfig -Path $resolvedBackupConfigPath
    Invoke-BackupFromConfiguration -Configuration $backupConfiguration
    return
}

if ($Restore) {
    $resolvedBackupConfigPath = if ($BackupConfigPath) { $BackupConfigPath } else { Get-DefaultBackupConfigPath }
    $backupConfiguration = Get-BackupConfig -Path $resolvedBackupConfigPath
    Invoke-RestoreFromConfiguration -Configuration $backupConfiguration
    return
}

do {
    Show-MainMenu
    $choice = Read-Host "Выберите действие"

    switch ($choice) {
        "1" {
            $configuration = Get-HardwareAdaptiveSetupConfiguration
            Invoke-SetupConfiguration -Configuration $configuration
            Wait-ForUser
        }
        "2" {
            Install-AppProfileInteractive -ProfileName "required"
            Wait-ForUser
        }
        "3" {
            Install-AppProfileInteractive -ProfileName "optional"
            Wait-ForUser
        }
        "4" {
            Install-CustomAppSelection
            Wait-ForUser
        }
        "5" {
            Invoke-WindowsOptimizationPreset
            Wait-ForUser
        }
        "6" {
            Invoke-GamingOptimizationPreset
            Wait-ForUser
        }
        "7" {
            Remove-BloatwareApps
            Wait-ForUser
        }
        "8" {
            Disable-UnneededWindowsComponents
            Wait-ForUser
        }
        "9" {
            Set-GamingMousePreset
            Wait-ForUser
        }
        "10" {
            Set-BluetoothPreset
            Wait-ForUser
        }
        "11" {
            Enable-DeveloperFeatures
            Wait-ForUser
        }
        "12" {
            Set-WindowsAppearancePreset
            Wait-ForUser
        }
        "13" {
            Install-NvidiaApp
            Wait-ForUser
        }
        "14" {
            Set-EdgeDefaultSearchGoogle
            Wait-ForUser
        }
        "15" {
            Set-ConvenienceLoginPreset
            Wait-ForUser
        }
        "16" {
            Disable-FirewallOffNotifications
            Wait-ForUser
        }
        "17" {
            Invoke-SystemFixesPreset
            Wait-ForUser
        }
        "18" {
            Show-StorageOverview
            Wait-ForUser
        }
        "19" {
            Invoke-StorageOptimizationPreset
            Wait-ForUser
        }
        "20" {
            Invoke-StorageHealthCheck
            Wait-ForUser
        }
        "21" {
            Update-AllWingetPackages
            Wait-ForUser
        }
        "22" {
            Export-SetupConfigTemplate
            Wait-ForUser
        }
        "23" {
            Show-HardwareRecommendations
            Wait-ForUser
        }
        "24" {
            Invoke-DeepCoolDigitalDiagnostics
            Wait-ForUser
        }
        "25" {
            Restart-DeepCoolDigitalClean
            Wait-ForUser
        }
        "26" {
            Set-DeepCoolDigitalStabilityPreset
            Wait-ForUser
        }
        "27" {
            Reset-DeepCoolDigitalDevice
            Wait-ForUser
        }
        "28" {
            Install-DeepCoolCompanion -LaunchAfterInstall
            Wait-ForUser
        }
        "29" {
            Start-DeepCoolCompanion
            Wait-ForUser
        }
        "30" {
            Install-DeepCoolDigitalSoftware
            Wait-ForUser
        }
        "31" {
            $backupConfiguration = Get-BackupConfig
            Invoke-BackupFromConfiguration -Configuration $backupConfiguration
            Wait-ForUser
        }
        "32" {
            $backupConfiguration = Get-BackupConfig
            Invoke-RestoreFromConfiguration -Configuration $backupConfiguration
            Wait-ForUser
        }
        "33" {
            Export-BackupConfigTemplate
            Wait-ForUser
        }
        "34" {
            $configuration = Get-HardwareAdaptiveSetupConfiguration -Path $ConfigPath
            Invoke-SetupConfiguration -Configuration $configuration
            Wait-ForUser
        }
        "0" {
            Write-Host "Завершение."
        }
        default {
            Write-Warning "Неизвестный пункт меню: $choice"
        }
    }
} until ($choice -eq "0")
