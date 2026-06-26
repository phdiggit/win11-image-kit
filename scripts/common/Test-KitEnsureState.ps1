#Requires -Version 5.1

. "$PSScriptRoot\New-KitEnsureStatePlan.ps1"

function New-KitEnsureStateResultItem {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("software", "service")]
        [string]$Kind,

        [Parameter(Mandatory)]
        $Item
    )

    $id = if ($Kind -eq "software") { [string]$Item.id } else { [string]$Item.name }
    $desired = if ($Kind -eq "software") {
        [pscustomobject]@{
            ensure = [string]$Item.desiredEnsure
            version = $Item.version
        }
    } else {
        [pscustomobject]@{
            ensure = [string]$Item.desiredEnsure
            startupType = [string]$Item.desiredStartupType
        }
    }
    $current = if ($Kind -eq "software") {
        [pscustomobject]@{
            ensure = [string]$Item.currentEnsure
            version = $Item.currentVersion
        }
    } else {
        [pscustomobject]@{
            ensure = [string]$Item.currentEnsure
            startupType = [string]$Item.currentStartupType
        }
    }

    $status = "manual"
    $errors = @($Item.errors)
    $warnings = @($Item.warnings)

    if ([string]::IsNullOrWhiteSpace([string]$id)) {
        $errors += "missing identity"
    }

    if ($Kind -eq "software") {
        if ([string]::IsNullOrWhiteSpace([string]$Item.desiredEnsure)) {
            $errors += "missing desired software ensure"
        }
    } else {
        if ([string]::IsNullOrWhiteSpace([string]$Item.desiredEnsure)) {
            $errors += "missing desired service ensure"
        }
    }

    if ($errors.Count -gt 0) {
        $status = "failed"
    } elseif ($Item.status -eq "matched") {
        $status = "passed"
    } elseif ($Item.status -eq "unknown") {
        $status = "manual"
    } elseif (@($Item.actions).Count -gt 0) {
        $status = "manual"
    } elseif ($Item.status -eq "manual") {
        $status = "manual"
    }

    [pscustomobject][ordered]@{
        kind = $Kind
        id = $id
        status = $status
        desired = $desired
        current = $current
        actions = @($Item.actions)
        warnings = @($warnings)
        errors = @($errors)
    }
}

function Test-KitEnsureState {
    [CmdletBinding()]
    param(
        [AllowNull()]
        $Plan,

        [AllowNull()]
        $SoftwareManifest,

        [AllowNull()]
        $ServicesManifest,

        [AllowNull()]
        $SoftwareFixtureState,

        [AllowNull()]
        $ServiceFixtureState,

        [switch]$WhatIf
    )

    if ($null -eq $Plan) {
        if ($null -eq $SoftwareManifest -or $null -eq $ServicesManifest) {
            throw "Test-KitEnsureState requires either -Plan or both manifests"
        }

        $Plan = New-KitEnsureStatePlan `
            -SoftwareManifest $SoftwareManifest `
            -ServicesManifest $ServicesManifest `
            -SoftwareFixtureState $SoftwareFixtureState `
            -ServiceFixtureState $ServiceFixtureState `
            -WhatIf:$WhatIf
    }

    $results = @()
    foreach ($item in @($Plan.software)) {
        $results += New-KitEnsureStateResultItem -Kind "software" -Item $item
    }
    foreach ($item in @($Plan.services)) {
        $results += New-KitEnsureStateResultItem -Kind "service" -Item $item
    }

    return @($results)
}
