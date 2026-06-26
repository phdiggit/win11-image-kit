#Requires -Version 5.1

. "$PSScriptRoot\Resolve-KitSoftwareState.ps1"

function Resolve-KitServiceCurrentEnsure {
    param(
        [AllowNull()]
        $State
    )

    $explicit = [string](Get-KitEnsureStateProperty -InputObject $State -Name "currentEnsure" -DefaultValue "")
    if (-not [string]::IsNullOrWhiteSpace($explicit)) {
        return $explicit.ToLowerInvariant()
    }

    $status = [string](Get-KitEnsureStateProperty -InputObject $State -Name "status" -DefaultValue "")
    if (-not [string]::IsNullOrWhiteSpace($status)) {
        switch ($status.ToLowerInvariant()) {
            "running" { return "running" }
            "stopped" { return "stopped" }
            "disabled" { return "stopped" }
            "absent" { return "absent" }
        }
    }

    $present = Get-KitEnsureStateProperty -InputObject $State -Name "present" -DefaultValue $null
    if ($null -ne $present -and -not [bool]$present) {
        return "absent"
    }

    return "unknown"
}

function Resolve-KitServiceStartupType {
    param(
        [AllowNull()]
        $State
    )

    $value = [string](Get-KitEnsureStateProperty -InputObject $State -Name "currentStartupType" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [string](Get-KitEnsureStateProperty -InputObject $State -Name "startupType" -DefaultValue "")
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [string](Get-KitEnsureStateProperty -InputObject $State -Name "startMode" -DefaultValue "")
    }

    return $value.ToLowerInvariant()
}

function Resolve-KitServiceState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $ServiceItem,

        [AllowNull()]
        $FixtureState,

        [AllowNull()]
        $CurrentState
    )

    $desiredEnsure = [string](Get-KitEnsureStateProperty -InputObject $ServiceItem -Name "ensure" -DefaultValue "")
    $desiredStartupType = [string](Get-KitEnsureStateProperty -InputObject $ServiceItem -Name "startupType" -DefaultValue "")
    $changeMode = [string](Get-KitEnsureStateProperty -InputObject $ServiceItem -Name "changeMode" -DefaultValue "")
    $state = if ($null -ne $FixtureState) { $FixtureState } else { $CurrentState }
    $currentEnsure = Resolve-KitServiceCurrentEnsure -State $state
    $currentStartupType = Resolve-KitServiceStartupType -State $state
    $warnings = @()
    $errors = @()
    $status = "unknown"

    if ($null -eq $state) {
        $warnings += "service fixture/current state not provided"
    }

    if ([string]::IsNullOrWhiteSpace($desiredEnsure)) {
        $errors += "service item missing desired ensure"
    } else {
        $desiredEnsure = $desiredEnsure.ToLowerInvariant()
    }

    if ([string]::IsNullOrWhiteSpace($desiredStartupType)) {
        $warnings += "service item missing desired startupType"
    } else {
        $desiredStartupType = $desiredStartupType.ToLowerInvariant()
    }

    if ([string]::IsNullOrWhiteSpace($changeMode)) {
        $warnings += "service item missing changeMode"
    } else {
        $changeMode = $changeMode.ToLowerInvariant()
    }

    if ($errors.Count -eq 0) {
        if ($desiredEnsure -eq "manual" -or $changeMode -eq "manual") {
            $status = "manual"
        } elseif ($desiredEnsure -eq "ignore") {
            $status = "manual"
            $warnings += "ignore service entry only reports drift and review state"
        } elseif ($currentEnsure -eq "unknown") {
            $status = "unknown"
        } else {
            $ensureMatches = $false
            switch ($desiredEnsure) {
                "running" { $ensureMatches = $currentEnsure -eq "running" }
                "stopped" { $ensureMatches = $currentEnsure -eq "stopped" }
                "absent" { $ensureMatches = $currentEnsure -eq "absent" }
                "disabled" { $ensureMatches = $currentEnsure -in @("stopped", "absent") }
            }

            $startupMatches = $true
            if ($desiredStartupType -and $desiredStartupType -ne "unchanged") {
                $startupMatches = $desiredStartupType -eq $currentStartupType
            }

            if ($ensureMatches -and $startupMatches) {
                $status = "matched"
            } else {
                $status = "drift"
            }
        }

        if ($status -eq "matched" -and $changeMode -eq "disabled") {
            $warnings += "disabled service entry only reports drift and match state"
        }
    }

    [pscustomobject][ordered]@{
        name = [string](Get-KitEnsureStateProperty -InputObject $ServiceItem -Name "name" -DefaultValue "")
        displayName = [string](Get-KitEnsureStateProperty -InputObject $ServiceItem -Name "displayName" -DefaultValue "")
        desiredEnsure = $desiredEnsure
        desiredStartupType = $desiredStartupType
        currentEnsure = $currentEnsure
        currentStartupType = $currentStartupType
        scope = [string](Get-KitEnsureStateProperty -InputObject $ServiceItem -Name "scope" -DefaultValue "")
        changeMode = $changeMode
        status = $status
        actions = @()
        warnings = @($warnings)
        errors = @($errors)
    }
}
