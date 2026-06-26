#Requires -Version 5.1

. "$PSScriptRoot\Resolve-KitSoftwareState.ps1"
. "$PSScriptRoot\Resolve-KitServiceState.ps1"

function Get-KitEnsureStateFixtureMap {
    param(
        [AllowNull()]
        $Items,

        [Parameter(Mandatory)]
        [string]$PrimaryKey,

        [string]$AliasKey = ""
    )

    $map = @{}
    foreach ($item in @($Items)) {
        if ($null -eq $item) {
            continue
        }

        $primary = [string](Get-KitEnsureStateProperty -InputObject $item -Name $PrimaryKey -DefaultValue "")
        if (-not [string]::IsNullOrWhiteSpace($primary)) {
            $map[$primary.ToLowerInvariant()] = $item
        }

        if (-not [string]::IsNullOrWhiteSpace($AliasKey)) {
            $alias = [string](Get-KitEnsureStateProperty -InputObject $item -Name $AliasKey -DefaultValue "")
            if (-not [string]::IsNullOrWhiteSpace($alias)) {
                $map[$alias.ToLowerInvariant()] = $item
            }
        }
    }

    return $map
}

function New-KitEnsureStateAction {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("software", "service")]
        [string]$Kind,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [ValidateSet("planned", "manual", "disabled")]
        [string]$Mode,

        [Parameter(Mandatory)]
        [string]$Reason
    )

    [pscustomobject][ordered]@{
        kind = $Kind
        target = $Target
        operation = $Operation
        mode = $Mode
        reason = $Reason
    }
}

function New-KitEnsureStatePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $SoftwareManifest,

        [Parameter(Mandatory)]
        $ServicesManifest,

        [AllowNull()]
        $SoftwareFixtureState,

        [AllowNull()]
        $ServiceFixtureState,

        [AllowNull()]
        $CurrentSoftwareState,

        [AllowNull()]
        $CurrentServiceState,

        [switch]$WhatIf
    )

    $softwareStates = @()
    $serviceStates = @()
    $actions = @()
    $warnings = @()
    $errors = @()
    $softwareMap = Get-KitEnsureStateFixtureMap -Items $SoftwareFixtureState -PrimaryKey "id" -AliasKey "packageId"
    $serviceMap = Get-KitEnsureStateFixtureMap -Items $ServiceFixtureState -PrimaryKey "name"
    $currentSoftwareMap = Get-KitEnsureStateFixtureMap -Items $CurrentSoftwareState -PrimaryKey "id" -AliasKey "packageId"
    $currentServiceMap = Get-KitEnsureStateFixtureMap -Items $CurrentServiceState -PrimaryKey "name"

    foreach ($item in @($SoftwareManifest.software)) {
        $id = [string](Get-KitEnsureStateProperty -InputObject $item -Name "id" -DefaultValue "")
        $lookupId = $id.ToLowerInvariant()
        $resolved = Resolve-KitSoftwareState -SoftwareItem $item -FixtureState $softwareMap[$lookupId] -CurrentState $currentSoftwareMap[$lookupId]
        $itemActions = @()

        switch ($resolved.installMode) {
            "manual" {
                $itemActions += New-KitEnsureStateAction -Kind "software" -Target $resolved.id -Operation "manual-review" -Mode "manual" -Reason "installMode=manual"
                $resolved.status = "manual"
            }
            "disabled" {
                if ($resolved.status -ne "matched") {
                    $itemActions += New-KitEnsureStateAction -Kind "software" -Target $resolved.id -Operation "no-op" -Mode "disabled" -Reason "installMode=disabled"
                    $resolved.status = "manual"
                }
            }
            default {
                switch ($resolved.desiredEnsure) {
                    "present" {
                        if ($resolved.currentEnsure -eq "absent") {
                            $itemActions += New-KitEnsureStateAction -Kind "software" -Target $resolved.id -Operation "install" -Mode "planned" -Reason "desired present but current absent"
                            $resolved.status = "drift"
                        }
                    }
                    "absent" {
                        if ($resolved.currentEnsure -eq "present") {
                            $itemActions += New-KitEnsureStateAction -Kind "software" -Target $resolved.id -Operation "uninstall" -Mode "planned" -Reason "desired absent but current present"
                            $resolved.status = "drift"
                        }
                    }
                    "latest" {
                        if ($resolved.currentEnsure -eq "absent") {
                            $itemActions += New-KitEnsureStateAction -Kind "software" -Target $resolved.id -Operation "install-latest" -Mode "planned" -Reason "desired latest but current absent"
                        } else {
                            $itemActions += New-KitEnsureStateAction -Kind "software" -Target $resolved.id -Operation "verify-latest-version" -Mode "manual" -Reason "latest requires explicit version evidence"
                        }
                        $resolved.status = "manual"
                    }
                    "pinned" {
                        if ($resolved.status -ne "matched") {
                            $itemActions += New-KitEnsureStateAction -Kind "software" -Target $resolved.id -Operation "verify-pinned-version" -Mode "manual" -Reason "pinned requires explicit version match"
                            $resolved.status = "manual"
                        }
                    }
                    "manual" {
                        $itemActions += New-KitEnsureStateAction -Kind "software" -Target $resolved.id -Operation "manual-review" -Mode "manual" -Reason "desired ensure is manual"
                        $resolved.status = "manual"
                    }
                }
            }
        }

        $resolved.actions = @($itemActions)
        $softwareStates += $resolved
        $actions += @($itemActions)
        $warnings += @($resolved.warnings)
        $errors += @($resolved.errors)
    }

    foreach ($item in @($ServicesManifest.services)) {
        $name = [string](Get-KitEnsureStateProperty -InputObject $item -Name "name" -DefaultValue "")
        $lookupName = $name.ToLowerInvariant()
        $resolved = Resolve-KitServiceState -ServiceItem $item -FixtureState $serviceMap[$lookupName] -CurrentState $currentServiceMap[$lookupName]
        $itemActions = @()

        switch ($resolved.changeMode) {
            "manual" {
                $itemActions += New-KitEnsureStateAction -Kind "service" -Target $resolved.name -Operation "manual-review" -Mode "manual" -Reason "changeMode=manual"
                $resolved.status = "manual"
            }
            "disabled" {
                if ($resolved.status -ne "matched") {
                    $itemActions += New-KitEnsureStateAction -Kind "service" -Target $resolved.name -Operation "no-op" -Mode "disabled" -Reason "changeMode=disabled"
                    $resolved.status = "manual"
                }
            }
            default {
                switch ($resolved.desiredEnsure) {
                    "running" {
                        if ($resolved.currentEnsure -eq "stopped") {
                            $itemActions += New-KitEnsureStateAction -Kind "service" -Target $resolved.name -Operation "service-start" -Mode "planned" -Reason "desired running but current stopped"
                            $resolved.status = "drift"
                        } elseif ($resolved.currentEnsure -eq "absent") {
                            $itemActions += New-KitEnsureStateAction -Kind "service" -Target $resolved.name -Operation "service-restore" -Mode "manual" -Reason "service is absent and requires manual restoration"
                            $resolved.status = "manual"
                        }
                    }
                    "stopped" {
                        if ($resolved.currentEnsure -eq "running") {
                            $itemActions += New-KitEnsureStateAction -Kind "service" -Target $resolved.name -Operation "service-stop" -Mode "planned" -Reason "desired stopped but current running"
                            $resolved.status = "drift"
                        }
                    }
                    "absent" {
                        if ($resolved.currentEnsure -ne "absent" -and $resolved.currentEnsure -ne "unknown") {
                            $itemActions += New-KitEnsureStateAction -Kind "service" -Target $resolved.name -Operation "service-remove" -Mode "planned" -Reason "desired absent but service still exists"
                            $resolved.status = "drift"
                        }
                    }
                    "disabled" {
                        if ($resolved.currentStartupType -ne "disabled") {
                            $itemActions += New-KitEnsureStateAction -Kind "service" -Target $resolved.name -Operation "service-disable" -Mode "planned" -Reason "desired disabled startup type"
                            $resolved.status = "drift"
                        }
                    }
                    "manual" {
                        $itemActions += New-KitEnsureStateAction -Kind "service" -Target $resolved.name -Operation "manual-review" -Mode "manual" -Reason "desired ensure is manual"
                        $resolved.status = "manual"
                    }
                    "ignore" {
                        $itemActions += New-KitEnsureStateAction -Kind "service" -Target $resolved.name -Operation "ignore-drift" -Mode "manual" -Reason "desired ensure is ignore"
                        $resolved.status = "manual"
                    }
                }

                if ($resolved.desiredStartupType -and
                    $resolved.desiredStartupType -ne "unchanged" -and
                    $resolved.currentEnsure -ne "unknown" -and
                    $resolved.currentStartupType -ne $resolved.desiredStartupType) {
                    $itemActions += New-KitEnsureStateAction -Kind "service" -Target $resolved.name -Operation "service-change-startup-type" -Mode "planned" -Reason "startupType drift detected"
                    if ($resolved.status -eq "matched") {
                        $resolved.status = "drift"
                    }
                }
            }
        }

        $resolved.actions = @($itemActions)
        $serviceStates += $resolved
        $actions += @($itemActions)
        $warnings += @($resolved.warnings)
        $errors += @($resolved.errors)
    }

    [pscustomobject][ordered]@{
        planType = "ensure-state"
        generatedAt = (Get-Date).ToString("s")
        whatIf = [bool]$WhatIf
        software = @($softwareStates)
        services = @($serviceStates)
        actions = @($actions)
        warnings = @($warnings | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        errors = @($errors | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
}
