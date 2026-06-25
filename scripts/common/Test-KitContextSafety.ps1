function Get-KitContextItemErrors {
    param(
        [Parameter(Mandatory)]
        $Item,

        [switch]$ValidateMode
    )

    $errors = @()
    $root = [string]$Item.root
    $path = [string]$Item.path
    $pathLower = $path.ToLowerInvariant()

    if ($Item.context -eq "machine") {
        if ($root -eq "HKCU" -or $pathLower -match '%userprofile%' -or $pathLower -match '\$env:userprofile' -or $pathLower -match '%localappdata%' -or $pathLower -match '%appdata%') {
            $errors += "machine context must not target HKCU or current-user profile"
        }
    }

    if ($Item.context -eq "current-user" -and $Item.phase -eq "build" -and $Item.status -eq "allowed") {
        $errors += "current-user context cannot be allowed in build phase"
    }

    if ($Item.context -eq "default-user") {
        $hasDefaultMarker = $root -eq "HKU_DEFAULT" -or
            $pathLower -match '(^|[\\/%])users[\\/%]default([\\/%]|$)' -or
            $pathLower -match '\$\{defaultuserprofile\}' -or
            $pathLower -match '%systemdrive%[\\/]users[\\/]default'
        if (-not $hasDefaultMarker) {
            $errors += "default-user context requires a Default User hive, profile path, or marker"
        }
    }

    if (@($Item.errors | Where-Object { [string]$_ -match "ambiguous" }).Count -gt 0 -and $Item.status -ne "blocked") {
        $errors += "ambiguous context must be blocked"
    }

    if ($Item.context -eq "unknown" -and $Item.status -eq "allowed") {
        $errors += "unknown context cannot be allowed"
    }

    if ($Item.mutationPolicy -notin @("planned", "manual", "blocked")) {
        $errors += "invalid mutationPolicy: $($Item.mutationPolicy)"
    }

    if ($ValidateMode -and $Item.status -eq "allowed" -and $Item.mutationPolicy -ne "planned") {
        $errors += "validate mode only allows plan or mock routing"
    }

    return $errors
}

function Test-KitContextSafety {
    param(
        [Parameter(Mandatory)]
        $InputObject,

        [switch]$ValidateMode
    )

    $items = @()
    if ($null -ne $InputObject.PSObject.Properties["items"]) {
        $items = @($InputObject.items)
    } else {
        $items = @($InputObject)
    }

    $checked = @()
    foreach ($item in $items) {
        $safetyErrors = @(Get-KitContextItemErrors -Item $item -ValidateMode:$ValidateMode)
        $mergedErrors = @($item.errors) + $safetyErrors
        $status = [string]$item.status
        if ($mergedErrors.Count -gt 0) {
            $status = "blocked"
        }

        $checked += [pscustomobject]@{
            id = $item.id
            context = $item.context
            phase = $item.phase
            targetType = $item.targetType
            root = $item.root
            path = $item.path
            mutationPolicy = $item.mutationPolicy
            status = $status
            reason = $item.reason
            warnings = @($item.warnings)
            errors = @($mergedErrors)
        }
    }

    $blockedCount = @($checked | Where-Object { $_.status -eq "blocked" }).Count
    $manualCount = @($checked | Where-Object { $_.status -eq "manual" }).Count
    $status = "passed"
    if ($blockedCount -gt 0) {
        $status = "failed"
    } elseif ($manualCount -gt 0) {
        $status = "manual"
    }

    [pscustomobject]@{
        status = $status
        summary = [pscustomobject]@{
            total = @($checked).Count
            manualCount = $manualCount
            blockedCount = $blockedCount
        }
        items = @($checked)
    }
}
