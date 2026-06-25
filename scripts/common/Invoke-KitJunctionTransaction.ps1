#Requires -Version 5.1

. "$PSScriptRoot\Test-KitJunctionState.ps1"

function Get-KitJunctionPolicyValue {
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

    return $value.ToLowerInvariant()
}

function Get-KitDirectoryCountAndSize {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            fileCount = 0
            bytes = 0
        }
    }

    $fileCount = 0
    $bytes = [Int64]0
    Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction Stop | ForEach-Object {
        $fileCount++
        $bytes += [Int64]$_.Length
    }

    [pscustomobject]@{
        fileCount = [int]$fileCount
        bytes = [Int64]$bytes
    }
}

function New-KitJunctionBackupPath {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [datetime]$Timestamp = (Get-Date)
    )

    $stamp = $Timestamp.ToString("yyyyMMdd-HHmmss")
    $candidate = "{0}.kit-backup-{1}" -f $Source, $stamp
    if (-not (Test-Path -LiteralPath $candidate)) {
        return $candidate
    }

    return "{0}-{1}" -f $candidate, ([guid]::NewGuid().ToString("N").Substring(0, 8))
}

function New-KitDataJunctionTransactionResult {
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

        [Parameter(Mandatory)]
        [string]$TransactionStage,

        [AllowNull()]
        $SourceState = $null,

        [AllowNull()]
        $TargetState = $null,

        [AllowNull()]
        $SourceStats = $null,

        [AllowNull()]
        $TargetStats = $null,

        [AllowNull()]
        [Nullable[int]]$RobocopyExitCode = $null,

        [AllowEmptyString()]
        [string]$BackupPath = "",

        [AllowNull()]
        [Nullable[int]]$MklinkExitCode = $null,

        [AllowEmptyString()]
        [string]$VerifiedTarget = "",

        [bool]$RollbackAttempted = $false,

        [bool]$RollbackSucceeded = $false,

        [AllowEmptyString()]
        [string]$ManualRecoveryHint = "",

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
    $onTargetConflict = Get-KitJunctionPolicyValue -JunctionConfig $JunctionConfig -Name "onTargetConflict" -DefaultValue "fail"
    $backupRetention = Get-KitJunctionPolicyValue -JunctionConfig $JunctionConfig -Name "backupRetention" -DefaultValue "keep"
    $verificationMode = Get-KitJunctionPolicyValue -JunctionConfig $JunctionConfig -Name "verificationMode" -DefaultValue "countAndSize"

    $sourceFileCount = if ($null -ne $SourceStats) { [int](Get-KitJunctionConfigProperty -JunctionConfig $SourceStats -Name "fileCount" -DefaultValue 0) } else { 0 }
    $sourceBytes = if ($null -ne $SourceStats) { [Int64](Get-KitJunctionConfigProperty -JunctionConfig $SourceStats -Name "bytes" -DefaultValue 0) } else { [Int64]0 }
    $targetFileCount = if ($null -ne $TargetStats) { [int](Get-KitJunctionConfigProperty -JunctionConfig $TargetStats -Name "fileCount" -DefaultValue 0) } else { 0 }
    $targetBytes = if ($null -ne $TargetStats) { [Int64](Get-KitJunctionConfigProperty -JunctionConfig $TargetStats -Name "bytes" -DefaultValue 0) } else { [Int64]0 }

    $data = [pscustomobject]@{
        junctionPath = $source
        expectedTarget = $target
        planAction = $PlanAction
        transactionStage = $TransactionStage
        sourceState = $SourceState
        targetState = $TargetState
        sourceFileCount = $sourceFileCount
        sourceBytes = $sourceBytes
        targetFileCount = $targetFileCount
        targetBytes = $targetBytes
        robocopyExitCode = $RobocopyExitCode
        backupPath = $BackupPath
        mklinkExitCode = $MklinkExitCode
        verifiedTarget = $VerifiedTarget
        backupRetention = $backupRetention
        rollbackAttempted = [bool]$RollbackAttempted
        rollbackSucceeded = [bool]$RollbackSucceeded
        manualRecoveryHint = $ManualRecoveryHint
        failurePolicy = $failurePolicy
        onTargetConflict = $onTargetConflict
        verificationMode = $verificationMode
    }

    $stepResult = New-KitStepResult `
        -Name (Get-KitJunctionName -JunctionConfig $JunctionConfig) `
        -Required:$required `
        -Status $Status `
        -Message $Message `
        -Reason $Reason `
        -Data $data `
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
        actualTarget = $VerifiedTarget
        exists = if ($Status -eq "changed" -or $Status -eq "unchanged") { $true } else { $false }
        isJunction = if ($Status -eq "changed" -or $Status -eq "unchanged") { $true } else { $false }
        linkType = if ($Status -eq "changed" -or $Status -eq "unchanged") { "Junction" } else { "" }
        attributes = ""
        required = $stepResult.required
        status = $stepResult.status
        changed = $stepResult.changed
        reason = $stepResult.reason
        message = $stepResult.message
        planAction = $PlanAction
        transactionStage = $TransactionStage
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
        data = $stepResult.data
        startedAt = $stepResult.startedAt
        endedAt = $stepResult.endedAt
    }
}

function Invoke-KitDataJunctionTransaction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $JunctionConfig,

        [AllowNull()]
        $PreflightResult = $null,

        [scriptblock]$CopyDirectory = $null,

        [scriptblock]$GetDirectoryStats = $null,

        [scriptblock]$CreateDirectory = $null,

        [scriptblock]$RenameSourceToBackup = $null,

        [scriptblock]$CreateJunction = $null,

        [scriptblock]$RemoveBackup = $null,

        [scriptblock]$PathExists = $null,

        [scriptblock]$JunctionQuery = $null,

        [switch]$WhatIf
    )

    $startedAt = Get-Date
    $source = Get-KitJunctionPath -JunctionConfig $JunctionConfig
    $target = Get-KitJunctionExpectedTarget -JunctionConfig $JunctionConfig
    $required = Get-KitJunctionRequired -JunctionConfig $JunctionConfig
    $failurePolicy = Get-KitJunctionFailurePolicy -JunctionConfig $JunctionConfig
    $backupRetention = Get-KitJunctionPolicyValue -JunctionConfig $JunctionConfig -Name "backupRetention" -DefaultValue "keep"

    $planAction = if ($null -ne $PreflightResult -and $null -ne $PreflightResult.PSObject.Properties["planAction"]) { [string]$PreflightResult.planAction } else { "migrate-directory" }
    $sourceState = if ($null -ne $PreflightResult -and $null -ne $PreflightResult.PSObject.Properties["sourceState"]) { $PreflightResult.sourceState } else { $null }
    $targetState = if ($null -ne $PreflightResult -and $null -ne $PreflightResult.PSObject.Properties["targetState"]) { $PreflightResult.targetState } else { $null }

    if ($null -ne $PreflightResult) {
        $preflightStatus = [string]$PreflightResult.status
        if ($preflightStatus -eq "unchanged") {
            return $PreflightResult
        }

        if ($preflightStatus -ne "changed" -and $preflightStatus -ne "whatif") {
            return $PreflightResult
        }
    }

    $plannedSteps = @("create-target", "copy", "verify-count-and-size", "rename-source-to-backup", "create-junction", "verify-junction", "apply-backup-retention")
    if ($WhatIf -or ($null -ne $PreflightResult -and [string]$PreflightResult.status -eq "whatif")) {
        return New-KitDataJunctionTransactionResult `
            -JunctionConfig $JunctionConfig `
            -Status "whatif" `
            -Reason "junction-transaction-plan" `
            -Message "WhatIf plan only; no target creation, copy, source rename, junction creation, or backup removal will run" `
            -PlanAction $planAction `
            -TransactionStage "plan" `
            -SourceState $sourceState `
            -TargetState $targetState `
            -Evidence ([pscustomobject]@{ plannedSteps = $plannedSteps }) `
            -StartedAt $startedAt
    }

    if ($null -eq $CopyDirectory) {
        $CopyDirectory = {
            param([string]$Source, [string]$Target)
            robocopy $Source $Target /E /NJH /NJS /NFL /NDL | Out-Null
            return [int]$LASTEXITCODE
        }
    }

    if ($null -eq $GetDirectoryStats) {
        $GetDirectoryStats = {
            param([string]$Path)
            Get-KitDirectoryCountAndSize -Path $Path
        }
    }

    if ($null -eq $CreateDirectory) {
        $CreateDirectory = {
            param([string]$Path)
            New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
        }
    }

    if ($null -eq $RenameSourceToBackup) {
        $RenameSourceToBackup = {
            param([string]$Source, [string]$BackupPath)
            Rename-Item -LiteralPath $Source -NewName (Split-Path -Path $BackupPath -Leaf) -ErrorAction Stop
        }
    }

    if ($null -eq $CreateJunction) {
        $CreateJunction = {
            param([string]$Source, [string]$Target)
            cmd.exe /c "mklink /J `"$Source`" `"$Target`"" | Out-Null
            return [int]$LASTEXITCODE
        }
    }

    if ($null -eq $RemoveBackup) {
        $RemoveBackup = {
            param([string]$BackupPath)
            Remove-Item -LiteralPath $BackupPath -Recurse -Force -ErrorAction Stop
        }
    }

    if ($null -eq $PathExists) {
        $PathExists = {
            param([string]$Path)
            return [bool](Test-Path -LiteralPath $Path)
        }
    }

    $sourceExists = $true
    if ($null -ne $sourceState) {
        $sourceExists = [bool](Get-KitJunctionConfigProperty -JunctionConfig $sourceState -Name "exists" -DefaultValue $true)
    }

    $sourceStats = [pscustomobject]@{ fileCount = 0; bytes = [Int64]0 }
    $targetStats = [pscustomobject]@{ fileCount = 0; bytes = [Int64]0 }
    $backupPath = ""
    $robocopyExitCode = $null
    $mklinkExitCode = $null
    $rollbackAttempted = $false
    $rollbackSucceeded = $false
    $warnings = @()

    try {
        & $CreateDirectory -Path $target
    } catch {
        $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
        return New-KitDataJunctionTransactionResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-target-create-failed" -Message "Failed to create Junction target directory" -PlanAction $planAction -TransactionStage "create-target" -SourceState $sourceState -TargetState $targetState -Errors @($_.Exception.Message) -StartedAt $startedAt
    }

    if ($sourceExists) {
        try {
            $sourceStats = & $GetDirectoryStats -Path $source
        } catch {
            $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
            return New-KitDataJunctionTransactionResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-source-stat-failed" -Message "Failed to calculate source countAndSize" -PlanAction $planAction -TransactionStage "source-stat" -SourceState $sourceState -TargetState $targetState -Errors @($_.Exception.Message) -StartedAt $startedAt
        }

        try {
            $robocopyExitCode = [int](& $CopyDirectory -Source $source -Target $target)
        } catch {
            $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
            return New-KitDataJunctionTransactionResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-copy-failed" -Message "Copy-first Junction migration failed before source rename" -PlanAction $planAction -TransactionStage "copy" -SourceState $sourceState -TargetState $targetState -SourceStats $sourceStats -RobocopyExitCode $robocopyExitCode -Errors @($_.Exception.Message) -StartedAt $startedAt
        }

        if ($robocopyExitCode -ge 8) {
            $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
            return New-KitDataJunctionTransactionResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-copy-failed" -Message "robocopy copy failed; source directory was not renamed" -PlanAction $planAction -TransactionStage "copy" -SourceState $sourceState -TargetState $targetState -SourceStats $sourceStats -RobocopyExitCode $robocopyExitCode -Errors @("robocopyExitCode=$robocopyExitCode") -StartedAt $startedAt
        }

        if ($robocopyExitCode -gt 0) {
            $warnings += "robocopyExitCode=$robocopyExitCode"
        }

        try {
            $targetStats = & $GetDirectoryStats -Path $target
        } catch {
            $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
            return New-KitDataJunctionTransactionResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-target-stat-failed" -Message "Failed to calculate target countAndSize after copy" -PlanAction $planAction -TransactionStage "verify-copy" -SourceState $sourceState -TargetState $targetState -SourceStats $sourceStats -RobocopyExitCode $robocopyExitCode -Errors @($_.Exception.Message) -StartedAt $startedAt
        }

        $sourceFileCount = [int](Get-KitJunctionConfigProperty -JunctionConfig $sourceStats -Name "fileCount" -DefaultValue 0)
        $targetFileCount = [int](Get-KitJunctionConfigProperty -JunctionConfig $targetStats -Name "fileCount" -DefaultValue 0)
        $sourceBytes = [Int64](Get-KitJunctionConfigProperty -JunctionConfig $sourceStats -Name "bytes" -DefaultValue 0)
        $targetBytes = [Int64](Get-KitJunctionConfigProperty -JunctionConfig $targetStats -Name "bytes" -DefaultValue 0)
        if ($sourceFileCount -ne $targetFileCount -or $sourceBytes -ne $targetBytes) {
            $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
            $errorText = "expectedCount=$sourceFileCount actualCount=$targetFileCount expectedBytes=$sourceBytes actualBytes=$targetBytes"
            return New-KitDataJunctionTransactionResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-copy-verification-failed" -Message "countAndSize verification failed after copy; source directory was not renamed" -PlanAction $planAction -TransactionStage "verify-copy" -SourceState $sourceState -TargetState $targetState -SourceStats $sourceStats -TargetStats $targetStats -RobocopyExitCode $robocopyExitCode -Errors @($errorText) -StartedAt $startedAt
        }

        $backupPath = New-KitJunctionBackupPath -Source $source
        try {
            & $RenameSourceToBackup -Source $source -BackupPath $backupPath
        } catch {
            $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
            return New-KitDataJunctionTransactionResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-backup-rename-failed" -Message "Failed to rename source directory to backup; Junction was not created" -PlanAction $planAction -TransactionStage "backup-rename" -SourceState $sourceState -TargetState $targetState -SourceStats $sourceStats -TargetStats $targetStats -RobocopyExitCode $robocopyExitCode -BackupPath $backupPath -ManualRecoveryHint "Inspect source path and backup rename failure before retrying." -Errors @($_.Exception.Message) -StartedAt $startedAt
        }
    }

    $parent = Split-Path -Path $source -Parent
    try {
        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (& $PathExists -Path $parent)) {
            & $CreateDirectory -Path $parent
        }
    } catch {
        $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
        return New-KitDataJunctionTransactionResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-parent-create-failed" -Message "Failed to create Junction parent directory" -PlanAction $planAction -TransactionStage "create-parent" -SourceState $sourceState -TargetState $targetState -SourceStats $sourceStats -TargetStats $targetStats -RobocopyExitCode $robocopyExitCode -BackupPath $backupPath -Errors @($_.Exception.Message) -StartedAt $startedAt
    }

    try {
        $mklinkExitCode = [int](& $CreateJunction -Source $source -Target $target)
    } catch {
        $mklinkExitCode = $null
        $mklinkError = $_.Exception.Message
    }

    if ($null -eq $mklinkExitCode -or $mklinkExitCode -ne 0) {
        if (-not [string]::IsNullOrWhiteSpace($backupPath) -and -not (& $PathExists -Path $source)) {
            $rollbackAttempted = $true
            try {
                & $RenameSourceToBackup -Source $backupPath -BackupPath $source
                $rollbackSucceeded = $true
            } catch {
                $warnings += "rollback failed: $($_.Exception.Message)"
            }
        }

        $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
        $errors = @("mklinkExitCode=$mklinkExitCode")
        if (-not [string]::IsNullOrWhiteSpace($mklinkError)) {
            $errors += $mklinkError
        }

        return New-KitDataJunctionTransactionResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-mklink-failed" -Message "Junction creation failed; backup was preserved or rollback was attempted" -PlanAction $planAction -TransactionStage "mklink" -SourceState $sourceState -TargetState $targetState -SourceStats $sourceStats -TargetStats $targetStats -RobocopyExitCode $robocopyExitCode -BackupPath $backupPath -MklinkExitCode $mklinkExitCode -RollbackAttempted:$rollbackAttempted -RollbackSucceeded:$rollbackSucceeded -ManualRecoveryHint "If rollback did not succeed, restore the source path from backupPath manually." -Warnings $warnings -Errors $errors -StartedAt $startedAt
    }

    $verification = Test-KitJunctionState -JunctionConfig $JunctionConfig -JunctionQuery $JunctionQuery
    $verifiedTarget = [string](Get-KitJunctionConfigProperty -JunctionConfig $verification -Name "actualTarget" -DefaultValue "")
    if ([string]$verification.status -ne "unchanged") {
        $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
        $verificationErrors = @(ConvertTo-KitStepResultArray -Value $verification.errors)
        return New-KitDataJunctionTransactionResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-post-verify-failed" -Message "Junction was created but final target verification failed; backup was preserved" -PlanAction $planAction -TransactionStage "verify-junction" -SourceState $sourceState -TargetState $targetState -SourceStats $sourceStats -TargetStats $targetStats -RobocopyExitCode $robocopyExitCode -BackupPath $backupPath -MklinkExitCode $mklinkExitCode -VerifiedTarget $verifiedTarget -ManualRecoveryHint "Inspect the created junction and restore from backupPath if the target is wrong." -Warnings $warnings -Errors $verificationErrors -StartedAt $startedAt
    }

    if ($backupRetention -eq "delete" -and -not [string]::IsNullOrWhiteSpace($backupPath)) {
        try {
            & $RemoveBackup -BackupPath $backupPath
        } catch {
            $status = Resolve-KitJunctionFailureStatus -Required $required -FailurePolicy $failurePolicy
            return New-KitDataJunctionTransactionResult -JunctionConfig $JunctionConfig -Status $status -Reason "junction-backup-delete-failed" -Message "Junction verified, but backup retention delete failed" -PlanAction $planAction -TransactionStage "backup-retention" -SourceState $sourceState -TargetState $targetState -SourceStats $sourceStats -TargetStats $targetStats -RobocopyExitCode $robocopyExitCode -BackupPath $backupPath -MklinkExitCode $mklinkExitCode -VerifiedTarget $verifiedTarget -ManualRecoveryHint "Junction is verified; remove backupPath manually after confirming retention policy." -Warnings $warnings -Errors @($_.Exception.Message) -StartedAt $startedAt
        }
    }

    return New-KitDataJunctionTransactionResult -JunctionConfig $JunctionConfig -Status "changed" -Reason "junction-transaction-complete" -Message "Junction transaction completed and verified" -PlanAction $planAction -TransactionStage "complete" -SourceState $sourceState -TargetState $targetState -SourceStats $sourceStats -TargetStats $targetStats -RobocopyExitCode $robocopyExitCode -BackupPath $backupPath -MklinkExitCode $mklinkExitCode -VerifiedTarget $verifiedTarget -Warnings $warnings -StartedAt $startedAt
}
