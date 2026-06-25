#Requires -Version 5.1

function Get-KitSysprepAppxProperty {
    param(
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [AllowNull()]
        $DefaultValue = $null
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    if ($InputObject -is [System.Collections.IDictionary] -and $InputObject.Contains($Name)) {
        return $InputObject[$Name]
    }

    if ($null -ne $InputObject.PSObject -and $null -ne $InputObject.PSObject.Properties[$Name]) {
        return $InputObject.PSObject.Properties[$Name].Value
    }

    return $DefaultValue
}

function Get-KitSysprepAppxRule {
    param(
        [AllowNull()]
        $Policy,

        [Parameter(Mandatory)]
        [string]$Name,

        [bool]$DefaultValue = $true
    )

    $rules = Get-KitSysprepAppxProperty -InputObject $Policy -Name "rules" -DefaultValue $null
    if ($null -eq $rules) {
        return $DefaultValue
    }

    return [bool](Get-KitSysprepAppxProperty -InputObject $rules -Name $Name -DefaultValue $DefaultValue)
}

function Get-KitSysprepAppxFamilyPolicyMap {
    param(
        [AllowNull()]
        $Items = @()
    )

    $map = @{}
    foreach ($item in @($Items)) {
        $familyName = [string](Get-KitSysprepAppxProperty -InputObject $item -Name "familyName" -DefaultValue "")
        if ([string]::IsNullOrWhiteSpace($familyName)) {
            continue
        }

        $map[$familyName.ToLowerInvariant()] = [pscustomobject]@{
            familyName = $familyName
            reason = [string](Get-KitSysprepAppxProperty -InputObject $item -Name "reason" -DefaultValue "")
        }
    }

    return $map
}

function Resolve-KitSysprepAppxBlockingStatus {
    param(
        [Parameter(Mandatory)]
        [string]$FailurePolicy
    )

    switch ($FailurePolicy.ToLowerInvariant()) {
        "manual" { return "manual" }
        "skip" { return "ignored" }
        default { return "blocking" }
    }
}

function Get-KitSysprepAppxPackageFamilyName {
    param(
        [AllowNull()]
        $Package
    )

    return [string](Get-KitSysprepAppxProperty -InputObject $Package -Name "packageFamilyName" -DefaultValue "")
}

function Test-KitSysprepAppxIgnoredPackage {
    param(
        [AllowNull()]
        $Package,

        [AllowNull()]
        $Policy
    )

    if ([bool](Get-KitSysprepAppxProperty -InputObject $Package -Name "isFramework" -DefaultValue $false) -and
        (Get-KitSysprepAppxRule -Policy $Policy -Name "ignoreFrameworkPackages" -DefaultValue $true)) {
        return "framework-package-ignored"
    }

    if ([bool](Get-KitSysprepAppxProperty -InputObject $Package -Name "isResourcePackage" -DefaultValue $false) -and
        (Get-KitSysprepAppxRule -Policy $Policy -Name "ignoreResourcePackages" -DefaultValue $true)) {
        return "resource-package-ignored"
    }

    if ([bool](Get-KitSysprepAppxProperty -InputObject $Package -Name "nonRemovable" -DefaultValue $false) -and
        (Get-KitSysprepAppxRule -Policy $Policy -Name "ignoreNonRemovableSystemPackages" -DefaultValue $true)) {
        return "non-removable-package-ignored"
    }

    return ""
}

function New-KitSysprepAppxFinding {
    param(
        [AllowNull()]
        $Package,

        [Parameter(Mandatory)]
        [ValidateSet("blocking", "manual", "allowed", "ignored")]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Reason,

        [Parameter(Mandatory)]
        [string]$RecommendedAction,

        [AllowEmptyString()]
        [string]$PolicyReason = ""
    )

    [pscustomobject][ordered]@{
        packageFamilyName = Get-KitSysprepAppxPackageFamilyName -Package $Package
        packageFullName = [string](Get-KitSysprepAppxProperty -InputObject $Package -Name "packageFullName" -DefaultValue "")
        packageName = [string](Get-KitSysprepAppxProperty -InputObject $Package -Name "packageName" -DefaultValue "")
        source = [string](Get-KitSysprepAppxProperty -InputObject $Package -Name "source" -DefaultValue "")
        status = $Status
        reason = $Reason
        policyReason = $PolicyReason
        evidence = [pscustomobject][ordered]@{
            name = [string](Get-KitSysprepAppxProperty -InputObject $Package -Name "name" -DefaultValue "")
            version = [string](Get-KitSysprepAppxProperty -InputObject $Package -Name "version" -DefaultValue "")
            architecture = [string](Get-KitSysprepAppxProperty -InputObject $Package -Name "architecture" -DefaultValue "")
            userSid = [string](Get-KitSysprepAppxProperty -InputObject $Package -Name "userSid" -DefaultValue "")
            isFramework = [bool](Get-KitSysprepAppxProperty -InputObject $Package -Name "isFramework" -DefaultValue $false)
            isResourcePackage = [bool](Get-KitSysprepAppxProperty -InputObject $Package -Name "isResourcePackage" -DefaultValue $false)
            nonRemovable = [bool](Get-KitSysprepAppxProperty -InputObject $Package -Name "nonRemovable" -DefaultValue $false)
        }
        recommendedAction = $RecommendedAction
    }
}

function New-KitSysprepAppxReadinessReport {
    param(
        [AllowNull()]
        $Policy,

        [AllowEmptyString()]
        [string]$PolicyPath = "",

        [AllowNull()]
        $Findings = @(),

        [AllowNull()]
        $QueryErrors = @(),

        [switch]$WhatIf
    )

    $findingList = @($Findings)
    $queryErrorList = @($QueryErrors)
    $blockingCount = @($findingList | Where-Object { $_.status -eq "blocking" }).Count
    $manualCount = @($findingList | Where-Object { $_.status -eq "manual" }).Count
    $allowedCount = @($findingList | Where-Object { $_.status -eq "allowed" }).Count
    $ignoredCount = @($findingList | Where-Object { $_.status -eq "ignored" }).Count
    $failurePolicy = [string](Get-KitSysprepAppxProperty -InputObject $Policy -Name "failurePolicy" -DefaultValue "fail")
    if ([string]::IsNullOrWhiteSpace($failurePolicy)) {
        $failurePolicy = "fail"
    }

    $status = "passed"
    $exitCode = 0
    if ($blockingCount -gt 0) {
        $status = "failed"
        $exitCode = 1
    } elseif ($manualCount -gt 0) {
        $status = "manual"
    } elseif ($findingList.Count -gt 0 -and $ignoredCount -eq $findingList.Count -and $failurePolicy -eq "skip") {
        $status = "skipped"
    }

    $statusCounts = [ordered]@{
        blocking = $blockingCount
        manual = $manualCount
        allowed = $allowedCount
        ignored = $ignoredCount
    }

    [pscustomobject][ordered]@{
        reportType = "sysprep-appx-readiness"
        policyPath = $PolicyPath
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        mode = [string](Get-KitSysprepAppxProperty -InputObject $Policy -Name "mode" -DefaultValue "audit")
        failurePolicy = $failurePolicy
        status = $status
        exitCode = $exitCode
        summary = [pscustomobject][ordered]@{
            totalFamilies = @($findingList | Where-Object { -not [string]::IsNullOrWhiteSpace($_.packageFamilyName) } | Select-Object -ExpandProperty packageFamilyName -Unique).Count
            blockingCount = $blockingCount
            manualCount = $manualCount
            allowedCount = $allowedCount
            ignoredCount = $ignoredCount
            queryErrorCount = $queryErrorList.Count
            statusCounts = [pscustomobject]$statusCounts
            hasBlockingFailure = ($blockingCount -gt 0)
        }
        findings = $findingList
        queryErrors = $queryErrorList
        recommendedActions = @($findingList | ForEach-Object { $_.recommendedAction } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        whatIf = [bool]$WhatIf
        stepSummary = [pscustomobject][ordered]@{
            total = $findingList.Count
            statusCounts = [pscustomobject]$statusCounts
            hasBlockingFailure = ($blockingCount -gt 0)
            exitCode = $exitCode
        }
    }
}

function Add-KitSysprepAppxReadinessFinding {
    param(
        [AllowNull()]
        $Package,

        [Parameter(Mandatory)]
        [ValidateSet("blocking", "manual", "allowed", "ignored")]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Reason,

        [Parameter(Mandatory)]
        [string]$RecommendedAction,

        [AllowEmptyString()]
        [string]$PolicyReason = "",

        [Parameter(Mandatory)]
        [ref]$Findings,

        [Parameter(Mandatory)]
        [hashtable]$Reported
    )

    $family = Get-KitSysprepAppxPackageFamilyName -Package $Package
    $key = "{0}|{1}|{2}" -f $family.ToLowerInvariant(), $Status, $Reason
    if ($Reported.ContainsKey($key)) {
        return
    }

    $list = @($Findings.Value)
    $list += New-KitSysprepAppxFinding -Package $Package -Status $Status -Reason $Reason -RecommendedAction $RecommendedAction -PolicyReason $PolicyReason
    $Findings.Value = $list
    $Reported[$key] = $true
}

function Test-KitSysprepAppxReadiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Inventory,

        [Parameter(Mandatory)]
        $Policy,

        [AllowEmptyString()]
        [string]$PolicyPath = "",

        [switch]$WhatIf
    )

    $failurePolicy = [string](Get-KitSysprepAppxProperty -InputObject $Policy -Name "failurePolicy" -DefaultValue "fail")
    if ([string]::IsNullOrWhiteSpace($failurePolicy)) {
        $failurePolicy = "fail"
    }

    $allowMap = Get-KitSysprepAppxFamilyPolicyMap -Items (Get-KitSysprepAppxProperty -InputObject $Policy -Name "allowFamilies" -DefaultValue @())
    $manualMap = Get-KitSysprepAppxFamilyPolicyMap -Items (Get-KitSysprepAppxProperty -InputObject $Policy -Name "manualFamilies" -DefaultValue @())
    $findings = @()
    $reported = @{}
    $provisionedPackages = @(Get-KitSysprepAppxProperty -InputObject $Inventory -Name "provisionedPackages" -DefaultValue @())
    $installedPackages = @(Get-KitSysprepAppxProperty -InputObject $Inventory -Name "installedPackages" -DefaultValue @())
    $queryErrors = @(Get-KitSysprepAppxProperty -InputObject $Inventory -Name "queryErrors" -DefaultValue @())

    $provisionedByFamily = @{}
    foreach ($package in $provisionedPackages) {
        $family = (Get-KitSysprepAppxPackageFamilyName -Package $package).ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($family)) {
            continue
        }
        if (-not $provisionedByFamily.ContainsKey($family)) {
            $provisionedByFamily[$family] = @()
        }
        $provisionedByFamily[$family] = @($provisionedByFamily[$family]) + $package
    }

    $installedByFamily = @{}
    foreach ($package in $installedPackages) {
        $family = (Get-KitSysprepAppxPackageFamilyName -Package $package).ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($family)) {
            continue
        }
        if (-not $installedByFamily.ContainsKey($family)) {
            $installedByFamily[$family] = @()
        }
        $installedByFamily[$family] = @($installedByFamily[$family]) + $package
    }

    foreach ($package in $installedPackages) {
        $family = Get-KitSysprepAppxPackageFamilyName -Package $package
        if ([string]::IsNullOrWhiteSpace($family)) {
            Add-KitSysprepAppxReadinessFinding -Package $package -Status "manual" -Reason "missing-package-family-name" -RecommendedAction "Inspect AppX package identity manually before Sysprep." -Findings ([ref]$findings) -Reported $reported
            continue
        }

        $familyKey = $family.ToLowerInvariant()
        $ignoreReason = Test-KitSysprepAppxIgnoredPackage -Package $package -Policy $Policy
        if (-not [string]::IsNullOrWhiteSpace($ignoreReason)) {
            Add-KitSysprepAppxReadinessFinding -Package $package -Status "ignored" -Reason $ignoreReason -RecommendedAction "No automated action; keep this package visible in the audit report." -Findings ([ref]$findings) -Reported $reported
            continue
        }

        if ($manualMap.ContainsKey($familyKey)) {
            Add-KitSysprepAppxReadinessFinding -Package $package -Status "manual" -Reason "manual-family-policy" -RecommendedAction "Review this AppX family in a VM snapshot before Sysprep." -PolicyReason $manualMap[$familyKey].reason -Findings ([ref]$findings) -Reported $reported
            continue
        }

        if ($allowMap.ContainsKey($familyKey)) {
            Add-KitSysprepAppxReadinessFinding -Package $package -Status "allowed" -Reason "allow-family-policy" -RecommendedAction "Keep allowed family visible and verify consistency before sealing." -PolicyReason $allowMap[$familyKey].reason -Findings ([ref]$findings) -Reported $reported
            continue
        }

        if (-not $provisionedByFamily.ContainsKey($familyKey) -and
            (Get-KitSysprepAppxRule -Policy $Policy -Name "blockUserInstalledNotProvisioned" -DefaultValue $true)) {
            $status = Resolve-KitSysprepAppxBlockingStatus -FailurePolicy $failurePolicy
            Add-KitSysprepAppxReadinessFinding -Package $package -Status $status -Reason "user-installed-not-provisioned" -RecommendedAction "Review the report, then repair manually in a VM snapshot if this family must be removed or provisioned consistently." -Findings ([ref]$findings) -Reported $reported
        }
    }

    foreach ($package in $provisionedPackages) {
        $family = Get-KitSysprepAppxPackageFamilyName -Package $package
        if ([string]::IsNullOrWhiteSpace($family)) {
            Add-KitSysprepAppxReadinessFinding -Package $package -Status "manual" -Reason "missing-package-family-name" -RecommendedAction "Inspect AppX package identity manually before Sysprep." -Findings ([ref]$findings) -Reported $reported
            continue
        }

        $familyKey = $family.ToLowerInvariant()
        $ignoreReason = Test-KitSysprepAppxIgnoredPackage -Package $package -Policy $Policy
        if (-not [string]::IsNullOrWhiteSpace($ignoreReason)) {
            Add-KitSysprepAppxReadinessFinding -Package $package -Status "ignored" -Reason $ignoreReason -RecommendedAction "No automated action; keep this package visible in the audit report." -Findings ([ref]$findings) -Reported $reported
            continue
        }

        if ($manualMap.ContainsKey($familyKey)) {
            Add-KitSysprepAppxReadinessFinding -Package $package -Status "manual" -Reason "manual-family-policy" -RecommendedAction "Review this AppX family in a VM snapshot before Sysprep." -PolicyReason $manualMap[$familyKey].reason -Findings ([ref]$findings) -Reported $reported
            continue
        }

        if ($allowMap.ContainsKey($familyKey)) {
            Add-KitSysprepAppxReadinessFinding -Package $package -Status "allowed" -Reason "allow-family-policy" -RecommendedAction "Keep allowed family visible and verify consistency before sealing." -PolicyReason $allowMap[$familyKey].reason -Findings ([ref]$findings) -Reported $reported
            continue
        }

        if (-not $installedByFamily.ContainsKey($familyKey) -and
            (Get-KitSysprepAppxRule -Policy $Policy -Name "blockProvisionedInstalledMismatch" -DefaultValue $true)) {
            $status = Resolve-KitSysprepAppxBlockingStatus -FailurePolicy $failurePolicy
            Add-KitSysprepAppxReadinessFinding -Package $package -Status $status -Reason "provisioned-installed-mismatch" -RecommendedAction "Review provisioned and all-users AppX state manually in a VM snapshot before Sysprep." -Findings ([ref]$findings) -Reported $reported
        }
    }

    if ($queryErrors.Count -gt 0 -and (Get-KitSysprepAppxRule -Policy $Policy -Name "blockQueryFailure" -DefaultValue $true)) {
        foreach ($queryError in $queryErrors) {
            $status = Resolve-KitSysprepAppxBlockingStatus -FailurePolicy $failurePolicy
            $package = [pscustomobject]@{
                packageFamilyName = "query:{0}" -f ([string](Get-KitSysprepAppxProperty -InputObject $queryError -Name "source" -DefaultValue "appx"))
                packageFullName = ""
                packageName = ""
                source = [string](Get-KitSysprepAppxProperty -InputObject $queryError -Name "source" -DefaultValue "appx")
            }
            Add-KitSysprepAppxReadinessFinding -Package $package -Status $status -Reason "appx-query-failed" -RecommendedAction "Fix AppX query permissions or run the audit in an elevated VM snapshot before relying on Sysprep readiness." -PolicyReason ([string](Get-KitSysprepAppxProperty -InputObject $queryError -Name "message" -DefaultValue "")) -Findings ([ref]$findings) -Reported $reported
        }
    }

    New-KitSysprepAppxReadinessReport -Policy $Policy -PolicyPath $PolicyPath -Findings $findings -QueryErrors $queryErrors -WhatIf:$WhatIf
}
