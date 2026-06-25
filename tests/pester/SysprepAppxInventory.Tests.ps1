$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Sysprep AppX inventory seam" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitAppxInventory.ps1")

        foreach ($commandName in @("Get-AppxPackage", "Get-AppxProvisionedPackage")) {
            if (-not (Test-Path -LiteralPath "function:\$commandName")) {
                Set-Item -Path "function:\global:$commandName" -Value { @() }
            }
        }
    }

    It "normalizes provisioned package fixtures" {
        $provisioned = [pscustomobject]@{
            DisplayName = "Contoso.App"
            PackageName = "Contoso.App_1.0.0.0_neutral__abc123"
            PublisherId = "abc123"
            Version = "1.0.0.0"
            Architecture = "neutral"
            IsFramework = $true
            NonRemovable = $true
        }

        $inventory = Get-KitAppxInventory -ProvisionedPackages @($provisioned) -InstalledPackages @()
        $package = @($inventory.provisionedPackages)[0]

        Assert-KitEqual $inventory.source "fixture"
        Assert-KitEqual $package.name "Contoso.App"
        Assert-KitEqual $package.packageFamilyName "Contoso.App_abc123"
        Assert-KitEqual $package.source "provisioned"
        Assert-KitEqual $package.isFramework $true
        Assert-KitEqual $package.nonRemovable $true
    }

    It "normalizes installed all-users package fixtures" {
        $installed = [pscustomobject]@{
            Name = "Contoso.App"
            PackageFullName = "Contoso.App_1.0.0.0_x64__abc123"
            PackageFamilyName = "Contoso.App_abc123"
            Publisher = "CN=Contoso"
            Version = "1.0.0.0"
            Architecture = "x64"
            UserSecurityId = "S-1-5-21-100"
            IsResourcePackage = $true
        }

        $inventory = Get-KitAppxInventory -ProvisionedPackages @() -InstalledPackages @($installed)
        $package = @($inventory.installedPackages)[0]

        Assert-KitEqual $package.packageName "Contoso.App_1.0.0.0_x64__abc123"
        Assert-KitEqual $package.packageFullName "Contoso.App_1.0.0.0_x64__abc123"
        Assert-KitEqual $package.packageFamilyName "Contoso.App_abc123"
        Assert-KitEqual $package.source "installed"
        Assert-KitEqual $package.userSid "S-1-5-21-100"
        Assert-KitEqual $package.isResourcePackage $true
    }

    It "records query errors in a structured shape" {
        $inventory = Get-KitAppxInventory -ProvisionedQuery { throw "provisioned denied" } -InstalledPackages @()

        Assert-KitEqual @($inventory.queryErrors).Count 1
        Assert-KitEqual @($inventory.queryErrors)[0].source "provisioned"
        Assert-KitMatch @($inventory.queryErrors)[0].message "provisioned denied"
    }

    It "does not call live AppX cmdlets when fixtures are provided" {
        Mock Get-AppxPackage { throw "Get-AppxPackage should not be called." }
        Mock Get-AppxProvisionedPackage { throw "Get-AppxProvisionedPackage should not be called." }

        $inventory = Get-KitAppxInventory -ProvisionedPackages @() -InstalledPackages @()

        Assert-KitEqual @($inventory.queryErrors).Count 0
        Assert-MockCalled Get-AppxPackage -Times 0 -Exactly
        Assert-MockCalled Get-AppxProvisionedPackage -Times 0 -Exactly
    }

    It "preserves framework resource and non-removable flags" {
        $installed = [pscustomobject]@{
            Name = "Framework.App"
            PackageFullName = "Framework.App_1.0.0.0_x64__abc123"
            PackageFamilyName = "Framework.App_abc123"
            IsFramework = $true
            IsResourcePackage = $true
            NonRemovable = $true
        }

        $package = @(Get-KitAppxInventory -ProvisionedPackages @() -InstalledPackages @($installed)).installedPackages[0]

        Assert-KitEqual $package.isFramework $true
        Assert-KitEqual $package.isResourcePackage $true
        Assert-KitEqual $package.nonRemovable $true
    }
}
