Set-StrictMode -Version Latest

function Get-DefaultSetupConfigPath {
    return Join-Path (Get-FirstSetupRoot) "Config\DefaultSetup.json"
}

function Get-AutoDetectedSetupConfigPath {
    [CmdletBinding()]
    param()

    $hardware = Get-HardwareProfile
    $specificProfilePath = Join-Path (Get-FirstSetupRoot) "Config\Profiles\Ryzen5700X-RTX4060-B550.json"

    if ($hardware.IsTargetGamingPc -and (Test-Path $specificProfilePath)) {
        return $specificProfilePath
    }

    return Get-DefaultSetupConfigPath
}

function Get-SetupConfig {
    [CmdletBinding()]
    param(
        [string]$Path = (Get-DefaultSetupConfigPath)
    )

    if (-not (Test-Path $Path)) {
        throw "Файл конфигурации не найден: $Path"
    }

    return Get-Content -Path $Path -Raw | ConvertFrom-Json -Depth 10
}

function Add-UniqueAppName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$List,
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not $List.Contains($Name)) {
        [void]$List.Add($Name)
    }
}

function Remove-AppNameIfPresent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$List,
        [Parameter(Mandatory)]
        [string]$Name
    )

    [void]$List.Remove($Name)
}

function Get-HardwareAdaptiveSetupConfiguration {
    [CmdletBinding()]
    param(
        [string]$Path
    )

    $resolvedPath = if ($Path) { $Path } else { Get-AutoDetectedSetupConfigPath }
    $configuration = Get-SetupConfig -Path $resolvedPath
    $hardware = Get-HardwareProfile

    $required = [System.Collections.ArrayList]::new()
    foreach ($name in @($configuration.Applications.Required)) { Add-UniqueAppName -List $required -Name $name }

    $optional = [System.Collections.ArrayList]::new()
    foreach ($name in @($configuration.Applications.Optional)) { Add-UniqueAppName -List $optional -Name $name }

    if ($hardware.HasSamsungSsd) {
        Add-UniqueAppName -List $optional -Name "Samsung Magician"
    }
    else {
        Remove-AppNameIfPresent -List $optional -Name "Samsung Magician"
    }

    if (-not $hardware.HasNvidiaGpu) {
        $configuration.Actions.InstallNvidiaApp = $false
    }

    if (-not $hardware.HasBluetooth) {
        $configuration.Actions.ConfigureBluetooth = $false
    }

    if ($hardware.IsLaptop) {
        $configuration.Actions.GamingOptimization = $false
    }

    $configuration.Applications.Required = @($required)
    $configuration.Applications.Optional = @($optional)

    Add-Member -InputObject $configuration -NotePropertyName "_ResolvedConfigPath" -NotePropertyValue $resolvedPath -Force
    Add-Member -InputObject $configuration -NotePropertyName "_DetectedHardwareProfile" -NotePropertyValue $hardware -Force

    return $configuration
}

function Export-SetupConfigTemplate {
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path (Get-FirstSetupRoot) "Config\SetupTemplate.json")
    )

    Copy-Item -Path (Get-DefaultSetupConfigPath) -Destination $Path -Force
    Write-Log "Шаблон конфигурации сохранен: $Path"
}

function Invoke-SetupConfiguration {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory)]
    [pscustomobject]$Configuration
    )

    Write-Section "Автоматическое применение конфигурации"

    if ($Configuration.PSObject.Properties.Name -contains "_ResolvedConfigPath") {
        Write-Log "Используется конфиг: $($Configuration._ResolvedConfigPath)"
    }

    if ($Configuration.PSObject.Properties.Name -contains "_DetectedHardwareProfile") {
        $hardware = $Configuration._DetectedHardwareProfile
        Write-Log "Auto-detect: NVIDIA=$($hardware.HasNvidiaGpu); SamsungSSD=$($hardware.HasSamsungSsd); Bluetooth=$($hardware.HasBluetooth); Laptop=$($hardware.IsLaptop)"
    }

    if ($Configuration.Actions.ShowHardwareRecommendations) {
        Show-HardwareRecommendations
    }

    if ($Configuration.Applications.UpdateAllBeforeInstall) {
        Update-AllWingetPackages
    }

    $appNames = @()
    foreach ($name in @($Configuration.Applications.Required)) { $appNames += $name }
    foreach ($name in @($Configuration.Applications.Optional)) { $appNames += $name }

    if ($appNames.Count -gt 0) {
        Install-AppNames -Names ($appNames | Sort-Object -Unique)
    }

    if ($Configuration.Actions.WindowsOptimization) { Invoke-WindowsOptimizationPreset }
    if ($Configuration.Actions.GamingOptimization) { Invoke-GamingOptimizationPreset }
    if ($Configuration.Actions.RemoveBloatware) { Remove-BloatwareApps }
    if ($Configuration.Actions.DisableUnusedWindowsFeatures) { Disable-UnneededWindowsComponents }
    if ($Configuration.Actions.ConfigureMouse) { Set-GamingMousePreset }
    if ($Configuration.Actions.ConfigureBluetooth) { Set-BluetoothPreset }
    if ($Configuration.Actions.EnableDeveloperFeatures) { Enable-DeveloperFeatures }
    if ($Configuration.Actions.ConfigureAppearance) { Set-WindowsAppearancePreset }
    if ($Configuration.Actions.ConfigureEdgeGoogleSearch) { Set-EdgeDefaultSearchGoogle }
    if ($Configuration.Actions.InstallNvidiaApp) { Install-NvidiaApp }
    if ($Configuration.Actions.RunSystemFixes) { Invoke-SystemFixesPreset }

    Write-Log "Применение конфигурации завершено. Перезагрузите ПК, если включались optional features или выполнялись network/update resets." "WARN"
}

Export-ModuleMember -Function @(
    "Export-SetupConfigTemplate",
    "Get-AutoDetectedSetupConfigPath",
    "Get-HardwareAdaptiveSetupConfiguration",
    "Get-DefaultSetupConfigPath",
    "Get-SetupConfig",
    "Invoke-SetupConfiguration"
)
