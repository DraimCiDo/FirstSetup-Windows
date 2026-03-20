Set-StrictMode -Version Latest

function Get-DefaultBackupConfigPath {
    return Join-Path (Get-FirstSetupRoot) "Config\BackupTemplate.json"
}

function Get-BackupConfig {
    [CmdletBinding()]
    param(
        [string]$Path = (Get-DefaultBackupConfigPath)
    )

    if (-not (Test-Path $Path)) {
        throw "Файл backup-конфига не найден: $Path"
    }

    return Get-Content -Path $Path -Raw | ConvertFrom-Json -Depth 10
}

function Export-BackupConfigTemplate {
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path (Get-FirstSetupRoot) "Config\BackupTemplate.copy.json")
    )

    Copy-Item -Path (Get-DefaultBackupConfigPath) -Destination $Path -Force
    Write-Log "Шаблон backup-конфига сохранен: $Path"
}

function Resolve-BackupPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return [Environment]::ExpandEnvironmentVariables($Path)
}

function Invoke-RobocopyTransfer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$Destination
    )

    if (-not (Test-Path $Source)) {
        Write-Log "Источник не найден, пропускаю: $Source" "WARN"
        return
    }

    if (-not (Test-Path $Destination)) {
        New-Item -Path $Destination -ItemType Directory -Force | Out-Null
    }

    $arguments = @(
        $Source,
        $Destination,
        "/E",
        "/R:1",
        "/W:1",
        "/NFL",
        "/NDL",
        "/NP",
        "/NJH",
        "/NJS"
    )

    Write-Log "Robocopy: $Source -> $Destination"
    $process = Start-Process -FilePath "robocopy.exe" -ArgumentList $arguments -NoNewWindow -PassThru

    try {
        while (-not $process.HasExited) {
            Start-Sleep -Milliseconds 500
            $process.Refresh()
        }
    }
    catch {
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
        throw
    }

    $exitCode = $process.ExitCode

    if ($exitCode -gt 7) {
        throw "Robocopy завершился с ошибкой. Код: $exitCode"
    }
}

function Copy-BackupItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Item,
        [Parameter(Mandatory)]
        [string]$DestinationRoot
    )

    if ($Item.Enabled -eq $false) {
        Write-Log "Элемент отключен в конфиге, пропускаю: $($Item.Name)"
        return
    }

    $sourcePath = Resolve-BackupPath -Path $Item.Source
    $relativeTarget = if ($Item.Target) { $Item.Target } else { $Item.Name }
    $destinationPath = Join-Path $DestinationRoot $relativeTarget

    Invoke-LoggedAction -Name "Backup: $($Item.Name)" -Action {
        Invoke-RobocopyTransfer -Source $sourcePath -Destination $destinationPath
    }
}

function Restore-BackupItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Item,
        [Parameter(Mandatory)]
        [string]$BackupRoot
    )

    if ($Item.Enabled -eq $false) {
        Write-Log "Элемент отключен в конфиге, пропускаю restore: $($Item.Name)"
        return
    }

    $targetPath = Resolve-BackupPath -Path $Item.Source
    $relativeTarget = if ($Item.Target) { $Item.Target } else { $Item.Name }
    $backupPath = Join-Path $BackupRoot $relativeTarget

    Invoke-LoggedAction -Name "Restore: $($Item.Name)" -Action {
        Invoke-RobocopyTransfer -Source $backupPath -Destination $targetPath
    }
}

function Get-EnabledBackupItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    return @($Configuration.Items | Where-Object { $_.Enabled -ne $false })
}

function Save-BackupManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,
        [Parameter(Mandatory)]
        [string]$DestinationRoot
    )

    $manifest = [pscustomobject]@{
        CreatedAt = (Get-Date).ToString("s")
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        DestinationRoot = $DestinationRoot
        Items = @($Configuration.Items | Where-Object { $_.Enabled -ne $false } | ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                Source = $_.Source
                Target = $_.Target
            }
        })
    }

    $manifestPath = Join-Path $DestinationRoot "backup-manifest.json"
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding UTF8
    Write-Log "Manifest сохранен: $manifestPath"
}

function Invoke-BackupFromConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    Write-Section "Создание backup"
    Write-Log "Backup запущен. Для прерывания используйте Ctrl+C; активный robocopy-процесс будет остановлен." "WARN"

    $destinationRoot = Resolve-BackupPath -Path $Configuration.DestinationRoot
    if (-not $destinationRoot) {
        throw "В backup-конфиге не задан DestinationRoot."
    }

    if (-not (Test-Path $destinationRoot)) {
        New-Item -Path $destinationRoot -ItemType Directory -Force | Out-Null
    }

    $items = Get-EnabledBackupItems -Configuration $Configuration
    $total = $items.Count
    $index = 0

    foreach ($item in $items) {
        $index++
        $percent = [int](($index / [math]::Max($total, 1)) * 100)
        Write-Progress -Id 1 -Activity "Создание backup" -Status "$index / $total - $($item.Name)" -PercentComplete $percent
        Copy-BackupItem -Item $item -DestinationRoot $destinationRoot
    }

    Write-Progress -Id 1 -Activity "Создание backup" -Completed

    Save-BackupManifest -Configuration $Configuration -DestinationRoot $destinationRoot
    Write-Log "Backup завершен: $destinationRoot"
}

function Invoke-RestoreFromConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    Write-Section "Восстановление backup"
    Write-Log "Restore запущен. Для прерывания используйте Ctrl+C; активный robocopy-процесс будет остановлен." "WARN"

    $backupRoot = Resolve-BackupPath -Path $Configuration.DestinationRoot
    if (-not (Test-Path $backupRoot)) {
        throw "Папка backup не найдена: $backupRoot"
    }

    $items = Get-EnabledBackupItems -Configuration $Configuration
    $total = $items.Count
    $index = 0

    foreach ($item in $items) {
        $index++
        $percent = [int](($index / [math]::Max($total, 1)) * 100)
        Write-Progress -Id 2 -Activity "Восстановление backup" -Status "$index / $total - $($item.Name)" -PercentComplete $percent
        Restore-BackupItem -Item $item -BackupRoot $backupRoot
    }

    Write-Progress -Id 2 -Activity "Восстановление backup" -Completed

    Write-Log "Восстановление завершено."
}

Export-ModuleMember -Function @(
    "Export-BackupConfigTemplate",
    "Get-BackupConfig",
    "Get-DefaultBackupConfigPath",
    "Invoke-BackupFromConfiguration",
    "Invoke-RestoreFromConfiguration"
)
