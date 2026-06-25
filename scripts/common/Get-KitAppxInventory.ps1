#Requires -Version 5.1

function Get-KitAppxInventoryProperty {
    param(
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory)]
        [string[]]$Names,

        [AllowNull()]
        $DefaultValue = $null
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    foreach ($name in $Names) {
        if ($InputObject -is [System.Collections.IDictionary] -and $InputObject.Contains($name)) {
            return $InputObject[$name]
        }

        if ($null -ne $InputObject.PSObject -and $null -ne $InputObject.PSObject.Properties[$name]) {
            return $InputObject.PSObject.Properties[$name].Value
        }
    }

    return $DefaultValue
}

function ConvertTo-KitAppxInventoryBoolean {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    if ($Value -is [bool]) {
        return [bool]$Value
    }

    $text = ([string]$Value).Trim()
    return $text -in @("1", "true", "yes")
}

function Resolve-KitAppxPackageFamilyName {
    param(
        [AllowEmptyString()]
        [string]$PackageFamilyName,

        [AllowEmptyString()]
        [string]$Name,

        [AllowEmptyString()]
        [string]$PackageName,

        [AllowEmptyString()]
        [string]$PublisherId
    )

    if (-not [string]::IsNullOrWhiteSpace($PackageFamilyName)) {
        return $PackageFamilyName
    }

    if (-not [string]::IsNullOrWhiteSpace($Name) -and -not [string]::IsNullOrWhiteSpace($PublisherId)) {
        return ("{0}_{1}" -f $Name, $PublisherId)
    }

    if (-not [string]::IsNullOrWhiteSpace($PackageName)) {
        $parts = $PackageName.Split("_")
        if ($parts.Count -ge 5) {
            return ("{0}_{1}" -f $parts[0], $parts[$parts.Count - 1])
        }
    }

    return ""
}

function ConvertTo-KitAppxInventoryPackage {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        [ValidateSet("provisioned", "installed")]
        [string]$Source
    )

    $name = [string](Get-KitAppxInventoryProperty -InputObject $Package -Names @("Name", "DisplayName") -DefaultValue "")
    $packageName = [string](Get-KitAppxInventoryProperty -InputObject $Package -Names @("PackageName") -DefaultValue "")
    $packageFullName = [string](Get-KitAppxInventoryProperty -InputObject $Package -Names @("PackageFullName") -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($packageName)) {
        $packageName = $packageFullName
    }
    if ([string]::IsNullOrWhiteSpace($packageFullName)) {
        $packageFullName = $packageName
    }

    $publisherId = [string](Get-KitAppxInventoryProperty -InputObject $Package -Names @("PublisherId") -DefaultValue "")
    $familyName = Resolve-KitAppxPackageFamilyName `
        -PackageFamilyName ([string](Get-KitAppxInventoryProperty -InputObject $Package -Names @("PackageFamilyName") -DefaultValue "")) `
        -Name $name `
        -PackageName $packageName `
        -PublisherId $publisherId

    [pscustomobject][ordered]@{
        name = $name
        packageName = $packageName
        packageFullName = $packageFullName
        packageFamilyName = $familyName
        publisher = [string](Get-KitAppxInventoryProperty -InputObject $Package -Names @("Publisher", "PublisherId") -DefaultValue "")
        version = [string](Get-KitAppxInventoryProperty -InputObject $Package -Names @("Version") -DefaultValue "")
        architecture = [string](Get-KitAppxInventoryProperty -InputObject $Package -Names @("Architecture", "ProcessorArchitecture") -DefaultValue "")
        userSid = [string](Get-KitAppxInventoryProperty -InputObject $Package -Names @("UserSid", "UserSecurityId") -DefaultValue "")
        userName = [string](Get-KitAppxInventoryProperty -InputObject $Package -Names @("UserName") -DefaultValue "")
        isFramework = ConvertTo-KitAppxInventoryBoolean (Get-KitAppxInventoryProperty -InputObject $Package -Names @("IsFramework", "Framework") -DefaultValue $false)
        isResourcePackage = ConvertTo-KitAppxInventoryBoolean (Get-KitAppxInventoryProperty -InputObject $Package -Names @("IsResourcePackage", "ResourcePackage") -DefaultValue $false)
        nonRemovable = ConvertTo-KitAppxInventoryBoolean (Get-KitAppxInventoryProperty -InputObject $Package -Names @("NonRemovable") -DefaultValue $false)
        source = $Source
    }
}

function New-KitAppxInventoryQueryError {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [string]$Message
    )

    [pscustomobject][ordered]@{
        source = $Source
        command = $Command
        message = $Message
    }
}

function Get-KitAppxInventory {
    [CmdletBinding()]
    param(
        [AllowNull()]
        $ProvisionedPackages = $null,

        [AllowNull()]
        $InstalledPackages = $null,

        [scriptblock]$ProvisionedQuery = $null,

        [scriptblock]$InstalledQuery = $null
    )

    $queryErrors = @()
    $provisionedRaw = @()
    $installedRaw = @()
    $usesFixture = $PSBoundParameters.ContainsKey("ProvisionedPackages") -or $PSBoundParameters.ContainsKey("InstalledPackages")

    if ($PSBoundParameters.ContainsKey("ProvisionedPackages")) {
        $provisionedRaw = @($ProvisionedPackages)
    } else {
        try {
            if ($null -ne $ProvisionedQuery) {
                $provisionedRaw = @(& $ProvisionedQuery)
            } else {
                $provisionedRaw = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop)
            }
        } catch {
            $queryErrors += New-KitAppxInventoryQueryError -Source "provisioned" -Command "Get-AppxProvisionedPackage -Online" -Message $_.Exception.Message
        }
    }

    if ($PSBoundParameters.ContainsKey("InstalledPackages")) {
        $installedRaw = @($InstalledPackages)
    } else {
        try {
            if ($null -ne $InstalledQuery) {
                $installedRaw = @(& $InstalledQuery)
            } else {
                $installedRaw = @(Get-AppxPackage -AllUsers -ErrorAction Stop)
            }
        } catch {
            $queryErrors += New-KitAppxInventoryQueryError -Source "installed" -Command "Get-AppxPackage -AllUsers" -Message $_.Exception.Message
        }
    }

    [pscustomobject][ordered]@{
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        provisionedPackages = @($provisionedRaw | ForEach-Object { ConvertTo-KitAppxInventoryPackage -Package $_ -Source "provisioned" })
        installedPackages = @($installedRaw | ForEach-Object { ConvertTo-KitAppxInventoryPackage -Package $_ -Source "installed" })
        queryErrors = @($queryErrors)
        source = if ($usesFixture) { "fixture" } else { "live" }
    }
}
