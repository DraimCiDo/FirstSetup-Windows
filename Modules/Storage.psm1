Set-StrictMode -Version Latest

function Get-StorageOverview {
    [CmdletBinding()]
    param()

    $physicalDisks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object FriendlyName, MediaType, BusType, Size, HealthStatus, OperationalStatus)
    $volumes = @(Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -ne $null } | Select-Object DriveLetter, FileSystemLabel, FileSystem, SizeRemaining, Size, HealthStatus)

    [pscustomobject]@{
        PhysicalDisks = $physicalDisks
        Volumes = $volumes
    }
}

function Show-StorageOverview {
    [CmdletBinding()]
    param()

    Write-Section "Анализ дисков"

    $overview = Get-StorageOverview
    Write-Log "Физические диски:"
    $overview.PhysicalDisks | Format-Table -AutoSize | Out-Host

    Write-Log "Тома:"
    $overview.Volumes | Format-Table -AutoSize | Out-Host
}

function Test-TrimEnabled {
    [CmdletBinding()]
    param()

    $output = & fsutil behavior query DisableDeleteNotify 2>$null
    if (-not $output) {
        return $null
    }

    return ($output -match "DisableDeleteNotify = 0")
}

function Invoke-VolumeOptimizationSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [char]$DriveLetter
    )

    $partition = Get-Partition -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
    if (-not $partition) {
        Write-Log "Не найден partition для диска $DriveLetter" "WARN"
        return
    }

    $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction SilentlyContinue
    if (-not $disk) {
        Write-Log "Не найден физический диск для тома $DriveLetter" "WARN"
        return
    }

    $mediaType = $disk.MediaType
    if (-not $mediaType -or $mediaType -eq "Unspecified") {
        $physical = Get-PhysicalDisk | Where-Object { $_.FriendlyName -eq $disk.FriendlyName } | Select-Object -First 1
        if ($physical) {
            $mediaType = $physical.MediaType
        }
    }

    if ($mediaType -eq "SSD") {
        Invoke-LoggedAction -Name "Optimize SSD/NVMe $DriveLetter`: ReTrim" -Action {
            Optimize-Volume -DriveLetter $DriveLetter -ReTrim -Verbose
        }
        return
    }

    Invoke-LoggedAction -Name "Optimize HDD $DriveLetter`: Defrag" -Action {
        Optimize-Volume -DriveLetter $DriveLetter -Defrag -Verbose
    }
}

function Invoke-StorageOptimizationPreset {
    [CmdletBinding()]
    param()

    Write-Section "Оптимизация дисков"

    $trimEnabled = Test-TrimEnabled
    if ($trimEnabled -eq $true) {
        Write-Log "TRIM включен."
    }
    elseif ($trimEnabled -eq $false) {
        Write-Log "TRIM выключен. Для SSD это нежелательно." "WARN"
    }
    else {
        Write-Log "Не удалось определить статус TRIM." "WARN"
    }

    $volumes = @(Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -ne $null -and $_.DriveType -eq "Fixed" })
    foreach ($volume in $volumes) {
        Invoke-VolumeOptimizationSafe -DriveLetter $volume.DriveLetter
    }

    Write-Log "Для Samsung SSD рекомендуется дополнительно использовать Samsung Magician." "WARN"
}

function Invoke-StorageHealthCheck {
    [CmdletBinding()]
    param()

    Write-Section "Проверка состояния дисков"

    $overview = Get-StorageOverview
    $badPhysical = @($overview.PhysicalDisks | Where-Object { $_.HealthStatus -ne "Healthy" -or $_.OperationalStatus -ne "OK" })
    $badVolumes = @($overview.Volumes | Where-Object { $_.HealthStatus -ne "Healthy" })

    if ($badPhysical.Count -eq 0 -and $badVolumes.Count -eq 0) {
        Write-Log "Критичных проблем по статусам дисков и томов не обнаружено."
        return
    }

    if ($badPhysical.Count -gt 0) {
        Write-Log "Есть физические диски с неблагополучным статусом:" "WARN"
        $badPhysical | Format-Table -AutoSize | Out-Host
    }

    if ($badVolumes.Count -gt 0) {
        Write-Log "Есть тома с неблагополучным статусом:" "WARN"
        $badVolumes | Format-Table -AutoSize | Out-Host
    }
}

Export-ModuleMember -Function @(
    "Get-StorageOverview",
    "Invoke-StorageHealthCheck",
    "Invoke-StorageOptimizationPreset",
    "Show-StorageOverview",
    "Test-TrimEnabled"
)
