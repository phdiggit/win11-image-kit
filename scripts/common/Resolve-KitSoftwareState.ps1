#Requires -Version 5.1

function Get-KitEnsureStateProperty {
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

function Resolve-KitSoftwareCurrentEnsure {
    param(
        [AllowNull()]
        $State
    )

    $explicit = [string](Get-KitEnsureStateProperty -InputObject $State -Name "currentEnsure" -DefaultValue "")
    if (-not [string]::IsNullOrWhiteSpace($explicit)) {
        return $explicit.ToLowerInvariant()
    }

    $ensure = [string](Get-KitEnsureStateProperty -InputObject $State -Name "ensure" -DefaultValue "")
    if (-not [string]::IsNullOrWhiteSpace($ensure)) {
        return $ensure.ToLowerInvariant()
    }

    $present = Get-KitEnsureStateProperty -InputObject $State -Name "present" -DefaultValue $null
    if ($null -ne $present) {
        if ([bool]$present) {
            return "present"
        }

        return "absent"
    }

    $installed = Get-KitEnsureStateProperty -InputObject $State -Name "installed" -DefaultValue $null
    if ($null -ne $installed) {
        if ([bool]$installed) {
            return "present"
        }

        return "absent"
    }

    return "unknown"
}

function Resolve-KitSoftwareState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $SoftwareItem,

        [AllowNull()]
        $FixtureState,

        [AllowNull()]
        $CurrentState
    )

    $desiredEnsure = [string](Get-KitEnsureStateProperty -InputObject $SoftwareItem -Name "ensure" -DefaultValue "")
    $installMode = [string](Get-KitEnsureStateProperty -InputObject $SoftwareItem -Name "installMode" -DefaultValue "")
    $state = if ($null -ne $FixtureState) { $FixtureState } else { $CurrentState }
    $currentEnsure = Resolve-KitSoftwareCurrentEnsure -State $state
    $currentVersion = Get-KitEnsureStateProperty -InputObject $state -Name "version" -DefaultValue $null
    $warnings = @()
    $errors = @()
    $status = "unknown"

    if ($null -eq $state) {
        $warnings += "software fixture/current state not provided"
    }

    if ([string]::IsNullOrWhiteSpace($desiredEnsure)) {
        $errors += "software item missing desired ensure"
    } else {
        $desiredEnsure = $desiredEnsure.ToLowerInvariant()
    }

    if ([string]::IsNullOrWhiteSpace($installMode)) {
        $warnings += "software item missing installMode"
    } else {
        $installMode = $installMode.ToLowerInvariant()
    }

    if ($errors.Count -eq 0) {
        if ($desiredEnsure -eq "manual" -or $installMode -eq "manual") {
            $status = "manual"
        } elseif ($currentEnsure -eq "unknown") {
            $status = "unknown"
        } elseif ($desiredEnsure -eq "present" -and $currentEnsure -eq "present") {
            $status = "matched"
        } elseif ($desiredEnsure -eq "absent" -and $currentEnsure -eq "absent") {
            $status = "matched"
        } elseif ($desiredEnsure -eq "pinned") {
            $desiredVersion = Get-KitEnsureStateProperty -InputObject $SoftwareItem -Name "version" -DefaultValue $null
            if (-not [string]::IsNullOrWhiteSpace([string]$desiredVersion) -and [string]$desiredVersion -eq [string]$currentVersion -and $currentEnsure -eq "present") {
                $status = "matched"
            } else {
                $status = "manual"
                $warnings += "pinned software requires explicit version evidence"
            }
        } elseif ($desiredEnsure -eq "latest") {
            if ($currentEnsure -eq "present" -and -not [string]::IsNullOrWhiteSpace([string]$currentVersion)) {
                $status = "matched"
            } else {
                $status = "manual"
                $warnings += "latest software requires explicit version evidence"
            }
        } else {
            $status = "drift"
        }

        if ($status -eq "unknown" -and $currentEnsure -ne "unknown") {
            $status = "drift"
        }

        if ($status -eq "matched" -and $installMode -eq "disabled") {
            $warnings += "disabled software entry only reports drift and match state"
        }
    }

    [pscustomobject][ordered]@{
        id = [string](Get-KitEnsureStateProperty -InputObject $SoftwareItem -Name "id" -DefaultValue "")
        displayName = [string](Get-KitEnsureStateProperty -InputObject $SoftwareItem -Name "displayName" -DefaultValue "")
        desiredEnsure = $desiredEnsure
        currentEnsure = $currentEnsure
        source = [string](Get-KitEnsureStateProperty -InputObject $SoftwareItem -Name "source" -DefaultValue "")
        packageId = [string](Get-KitEnsureStateProperty -InputObject $SoftwareItem -Name "packageId" -DefaultValue "")
        version = Get-KitEnsureStateProperty -InputObject $SoftwareItem -Name "version" -DefaultValue $null
        currentVersion = $currentVersion
        scope = [string](Get-KitEnsureStateProperty -InputObject $SoftwareItem -Name "scope" -DefaultValue "")
        installMode = $installMode
        status = $status
        actions = @()
        warnings = @($warnings)
        errors = @($errors)
    }
}
