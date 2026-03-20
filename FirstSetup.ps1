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
    Write-Host "1. Автонастройка"
    Write-Host "2. Приложения"
    Write-Host "3. Настройки Windows"
    Write-Host "4. Оборудование и драйверы"
    Write-Host "5. Обслуживание и диски"
    Write-Host "6. Backup и конфиги"
    Write-Host "0. Выход"
}

function Show-AutoSetupMenu {
    Write-Section "Автонастройка"
    Write-Host "1. Автоматически определить ПК и применить нужный профиль"
    Write-Host "2. Выполнить полный рекомендуемый сценарий"
    Write-Host "0. Назад в главное меню"
}

function Show-ApplicationsMenu {
    Write-Section "Приложения"
    Write-Host "1. Выбрать программы из required-профиля"
    Write-Host "2. Выбрать программы из optional-профиля"
    Write-Host "3. Выбрать приложения вручную"
    Write-Host "4. Обновить все установленные winget-пакеты"
    Write-Host "0. Назад в главное меню"
}

function Show-WindowsMenu {
    Write-Section "Настройки Windows"
    Write-Host "1. Применить оптимизацию Windows"
    Write-Host "2. Оптимизировать Windows под игры"
    Write-Host "3. Удалить встроенный мусор Windows"
    Write-Host "4. Отключить ненужные компоненты Windows"
    Write-Host "5. Настроить мышку"
    Write-Host "6. Настроить Bluetooth"
    Write-Host "7. Включить WSL / VirtualMachinePlatform / Hyper-V"
    Write-Host "8. Настроить тему и отображение Windows"
    Write-Host "9. Заменить поиск Edge с Bing на Google"
    Write-Host "10. Отключить lock screen / пароль после сна / UAC"
    Write-Host "11. Убрать уведомление о выключенном Брандмауэре"
    Write-Host "0. Назад в главное меню"
}

function Show-HardwareMenu {
    Write-Section "Оборудование и драйверы"
    Write-Host "1. Установить NVIDIA App"
    Write-Host "2. Показать рекомендации под это железо"
    Write-Host "3. Диагностика DeepCool AK400 Digital"
    Write-Host "4. Сбросить HID-устройство DeepCool"
    Write-Host "5. Собрать и установить DeepCool Companion"
    Write-Host "6. Запустить DeepCool Companion"
    Write-Host "0. Назад в главное меню"
}

function Show-MaintenanceMenu {
    Write-Section "Обслуживание и диски"
    Write-Host "1. Запустить системные fixes"
    Write-Host "2. Анализ дисков"
    Write-Host "3. Оптимизация дисков"
    Write-Host "4. Проверка состояния дисков"
    Write-Host "0. Назад в главное меню"
}

function Show-BackupConfigMenu {
    Write-Section "Backup и конфиги"
    Write-Host "1. Создать backup по BackupTemplate.json"
    Write-Host "2. Восстановить backup по BackupTemplate.json"
    Write-Host "3. Экспортировать шаблон backup-конфига"
    Write-Host "4. Экспортировать шаблон конфигурации"
    Write-Host "0. Назад в главное меню"
}

function Show-And-Wait {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    & $Action
    Wait-ForUser
}

function Invoke-AutoSetupMenu {
    do {
        Show-AutoSetupMenu
        $choice = Read-Host "Выберите действие"

        switch ($choice) {
            "1" { Show-And-Wait { $configuration = Get-HardwareAdaptiveSetupConfiguration; Invoke-SetupConfiguration -Configuration $configuration } }
            "2" { Show-And-Wait { $configuration = Get-HardwareAdaptiveSetupConfiguration -Path $ConfigPath; Invoke-SetupConfiguration -Configuration $configuration } }
            "0" { }
            default { Write-Warning "Неизвестный пункт меню: $choice" }
        }
    } until ($choice -eq "0")
}

function Invoke-ApplicationsMenu {
    do {
        Show-ApplicationsMenu
        $choice = Read-Host "Выберите действие"

        switch ($choice) {
            "1" { Show-And-Wait { Install-AppProfileInteractive -ProfileName "required" } }
            "2" { Show-And-Wait { Install-AppProfileInteractive -ProfileName "optional" } }
            "3" { Show-And-Wait { Install-CustomAppSelection } }
            "4" { Show-And-Wait { Update-AllWingetPackages } }
            "0" { }
            default { Write-Warning "Неизвестный пункт меню: $choice" }
        }
    } until ($choice -eq "0")
}

function Invoke-WindowsMenu {
    do {
        Show-WindowsMenu
        $choice = Read-Host "Выберите действие"

        switch ($choice) {
            "1" { Show-And-Wait { Invoke-WindowsOptimizationPreset } }
            "2" { Show-And-Wait { Invoke-GamingOptimizationPreset } }
            "3" { Show-And-Wait { Remove-BloatwareApps } }
            "4" { Show-And-Wait { Disable-UnneededWindowsComponents } }
            "5" { Show-And-Wait { Set-GamingMousePreset } }
            "6" { Show-And-Wait { Set-BluetoothPreset } }
            "7" { Show-And-Wait { Enable-DeveloperFeatures } }
            "8" { Show-And-Wait { Set-WindowsAppearancePreset } }
            "9" { Show-And-Wait { Set-EdgeDefaultSearchGoogle } }
            "10" { Show-And-Wait { Set-ConvenienceLoginPreset } }
            "11" { Show-And-Wait { Disable-FirewallOffNotifications } }
            "0" { }
            default { Write-Warning "Неизвестный пункт меню: $choice" }
        }
    } until ($choice -eq "0")
}

function Invoke-HardwareMenu {
    do {
        Show-HardwareMenu
        $choice = Read-Host "Выберите действие"

        switch ($choice) {
            "1" { Show-And-Wait { Install-NvidiaApp } }
            "2" { Show-And-Wait { Show-HardwareRecommendations } }
            "3" { Show-And-Wait { Invoke-DeepCoolDigitalDiagnostics } }
            "4" { Show-And-Wait { Reset-DeepCoolDigitalDevice } }
            "5" { Show-And-Wait { Install-DeepCoolCompanion -LaunchAfterInstall } }
            "6" { Show-And-Wait { Start-DeepCoolCompanion } }
            "0" { }
            default { Write-Warning "Неизвестный пункт меню: $choice" }
        }
    } until ($choice -eq "0")
}

function Invoke-MaintenanceMenu {
    do {
        Show-MaintenanceMenu
        $choice = Read-Host "Выберите действие"

        switch ($choice) {
            "1" { Show-And-Wait { Invoke-SystemFixesPreset } }
            "2" { Show-And-Wait { Show-StorageOverview } }
            "3" { Show-And-Wait { Invoke-StorageOptimizationPreset } }
            "4" { Show-And-Wait { Invoke-StorageHealthCheck } }
            "0" { }
            default { Write-Warning "Неизвестный пункт меню: $choice" }
        }
    } until ($choice -eq "0")
}

function Invoke-BackupConfigMenu {
    do {
        Show-BackupConfigMenu
        $choice = Read-Host "Выберите действие"

        switch ($choice) {
            "1" { Show-And-Wait { $backupConfiguration = Get-BackupConfig; Invoke-BackupFromConfiguration -Configuration $backupConfiguration } }
            "2" { Show-And-Wait { $backupConfiguration = Get-BackupConfig; Invoke-RestoreFromConfiguration -Configuration $backupConfiguration } }
            "3" { Show-And-Wait { Export-BackupConfigTemplate } }
            "4" { Show-And-Wait { Export-SetupConfigTemplate } }
            "0" { }
            default { Write-Warning "Неизвестный пункт меню: $choice" }
        }
    } until ($choice -eq "0")
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
        "1" { Invoke-AutoSetupMenu }
        "2" { Invoke-ApplicationsMenu }
        "3" { Invoke-WindowsMenu }
        "4" { Invoke-HardwareMenu }
        "5" { Invoke-MaintenanceMenu }
        "6" { Invoke-BackupConfigMenu }
        "0" {
            Write-Host "Завершение."
        }
        default {
            Write-Warning "Неизвестный пункт меню: $choice"
        }
    }
} until ($choice -eq "0")
