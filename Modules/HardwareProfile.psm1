Set-StrictMode -Version Latest

function Get-HardwareProfile {
    [CmdletBinding()]
    param()

    $computerSystem = Get-CimInstance Win32_ComputerSystem
    $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
    $videoController = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $baseBoard = Get-CimInstance Win32_BaseBoard | Select-Object -First 1
    $memoryModules = @(Get-CimInstance Win32_PhysicalMemory)
    $physicalDisks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
    $netAdapters = @(Get-NetAdapter -ErrorAction SilentlyContinue)
    $battery = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
    $monitors = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue)

    $configuredSpeeds = @($memoryModules | Where-Object { $_.ConfiguredClockSpeed } | ForEach-Object { [int]$_.ConfiguredClockSpeed })
    $memoryConfiguredSpeed = if ($configuredSpeeds.Count -gt 0) { ($configuredSpeeds | Measure-Object -Maximum).Maximum } else { 0 }
    $totalMemoryGb = [math]::Round((($memoryModules | Measure-Object -Property Capacity -Sum).Sum / 1GB), 0)
    $hasNvidiaGpu = $videoController.Name -match "NVIDIA"
    $hasSamsungSsd = ($physicalDisks | Where-Object { $_.FriendlyName -match "Samsung" -and $_.MediaType -eq "SSD" }).Count -gt 0
    $hasBluetooth = ($netAdapters | Where-Object { $_.Name -match "Bluetooth" -or $_.InterfaceDescription -match "Bluetooth" }).Count -gt 0
    $isLaptop = $battery.Count -gt 0 -or $computerSystem.PCSystemType -in 2, 9, 10
    $hasHighResolutionDisplay = $monitors.Count -gt 0

    [pscustomobject]@{
        Manufacturer = $computerSystem.Manufacturer
        Model = $computerSystem.Model
        CpuName = $processor.Name
        GpuName = $videoController.Name
        Motherboard = $baseBoard.Product
        MemoryTotalGb = [int]$totalMemoryGb
        MemoryConfiguredSpeed = $memoryConfiguredSpeed
        HasNvidiaGpu = $hasNvidiaGpu
        HasSamsungSsd = $hasSamsungSsd
        HasBluetooth = $hasBluetooth
        IsLaptop = $isLaptop
        HasHighResolutionDisplay = $hasHighResolutionDisplay
        IsTargetGamingPc = (
            $processor.Name -match "Ryzen 7 5700X" -and
            $videoController.Name -match "RTX 4060" -and
            $baseBoard.Product -match "B550 GAMING X V2"
        )
    }
}

function Test-MemoryNeedsXmp {
    [CmdletBinding()]
    param()

    $profile = Get-HardwareProfile
    return $profile.MemoryConfiguredSpeed -gt 0 -and $profile.MemoryConfiguredSpeed -lt 3000
}

function Show-HardwareRecommendations {
    [CmdletBinding()]
    param()

    $profile = Get-HardwareProfile

    Write-Section "Рекомендации под текущее железо"
    Write-Log "Профиль: CPU=$($profile.CpuName); GPU=$($profile.GpuName); MB=$($profile.Motherboard); RAM=$($profile.MemoryTotalGb)GB @ $($profile.MemoryConfiguredSpeed) MHz"

    if ($profile.IsTargetGamingPc) {
        Write-Log "Обнаружен профиль Ryzen 5700X + RTX 4060 + B550. Используйте JSON-профиль из Config\\Profiles."
    }

    if ($profile.HasSamsungSsd) {
        Write-Log "Обнаружен Samsung SSD. Можно автоматически ставить Samsung Magician."
    }

    if (-not $profile.HasBluetooth) {
        Write-Log "Bluetooth адаптер не найден. Bluetooth-настройки можно автоматически пропускать." "WARN"
    }

    if ($profile.IsLaptop) {
        Write-Log "Обнаружен ноутбук. Для него стоит аккуратнее применять агрессивные power/gaming presets." "WARN"
    }

    if (Test-MemoryNeedsXmp) {
        Write-Log "Память работает на $($profile.MemoryConfiguredSpeed) MHz. Для модулей Kingston KF3733C19D4/16GX это похоже на отключенный XMP/DOCP." "WARN"
    }

    Write-Log "Проверьте BIOS: XMP/DOCP = Enabled, Above 4G Decoding = Enabled, Re-Size BAR = Enabled." "WARN"
    Write-Log "Для RTX 4060 на 1440p используйте Game Ready Driver, G-Sync/Adaptive Sync и NVIDIA Reflex в поддерживаемых играх." "WARN"
}

Export-ModuleMember -Function @(
    "Get-HardwareProfile",
    "Show-HardwareRecommendations",
    "Test-MemoryNeedsXmp"
)
