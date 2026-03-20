Set-StrictMode -Version Latest

function Get-WingetInstallArgumentSets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Package
    )

    $source = if ($Package.PSObject.Properties.Name -contains "Source" -and $Package.Source) { $Package.Source } else { "winget" }

    $baseArguments = @(
        "install",
        "--id", $Package.Id,
        "--exact",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity"
    )

    $argumentSets = @()

    $primary = @($baseArguments)
    if ($source) {
        $primary += @("--source", $source)
    }
    if ($Package.Scope) {
        $primary += @("--scope", $Package.Scope)
    }
    $argumentSets += ,$primary

    if ($Package.Scope) {
        $withoutScope = @($baseArguments)
        if ($source) {
            $withoutScope += @("--source", $source)
        }
        $argumentSets += ,$withoutScope
    }

    if ($source -eq "winget") {
        $withoutSource = @($baseArguments)
        if ($Package.Scope) {
            $withoutSource += @("--scope", $Package.Scope)
        }
        $argumentSets += ,$withoutSource

        $withoutSourceAndScope = @($baseArguments)
        $argumentSets += ,$withoutSourceAndScope
    }

    return $argumentSets
}

function Get-AppCatalog {
    $catalogPath = Join-Path (Get-FirstSetupRoot) "Config\AppCatalog.json"
    return Get-Content -Path $catalogPath -Raw | ConvertFrom-Json
}

function Get-AllCatalogPackages {
    $catalog = Get-AppCatalog
    return @($catalog.required) + @($catalog.optional)
}

function Get-AppPackageByName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $packages = Get-AllCatalogPackages
    $package = $packages | Where-Object { $_.Name -eq $Name -or $_.Id -eq $Name } | Select-Object -First 1

    if (-not $package) {
        throw "Пакет не найден в каталоге: $Name"
    }

    return $package
}

function Install-WingetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Package
    )

    [void](Get-WingetCommand)

    $listOutput = & winget list --id $Package.Id --exact --accept-source-agreements --disable-interactivity 2>$null
    if ($LASTEXITCODE -eq 0 -and $listOutput -match [regex]::Escape($Package.Id)) {
        Write-Log "Пакет уже установлен, пропускаю: $($Package.Name)"
        return
    }

    Invoke-LoggedAction -Name "Установка $($Package.Name)" -Action {
        $argumentSets = Get-WingetInstallArgumentSets -Package $Package
        $lastError = $null

        foreach ($arguments in $argumentSets) {
            try {
                Invoke-NativeCommand -FilePath "winget" -ArgumentList $arguments
                return
            }
            catch {
                $lastError = $_
                Write-Log "Попытка установки не удалась, пробую более совместимый вариант: $($arguments -join ' ')" "WARN"
            }
        }

        throw $lastError
    }
}

function Install-AppProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("required", "optional")]
        [string]$ProfileName
    )

    $catalog = Get-AppCatalog
    $packages = @($catalog.$ProfileName)

    Write-Section "Установка профиля: $ProfileName"

    Install-AppPackages -Packages $packages
}

function Install-AppProfileInteractive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("required", "optional")]
        [string]$ProfileName
    )

    $catalog = Get-AppCatalog
    $packages = @($catalog.$ProfileName)

    Write-Section "Выбор приложений из профиля: $ProfileName"

    for ($index = 0; $index -lt $packages.Count; $index++) {
        $package = $packages[$index]
        Write-Host ("{0}. {1} [{2}]" -f ($index + 1), $package.Name, $package.Id)
    }

    $selection = @(Read-NumberSelection -MaxNumber $packages.Count -Prompt "Введите номера приложений для установки через запятую")

    if ($selection.Count -eq 0) {
        Write-Warning "Ничего не выбрано."
        return
    }

    $selectedPackages = @(foreach ($number in $selection) {
        $packages[$number - 1]
    })

    Install-AppPackages -Packages $selectedPackages
}

function Install-AppPackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Packages
    )

    foreach ($package in $Packages) {
        Install-WingetPackage -Package $package
    }
}

function Install-AppNames {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Names
    )

    $packages = foreach ($name in $Names) {
        Get-AppPackageByName -Name $name
    }

    Install-AppPackages -Packages $packages
}

function Update-AllWingetPackages {
    [CmdletBinding()]
    param()

    [void](Get-WingetCommand)

    Invoke-LoggedAction -Name "Обновить все пакеты через winget" -Action {
        Invoke-NativeCommand -FilePath "winget" -ArgumentList @(
            "upgrade",
            "--all",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "--disable-interactivity"
        )
    }
}

function Install-CustomAppSelection {
    [CmdletBinding()]
    param()

    $packages = Get-AllCatalogPackages

    Write-Section "Выбор приложений"

    for ($index = 0; $index -lt $packages.Count; $index++) {
        $package = $packages[$index]
        Write-Host ("{0}. {1} [{2}]" -f ($index + 1), $package.Name, $package.Id)
    }

    $selection = @(Read-NumberSelection -MaxNumber $packages.Count -Prompt "Введите номера пакетов через запятую")

    if ($selection.Count -eq 0) {
        Write-Warning "Ничего не выбрано."
        return
    }

    foreach ($number in $selection) {
        Install-WingetPackage -Package $packages[$number - 1]
    }
}

Export-ModuleMember -Function @(
    "Get-AppCatalog",
    "Get-AppPackageByName",
    "Install-AppProfile",
    "Install-AppProfileInteractive",
    "Install-AppPackages",
    "Install-AppNames",
    "Install-CustomAppSelection",
    "Install-WingetPackage",
    "Update-AllWingetPackages"
)
