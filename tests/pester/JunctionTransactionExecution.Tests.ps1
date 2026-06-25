$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Junction transaction execution" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Invoke-KitJunctionTransaction.ps1")

        $script:NewTransactionConfig = {
            param(
                [string]$Source = "C:\Source",
                [string]$Target = "D:\Data\Target",
                [string]$BackupRetention = "keep"
            )

            [pscustomobject]@{
                name = "PesterJunction"
                description = "PesterJunction"
                source = $Source
                target = $Target
                required = $true
                failurePolicy = "fail"
                onTargetConflict = "fail"
                backupRetention = $BackupRetention
                verificationMode = "countAndSize"
            }
        }

        $script:NewSourceState = {
            param(
                [bool]$Exists = $true
            )

            [pscustomobject]@{
                exists = $Exists
                isDirectory = $Exists
                isJunction = $false
                isEmpty = if ($Exists) { $false } else { $null }
                target = ""
                linkType = ""
                attributes = if ($Exists) { "Directory" } else { "" }
                sizeBytes = if ($Exists) { 10 } else { 0 }
            }
        }

        $script:NewTargetState = {
            [pscustomobject]@{
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

        $script:NewPreflightResult = {
            param(
                [string]$Status = "changed",
                [bool]$SourceExists = $true
            )

            [pscustomobject]@{
                status = $Status
                reason = "junction-migration-planned"
                planAction = if ($SourceExists) { "migrate-directory" } else { "create-target-and-junction" }
                sourceState = & $script:NewSourceState -Exists:$SourceExists
                targetState = & $script:NewTargetState
            }
        }

        $script:Stats = {
            param([string]$Path)
            [pscustomobject]@{ fileCount = 2; bytes = [Int64]10 }
        }

        $script:VerifyOk = {
            param([string]$Path, $JunctionConfig)
            [pscustomobject]@{ Exists = $true; IsJunction = $true; Target = "D:\Data\Target"; LinkType = "Junction"; Attributes = "Directory, ReparsePoint" }
        }
    }

    It "reports a WhatIf transaction plan without running mutating operations" {
        $operations = [ordered]@{ create = 0; copy = 0; rename = 0; mklink = 0; remove = 0 }
        $config = & $script:NewTransactionConfig

        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewPreflightResult) `
            -CreateDirectory { $operations.create++ } `
            -CopyDirectory { $operations.copy++; 0 } `
            -RenameSourceToBackup { $operations.rename++ } `
            -CreateJunction { $operations.mklink++; 0 } `
            -RemoveBackup { $operations.remove++ } `
            -WhatIf

        Assert-KitEqual $result.status "whatif"
        Assert-KitEqual $result.reason "junction-transaction-plan"
        Assert-KitEqual $result.data.transactionStage "plan"
        Assert-KitEqual $operations.create 0
        Assert-KitEqual $operations.copy 0
        Assert-KitEqual $operations.rename 0
        Assert-KitEqual $operations.mklink 0
        Assert-KitEqual $operations.remove 0
    }

    It "returns unchanged preflight results without copy, backup, or mklink" {
        $operations = [ordered]@{ copy = 0; rename = 0; mklink = 0 }
        $config = & $script:NewTransactionConfig
        $preflight = [pscustomobject]@{
            status = "unchanged"
            reason = "junction-state-ok"
            planAction = "unchanged"
            sourceState = & $script:NewSourceState
            targetState = & $script:NewTargetState
        }

        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult $preflight `
            -CopyDirectory { $operations.copy++; 0 } `
            -RenameSourceToBackup { $operations.rename++ } `
            -CreateJunction { $operations.mklink++; 0 }

        Assert-KitEqual $result.status "unchanged"
        Assert-KitEqual $operations.copy 0
        Assert-KitEqual $operations.rename 0
        Assert-KitEqual $operations.mklink 0
    }

    It "returns blocking preflight failures without copy, backup, or mklink" {
        $operations = [ordered]@{ copy = 0; rename = 0; mklink = 0 }
        $config = & $script:NewTransactionConfig
        $preflight = [pscustomobject]@{
            status = "failed"
            reason = "junction-target-mismatch"
            planAction = "block"
            sourceState = & $script:NewSourceState
            targetState = & $script:NewTargetState
        }

        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult $preflight `
            -CopyDirectory { $operations.copy++; 0 } `
            -RenameSourceToBackup { $operations.rename++ } `
            -CreateJunction { $operations.mklink++; 0 }

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-target-mismatch"
        Assert-KitEqual $operations.copy 0
        Assert-KitEqual $operations.rename 0
        Assert-KitEqual $operations.mklink 0
    }

    It "does not rename source or create a junction when copy fails" {
        $operations = [ordered]@{ rename = 0; mklink = 0 }
        $config = & $script:NewTransactionConfig

        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewPreflightResult) `
            -GetDirectoryStats $script:Stats `
            -CopyDirectory { 8 } `
            -RenameSourceToBackup { $operations.rename++ } `
            -CreateJunction { $operations.mklink++; 0 }

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-copy-failed"
        Assert-KitEqual $result.data.robocopyExitCode 8
        Assert-KitEqual $operations.rename 0
        Assert-KitEqual $operations.mklink 0
    }

    It "does not rename source or create a junction when countAndSize verification fails" {
        $operations = [ordered]@{ stats = 0; rename = 0; mklink = 0 }
        $config = & $script:NewTransactionConfig
        $stats = {
            param([string]$Path)
            $operations.stats++
            if ($operations.stats -eq 1) {
                return [pscustomobject]@{ fileCount = 2; bytes = [Int64]10 }
            }

            [pscustomobject]@{ fileCount = 1; bytes = [Int64]5 }
        }

        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewPreflightResult) `
            -GetDirectoryStats $stats `
            -CopyDirectory { 0 } `
            -RenameSourceToBackup { $operations.rename++ } `
            -CreateJunction { $operations.mklink++; 0 }

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-copy-verification-failed"
        Assert-KitEqual $result.data.sourceFileCount 2
        Assert-KitEqual $result.data.targetFileCount 1
        Assert-KitEqual $operations.rename 0
        Assert-KitEqual $operations.mklink 0
    }

    It "does not create a junction when backup rename fails" {
        $operations = [ordered]@{ mklink = 0 }
        $config = & $script:NewTransactionConfig

        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewPreflightResult) `
            -GetDirectoryStats $script:Stats `
            -CopyDirectory { 0 } `
            -RenameSourceToBackup { throw "rename failed" } `
            -CreateJunction { $operations.mklink++; 0 }

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-backup-rename-failed"
        Assert-KitMatch $result.errors[0] "rename failed"
        Assert-KitEqual $operations.mklink 0
    }

    It "preserves backup and attempts rollback when mklink fails" {
        $operations = [ordered]@{ rename = 0 }
        $config = & $script:NewTransactionConfig
        $rename = {
            param([string]$Source, [string]$BackupPath)
            $operations.rename++
        }

        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewPreflightResult) `
            -GetDirectoryStats $script:Stats `
            -CopyDirectory { 0 } `
            -RenameSourceToBackup $rename `
            -CreateJunction { 1 } `
            -PathExists { param([string]$Path) $Path -ne "C:\Source" }

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-mklink-failed"
        Assert-KitEqual $result.data.mklinkExitCode 1
        Assert-KitEqual $result.data.rollbackAttempted $true
        Assert-KitEqual $result.data.rollbackSucceeded $true
        Assert-KitEqual $operations.rename 2
    }

    It "preserves backup when final junction verification fails" {
        $config = & $script:NewTransactionConfig
        $verifyWrong = {
            param([string]$Path, $JunctionConfig)
            [pscustomobject]@{ Exists = $true; IsJunction = $true; Target = "D:\Data\Wrong"; LinkType = "Junction"; Attributes = "Directory, ReparsePoint" }
        }

        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewPreflightResult) `
            -GetDirectoryStats $script:Stats `
            -CopyDirectory { 0 } `
            -RenameSourceToBackup { } `
            -CreateJunction { 0 } `
            -JunctionQuery $verifyWrong

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-post-verify-failed"
        Assert-KitEqual $result.data.verifiedTarget "D:\Data\Wrong"
        Assert-KitNotNullOrEmpty $result.data.backupPath
    }

    It "keeps backup after a successful transaction by default" {
        $operations = [ordered]@{ remove = 0 }
        $config = & $script:NewTransactionConfig

        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewPreflightResult) `
            -GetDirectoryStats $script:Stats `
            -CopyDirectory { 0 } `
            -RenameSourceToBackup { } `
            -CreateJunction { 0 } `
            -RemoveBackup { $operations.remove++ } `
            -JunctionQuery $script:VerifyOk

        Assert-KitEqual $result.status "changed"
        Assert-KitEqual $result.reason "junction-transaction-complete"
        Assert-KitEqual $result.data.transactionStage "complete"
        Assert-KitEqual $result.data.verifiedTarget "D:\Data\Target"
        Assert-KitNotNullOrEmpty $result.data.backupPath
        Assert-KitEqual $operations.remove 0
    }

    It "deletes backup only after final verification when backupRetention is delete" {
        $operations = [ordered]@{ remove = 0 }
        $config = & $script:NewTransactionConfig -BackupRetention "delete"

        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewPreflightResult) `
            -GetDirectoryStats $script:Stats `
            -CopyDirectory { 0 } `
            -RenameSourceToBackup { } `
            -CreateJunction { 0 } `
            -RemoveBackup { $operations.remove++ } `
            -JunctionQuery $script:VerifyOk

        Assert-KitEqual $result.status "changed"
        Assert-KitEqual $operations.remove 1
    }

    It "reports backup retention delete failures after final verification" {
        $config = & $script:NewTransactionConfig -BackupRetention "delete"

        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewPreflightResult) `
            -GetDirectoryStats $script:Stats `
            -CopyDirectory { 0 } `
            -RenameSourceToBackup { } `
            -CreateJunction { 0 } `
            -RemoveBackup { throw "remove failed" } `
            -JunctionQuery $script:VerifyOk

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-backup-delete-failed"
        Assert-KitEqual $result.data.transactionStage "backup-retention"
        Assert-KitMatch $result.errors[0] "remove failed"
    }

    It "creates an empty target and junction when source does not exist" {
        $operations = [ordered]@{ copy = 0; rename = 0 }
        $config = & $script:NewTransactionConfig

        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewPreflightResult -SourceExists:$false) `
            -GetDirectoryStats $script:Stats `
            -CopyDirectory { $operations.copy++; 0 } `
            -RenameSourceToBackup { $operations.rename++ } `
            -CreateJunction { 0 } `
            -JunctionQuery $script:VerifyOk

        Assert-KitEqual $result.status "changed"
        Assert-KitEqual $result.planAction "create-target-and-junction"
        Assert-KitEqual $result.data.backupPath ""
        Assert-KitEqual $operations.copy 0
        Assert-KitEqual $operations.rename 0
    }
}
