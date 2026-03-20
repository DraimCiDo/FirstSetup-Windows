Set-StrictMode -Version Latest

$script:FirstSetupRoot = $null
$script:LogFile = $null

function Initialize-FirstSetupEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    $script:FirstSetupRoot = $RootPath
    $logDirectory = Join-Path $RootPath "Logs"

    if (-not (Test-Path $logDirectory)) {
        New-Item -Path $logDirectory -ItemType Directory | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:LogFile = Join-Path $logDirectory "FirstSetup-$timestamp.log"
    Write-Log "Инициализация FirstSetup. Корень: $RootPath"
}

function Get-FirstSetupRoot {
    if (-not $script:FirstSetupRoot) {
        throw "Environment is not initialized. Call Initialize-FirstSetupEnvironment first."
    }

    return $script:FirstSetupRoot
}

function Test-RunningAsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Section {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ""
    Write-Host ("=" * 72) -ForegroundColor DarkGray
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * 72) -ForegroundColor DarkGray
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $line

    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $line
    }
}

function Invoke-LoggedAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    Write-Log "Старт: $Name"

    try {
        & $Action
        Write-Log "Готово: $Name"
    }
    catch {
        Write-Log "Ошибка в '${Name}': $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Invoke-NativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [switch]$IgnoreExitCode
    )

    $displayArgs = if ($ArgumentList.Count -gt 0) { $ArgumentList -join " " } else { "" }
    Write-Log "Команда: $FilePath $displayArgs"

    & $FilePath @ArgumentList
    $exitCode = $LASTEXITCODE

    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        throw "Команда завершилась с кодом ${exitCode}: $FilePath $displayArgs"
    }
}

function Test-MicrosoftStoreInstalled {
    [CmdletBinding()]
    param()

    return $null -ne (Get-AppxPackage -AllUsers -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Ensure-MicrosoftStoreAvailable {
    [CmdletBinding()]
    param()

    if (Test-MicrosoftStoreInstalled) {
        return $true
    }

    Write-Log "Microsoft Store не найден. Пробую восстановление через wsreset -i" "WARN"

    try {
        Invoke-NativeCommand -FilePath "wsreset.exe" -ArgumentList @("-i") -IgnoreExitCode
        Start-Sleep -Seconds 8
    }
    catch {
        Write-Log "Не удалось запустить wsreset -i: $($_.Exception.Message)" "WARN"
    }

    if (Test-MicrosoftStoreInstalled) {
        Write-Log "Microsoft Store обнаружен после wsreset -i"
        return $true
    }

    Write-Log "Microsoft Store по-прежнему не найден." "WARN"
    return $false
}

function Get-WingetCommand {
    [void](Ensure-MicrosoftStoreAvailable)

    $command = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "winget не найден. Установите App Installer из Microsoft Store."
    }

    return $command
}

function Read-NumberSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$MaxNumber,
        [string]$Prompt = "Введите номера через запятую"
    )

    $raw = Read-Host $Prompt

    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    $values = foreach ($item in ($raw -split ",")) {
        $trimmed = $item.Trim()

        if ($trimmed -match "^\d+$") {
            $number = [int]$trimmed
            if ($number -ge 1 -and $number -le $MaxNumber) {
                $number
            }
        }
    }

    return @($values | Sort-Object -Unique)
}

function Wait-ForUser {
    [void](Read-Host "Нажмите Enter для продолжения")
}

function Read-YesNo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        [bool]$DefaultValue = $true
    )

    $suffix = if ($DefaultValue) { "[Y/n]" } else { "[y/N]" }
    $answer = Read-Host "$Prompt $suffix"

    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $DefaultValue
    }

    switch -Regex ($answer.Trim()) {
        "^(y|yes|д|да)$" { return $true }
        "^(n|no|н|нет)$" { return $false }
        default { return $DefaultValue }
    }
}

Export-ModuleMember -Function @(
    "Ensure-MicrosoftStoreAvailable",
    "Get-WingetCommand",
    "Get-FirstSetupRoot",
    "Initialize-FirstSetupEnvironment",
    "Invoke-LoggedAction",
    "Invoke-NativeCommand",
    "Test-RunningAsAdministrator",
    "Test-MicrosoftStoreInstalled",
    "Wait-ForUser",
    "Read-YesNo",
    "Read-NumberSelection",
    "Write-Log",
    "Write-Section"
)
