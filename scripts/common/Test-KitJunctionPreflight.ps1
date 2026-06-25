#Requires -Version 5.1

. "$PSScriptRoot\Test-KitJunctionState.ps1"

function Get-KitJunctionPolicy {
    param(
        [AllowNull()]
        $JunctionConfig,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$DefaultValue
    )

    $value = [string](Get-KitJunctionConfigProperty -JunctionConfig $JunctionConfig -Name $Name -DefaultValue $DefaultValue)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }

    return $value
}

function Normalize-KitJunctionPathForCompare {
    param(
        [AllowNull()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path).Replace([IO.Path]::AltDirectorySeparatorChar, [IO.Path]::DirectorySeparatorChar)
    try {
        $expanded = [IO.Path]::GetFullPath($expanded)
    } catch {
        $expanded = $expanded.Trim()
    }

    $trimChars = @([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    return $expanded.TrimEnd($trimChars)
}

function Test-KitJunctionPathRelation {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Target
    )

    $sourcePath = Normalize-KitJunctionPathForCompare -Path $Source
    $targetPath = Normalize-KitJunctionPathForCompare -Path $Target

    if ([string]::IsNullOrWhiteSpace($sourcePath) -or [string]::IsNullOrWhiteSpace($targetPath)) {
        return [pscustomobject]@{
            samePath = $false
            parentChild = $false
            relation = "unknown"
        }
    }

    if ([string]::Equals($sourcePath, $targetPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{
            samePath = $true
            parentChild = $false
            relation = "same-path"
        }
    }

    $sourcePrefix = $sourcePath + [IO.Path]::DirectorySeparatorChar
    $targetPrefix = $targetPath + [IO.Path]::DirectorySeparatorChar
    if ($targetPath.StartsWith($sourcePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{
            samePath = $false
            parentChild = $true
            relation = "target-under-source"
        }
    }

    if ($sourcePath.StartsWith($targetPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{
            samePath = $false
            parentChild = $true
            relation = "source-under-target"
        }
    }

    [pscustomobject]@{
        samePath = $false
        parentChild = $false
        relation = "separate"
    }
}

function Test-KitJunctionDriveRoot {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $qualifier = Split-Path -Path $Path -Qualifier
    if ([string]::IsNullOrWhiteSpace($qualifier)) {
        return $true
    }

    return Test-Path -LiteralPath ("{0}\" -f $qualifier)
}

function Get-KitJunctionAvailableBytes {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $qualifier = Split-Path -Path $Path -Qualifier
    if ([string]::IsNullOrWhiteSpace($qualifier)) {
        return $null
    }

    $driveName = $qualifier.TrimEnd(":")
    try {
        $drive = Get-PSDrive -Name $driveName -ErrorAction Stop
        return [Nullable[Int64]]$drive.Free
    } catch {
        return $null
    }
}

function Get-KitDirectorySizeBytes {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $total = [Int64]0
        Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction Stop | ForEach-Object {
            $total += [Int64]$_.Length
        }

        return $total
    } catch {
        return $null
    }
}

function Get-KitJunctionPathState {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            exists = $false
            isDirectory = $false
            isJunction = $false
            isEmpty = $null
            target = ""
            linkType = ""
            attributes = ""
            sizeBytes = 0
        }
    }

    $item = Get-Item -LiteralPath $Path -Force
    $attributes = $item.Attributes
    $isDirectory = [bool]$item.PSIsContainer
    $isReparsePoint = (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
    $linkType = [string](Get-KitJunctionConfigProperty -JunctionConfig $item -Name "LinkType" -DefaultValue "")
    $target = ConvertTo-KitJunctionTargetText -Value (Get-KitJunctionConfigProperty -JunctionConfig $item -Name "Target" -DefaultValue "")
    $isJunction = $linkType -eq "Junction"
    if (-not $isJunction -and [string]::IsNullOrWhiteSpace($linkType) -and $isReparsePoint -and -not [string]::IsNullOrWhiteSpace($target)) {
        $isJunction = $true
    }

    $isEmpty = $null
    $sizeBytes = $null
    if ($isDirectory -and -not $isJunction) {
        $firstChild = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop | Select-Object -First 1)
        $isEmpty = ($firstChild.Count -eq 0)
        $sizeBytes = Get-KitDirectorySizeBytes -Path $Path
    }

    [pscustomobject]@{
        exists = $true
        isDirectory = $isDirectory
        isJunction = [bool]$isJunction
        isEmpty = $isEmpty
        target = $target
        linkType = $linkType
        attributes = [string]$attributes
        sizeBytes = $sizeBytes
    }
}

function New-KitDataJunctionPreflightResult {
    param(
        [Parameter(Mandatory)]
        $JunctionConfig,

        [Parameter(Mandatory)]
        [ValidateSet("changed", "unchanged", "skipped", "manual", "whatif", "failed")]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Reason,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$PlanAction,

        [AllowNull()]
        $SourceState = $null,

        [AllowNull()]
        $TargetState = $null,

        [AllowNull()]
        $Evidence = $null,

        [AllowNull()]
        $Warnings = @(),

        [AllowNull()]
        $Errors = @(),

        [datetime]$StartedAt = (Get-Date)
    )

    $source = Get-KitJunctionPath -JunctionConfig $JunctionConfig
    $target = Get-KitJunctionExpectedTarget -JunctionConfig $JunctionConfig
    $required = Get-KitJunctionRequired -JunctionConfig $JunctionConfig
    $failurePolicy = Get-KitJunctionFailurePolicy -JunctionConfig $JunctionConfig
    $onTargetConflict = Get-KitJunctionPolicy -JunctionConfig $JunctionConfig -Name "onTargetConflict" -DefaultValue "fail"
    $backupRetention = Get-KitJunctionPolicy -JunctionConfig $JunctionConfig -Name "backupRetention" -DefaultValue "keep"
    $verificationMode = Get-KitJunctionPolicy -JunctionConfig $JunctionConfig -Name "verificationMode" -DefaultValue "countAndSize"

    $stepResult = New-KitStepResult `
        -Name (Get-KitJunctionName -JunctionConfig $JunctionConfig) `
        -Required:$required `
        -Status $Status `
        -Message $Message `
        -Reason $Reason `
        -Data ([pscustomobject]@{
            junctionPath = $source
            expectedTarget = $target
            planAction = $PlanAction
            sourceState = $SourceState
            targetState = $TargetState
            failurePolicy = $failurePolicy
            onTargetConflict = $onTargetConflict
            backupRetention = $backupRetention
            verificationMode = $verificationMode
        }) `
        -Evidence $Evidence `
        -Warnings $Warnings `
        -Errors $Errors `
        -WhatIfResult:($Status -eq "whatif") `
        -StartedAt $StartedAt `
        -EndedAt (Get-Date)

    [pscustomobject][ordered]@{
        name = $stepResult.name
        junctionPath = $source
        expectedTarget = $target
        actualTarget = if ($null -ne $SourceState) { [string](Get-KitJunctionConfigProperty -JunctionConfig $SourceState -Name "target" -DefaultValue "") } else { "" }
        exists = if ($null -ne $SourceState) { [bool](Get-KitJunctionConfigProperty -JunctionConfig $SourceState -Name "exists" -DefaultValue $false) } else { $false }
        isJunction = if ($null -ne $SourceState) { [bool](Get-KitJunctionConfigProperty -JunctionConfig $SourceState -Name "isJunction" -DefaultValue $false) } else { $false }
        linkType = if ($null -ne $SourceState) { [string](Get-KitJunctionConfigProperty -JunctionConfig $SourceState -Name "linkType" -DefaultValue "") } else { "" }
        attributes = if ($null -ne $SourceState) { [string](Get-KitJunctionConfigProperty -JunctionConfig $SourceState -Name "attributes" -DefaultValue "") } else { "" }
        required = $stepResult.required
        status = $stepResult.status
        changed = $stepResult.changed
        reason = $stepResult.reason
        message = $stepResult.message
        planAction = $PlanAction
        failurePolicy = $failurePolicy
        onTargetConflict = $onTargetConflict
        backupRetention = $backupRetention
        verificationMode = $verificationMode
        sourceState = $SourceState
        targetState = $TargetState
        evidence = $stepResult.evidence
        warnings = $stepResult.warnings
        errors = $stepResult.errors
        skippedReason = $stepResult.skippedReason
        manualAction = $stepResult.manualAction
        whatIf = $stepResult.whatIf
        startedAt = $stepResult.startedAt
        endedAt = $stepResult.endedAt
    }
}

function New-KitDataJunctionBlockingPreflightResult {
    param(
        [Parameter(Mandatory)]
        $JunctionConfig,

        [Parameter(Mandatory)]
        [string]$Reason,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$PlanAction,

        [AllowNull()]
        $SourceState = $null,

        [AllowNull()]
        $TargetState = $null,

        [AllowNull()]
        $Errors = @(),

        [datetime]$StartedAt = (Get-Date)
    )

    $status = Resolve-KitJunctionFailureStatus -Required (Get-KitJunctionRequired -JunctionConfig $JunctionConfig) -FailurePolicy (Get-KitJunctionFailurePolicy -JunctionConfig $JunctionConfig)
    New-KitDataJunctionPreflightResult -JunctionConfig $JunctionConfig -Status $status -Reason $Reason -Message $Message -PlanAction $PlanAction -SourceState $SourceState -TargetState $TargetState -Errors $Errors -StartedAt $StartedAt
}

function Test-KitDataJunctionPreflight {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $JunctionConfig,

        [scriptblock]$StateQuery = $null,

        [scriptblock]$TargetAvailableBytesQuery = $null,

        [switch]$WhatIf
    )

    $startedAt = Get-Date
    $source = Get-KitJunctionPath -JunctionConfig $JunctionConfig
    $target = Get-KitJunctionExpectedTarget -JunctionConfig $JunctionConfig
    $onTargetConflict = Get-KitJunctionPolicy -JunctionConfig $JunctionConfig -Name "onTargetConflict" -DefaultValue "fail"

    if ($onTargetConflict -eq "merge") {
        return New-KitDataJunctionBlockingPreflightResult -JunctionConfig $JunctionConfig -Reason "junction-merge-not-supported" -Message "Junction target merge policy is not implemented for transaction migration" -PlanAction "block" -Errors @("onTargetConflict=merge requires a separately designed no-clobber merge flow") -StartedAt $startedAt
    }

    $relation = Test-KitJunctionPathRelation -Source $source -Target $target
    if ($relation.samePath -or $relation.parentChild) {
        return New-KitDataJunctionBlockingPreflightResult -JunctionConfig $JunctionConfig -Reason "junction-path-cycle-risk" -Message "Junction source and target paths have an unsafe relationship" -PlanAction "block" -Errors @("relation=$($relation.relation) source=$source target=$target") -StartedAt $startedAt
    }

    $query = $StateQuery
    if ($null -eq $query) {
        $query = {
            param(
                [string]$Path,
                [string]$Role,
                [AllowNull()]
                $JunctionConfig
            )

            Get-KitJunctionPathState -Path $Path
        }
    }

    try {
        $sourceState = & $query -Path $source -Role "source" -JunctionConfig $JunctionConfig
        $targetState = & $query -Path $target -Role "target" -JunctionConfig $JunctionConfig
    } catch {
        return New-KitDataJunctionBlockingPreflightResult -JunctionConfig $JunctionConfig -Reason "junction-preflight-query-failed" -Message "Junction preflight state query failed" -PlanAction "block" -Errors @($_.Exception.Message) -StartedAt $startedAt
    }

    $sourceExists = [bool](Get-KitJunctionConfigProperty -JunctionConfig $sourceState -Name "exists" -DefaultValue $false)
    $sourceIsDirectory = [bool](Get-KitJunctionConfigProperty -JunctionConfig $sourceState -Name "isDirectory" -DefaultValue $false)
    $sourceIsJunction = [bool](Get-KitJunctionConfigProperty -JunctionConfig $sourceState -Name "isJunction" -DefaultValue $false)
    $sourceActualTarget = ConvertTo-KitJunctionTargetText -Value (Get-KitJunctionConfigProperty -JunctionConfig $sourceState -Name "target" -DefaultValue "")
    $targetExists = [bool](Get-KitJunctionConfigProperty -JunctionConfig $targetState -Name "exists" -DefaultValue $false)
    $targetIsDirectory = [bool](Get-KitJunctionConfigProperty -JunctionConfig $targetState -Name "isDirectory" -DefaultValue $false)
    $targetIsEmpty = Get-KitJunctionConfigProperty -JunctionConfig $targetState -Name "isEmpty" -DefaultValue $null
    $sourceSizeBytes = Get-KitJunctionConfigProperty -JunctionConfig $sourceState -Name "sizeBytes" -DefaultValue $null

    if ($sourceExists -and $sourceIsJunction) {
        if (Test-KitJunctionTargetMatch -ActualTarget $sourceActualTarget -ExpectedTarget $target) {
            return New-KitDataJunctionPreflightResult -JunctionConfig $JunctionConfig -Status "unchanged" -Reason "junction-state-ok" -Message "Junction already points to expected target" -PlanAction "unchanged" -SourceState $sourceState -TargetState $targetState -StartedAt $startedAt
        }

        return New-KitDataJunctionBlockingPreflightResult -JunctionConfig $JunctionConfig -Reason "junction-target-mismatch" -Message "Existing junction points to a different target" -PlanAction "block" -SourceState $sourceState -TargetState $targetState -Errors @("expectedTarget=$target actualTarget=$sourceActualTarget") -StartedAt $startedAt
    }

    if ($sourceExists -and -not $sourceIsDirectory) {
        return New-KitDataJunctionBlockingPreflightResult -JunctionConfig $JunctionConfig -Reason "junction-source-not-directory" -Message "Source path exists but is not a directory" -PlanAction "block" -SourceState $sourceState -TargetState $targetState -Errors @("source is not directory: $source") -StartedAt $startedAt
    }

    if ($targetExists -and -not $targetIsDirectory) {
        return New-KitDataJunctionBlockingPreflightResult -JunctionConfig $JunctionConfig -Reason "junction-target-not-directory" -Message "Target path exists but is not a directory" -PlanAction "block" -SourceState $sourceState -TargetState $targetState -Errors @("target is not directory: $target") -StartedAt $startedAt
    }

    if (-not $targetExists) {
        $parent = Split-Path -Path $target -Parent
        $parentAvailable = $false
        if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent)) {
            $parentAvailable = $true
        } elseif (Test-KitJunctionDriveRoot -Path $target) {
            $parentAvailable = $true
        }

        if (-not $parentAvailable) {
            return New-KitDataJunctionBlockingPreflightResult -JunctionConfig $JunctionConfig -Reason "junction-target-parent-unavailable" -Message "Target parent directory or drive is unavailable" -PlanAction "block" -SourceState $sourceState -TargetState $targetState -Errors @("target parent or drive unavailable: $target") -StartedAt $startedAt
        }
    }

    if ($targetExists -and $targetIsEmpty -eq $false -and $onTargetConflict -eq "fail") {
        return New-KitDataJunctionBlockingPreflightResult -JunctionConfig $JunctionConfig -Reason "junction-target-conflict" -Message "Target path is non-empty and conflict policy is fail" -PlanAction "block" -SourceState $sourceState -TargetState $targetState -Errors @("target is non-empty: $target") -StartedAt $startedAt
    }

    $availableBytes = $null
    if ($null -ne $TargetAvailableBytesQuery) {
        $availableBytes = & $TargetAvailableBytesQuery -Path $target -JunctionConfig $JunctionConfig
    } else {
        $availableBytes = Get-KitJunctionAvailableBytes -Path $target
    }

    if ($null -ne $sourceSizeBytes -and $null -ne $availableBytes -and [Int64]$sourceSizeBytes -gt [Int64]$availableBytes) {
        return New-KitDataJunctionBlockingPreflightResult -JunctionConfig $JunctionConfig -Reason "junction-target-space-insufficient" -Message "Target drive does not have enough free space for source data estimate" -PlanAction "block" -SourceState $sourceState -TargetState $targetState -Errors @("sourceBytes=$sourceSizeBytes availableBytes=$availableBytes") -StartedAt $startedAt
    }

    $planAction = if ($sourceExists) { "migrate-directory" } else { "create-target-and-junction" }
    $status = if ($WhatIf) { "whatif" } else { "changed" }
    $message = if ($WhatIf) { "WhatIf plan only; no target creation, copy, delete, robocopy, or mklink will run" } else { "Junction preflight passed; migration can proceed" }
    New-KitDataJunctionPreflightResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-migration-planned" -Message $message -PlanAction $planAction -SourceState $sourceState -TargetState $targetState -Evidence ([pscustomobject]@{ sourceBytes = $sourceSizeBytes; availableBytes = $availableBytes }) -StartedAt $startedAt
}
