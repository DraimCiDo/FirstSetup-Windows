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

Assert-RunningAsAdministrator
Initialize-FirstSetupEnvironment -RootPath $scriptRoot

function Show-MainMenu {
    Write-Section "FirstSetup Windows"
    Write-Host "1. Автоматически определить ПК и применить нужный профиль"
    Write-Host "2. Установить основной набор приложений"
    Write-Host "3. Установить optional-приложения"
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
    Write-Host "15. Запустить системные fixes"
    Write-Host "16. Обновить все установленные winget-пакеты"
    Write-Host "17. Экспортировать шаблон конфигурации"
    Write-Host "18. Показать рекомендации под это железо"
    Write-Host "19. Диагностика DeepCool AK400 Digital"
    Write-Host "20. Установить DeepCool DIGITAL Software"
    Write-Host "21. Создать backup по BackupTemplate.json"
    Write-Host "22. Восстановить backup по BackupTemplate.json"
    Write-Host "23. Экспортировать шаблон backup-конфига"
    Write-Host "24. Выполнить полный рекомендуемый сценарий"
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
            Pause-ForUser
        }
        "2" {
            Install-AppProfile -ProfileName "required"
            Pause-ForUser
        }
        "3" {
            Install-AppProfile -ProfileName "optional"
            Pause-ForUser
        }
        "4" {
            Install-CustomAppSelection
            Pause-ForUser
        }
        "5" {
            Invoke-WindowsOptimizationPreset
            Pause-ForUser
        }
        "6" {
            Invoke-GamingOptimizationPreset
            Pause-ForUser
        }
        "7" {
            Remove-BloatwareApps
            Pause-ForUser
        }
        "8" {
            Disable-UnneededWindowsComponents
            Pause-ForUser
        }
        "9" {
            Set-GamingMousePreset
            Pause-ForUser
        }
        "10" {
            Set-BluetoothPreset
            Pause-ForUser
        }
        "11" {
            Enable-DeveloperFeatures
            Pause-ForUser
        }
        "12" {
            Set-WindowsAppearancePreset
            Pause-ForUser
        }
        "13" {
            Install-NvidiaApp
            Pause-ForUser
        }
        "14" {
            Set-EdgeDefaultSearchGoogle
            Pause-ForUser
        }
        "15" {
            Invoke-SystemFixesPreset
            Pause-ForUser
        }
        "16" {
            Update-AllWingetPackages
            Pause-ForUser
        }
        "17" {
            Export-SetupConfigTemplate
            Pause-ForUser
        }
        "18" {
            Show-HardwareRecommendations
            Pause-ForUser
        }
        "19" {
            Invoke-DeepCoolDigitalDiagnostics
            Pause-ForUser
        }
        "20" {
            Install-DeepCoolDigitalSoftware
            Pause-ForUser
        }
        "21" {
            $backupConfiguration = Get-BackupConfig
            Invoke-BackupFromConfiguration -Configuration $backupConfiguration
            Pause-ForUser
        }
        "22" {
            $backupConfiguration = Get-BackupConfig
            Invoke-RestoreFromConfiguration -Configuration $backupConfiguration
            Pause-ForUser
        }
        "23" {
            Export-BackupConfigTemplate
            Pause-ForUser
        }
        "24" {
            $configuration = Get-HardwareAdaptiveSetupConfiguration -Path $ConfigPath
            Invoke-SetupConfiguration -Configuration $configuration
            Pause-ForUser
        }
        "0" {
            Write-Host "Завершение."
        }
        default {
            Write-Warning "Неизвестный пункт меню: $choice"
        }
    }
} until ($choice -eq "0")
