$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Issue 7 Junction transaction acceptance guardrails" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitJunctionPreflight.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Invoke-KitJunctionTransaction.ps1")

        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $script:NewIssue7JunctionConfig = {
            param(
                [string]$Source = "C:\Source",
                [string]$Target = "D:\Data\Target",
                [string]$BackupRetention = "keep"
            )

            [pscustomobject]@{
                name = "Issue7Junction"
                description = "Issue7Junction"
                source = $Source
                target = $Target
                required = $true
                failurePolicy = "fail"
                onTargetConflict = "fail"
                backupRetention = $BackupRetention
                verificationMode = "countAndSize"
            }
        }

        $script:NewIssue7PathState = {
            param(
                [bool]$Exists = $false,
                [bool]$IsDirectory = $false,
                [bool]$IsJunction = $false,
                [AllowNull()]$IsEmpty = $null,
                [string]$Target = "",
                [string]$LinkType = "",
                [string]$Attributes = "",
                [AllowNull()]$SizeBytes = 0
            )

            [pscustomobject]@{
                exists = $Exists
                isDirectory = $IsDirectory
                isJunction = $IsJunction
                isEmpty = $IsEmpty
                target = $Target
                linkType = $LinkType
                attributes = $Attributes
                sizeBytes = $SizeBytes
            }
        }

        $script:NewIssue7PreflightResult = {
            param(
                [string]$Status = "changed",
                [bool]$SourceExists = $true
            )

            [pscustomobject]@{
                status = $Status
                reason = "junction-migration-planned"
                planAction = if ($SourceExists) { "migrate-directory" } else { "create-target-and-junction" }
                sourceState = & $script:NewIssue7PathState -Exists:$SourceExists -IsDirectory:$SourceExists -IsEmpty $(if ($SourceExists) { $false } else { $null }) -SizeBytes $(if ($SourceExists) { 10 } else { 0 })
                targetState = & $script:NewIssue7PathState -Exists $false -IsDirectory $false -IsEmpty $null
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

    It "keeps active Junction migration code free of robocopy MOVE" {
        $moveSwitch = ([string][char]47) + "MOVE"
        $movePattern = '(?im)^\s*robocopy\b[^\r\n]*\s' + [regex]::Escape($moveSwitch) + '\b'
        foreach ($relativePath in @(
            "scripts\postdeploy\Set-DataJunctions.ps1";
            "scripts\common\Invoke-KitJunctionTransaction.ps1"
        )) {
            $content = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            if ($content -match $movePattern) {
                throw "Active Junction migration path must not use robocopy MOVE switch: $relativePath"
            }
        }
    }

    It "keeps PR Fast CI wired to Issue 7 Junction acceptance tests" {
        $ci = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
        foreach ($requiredPath in @(
            "tests/pester/JunctionTransactionPreflight.Tests.ps1";
            "tests/pester/JunctionTransactionExecution.Tests.ps1";
            "tests/pester/Issue7JunctionAcceptance.Tests.ps1"
        )) {
            if (-not $ci.Contains($requiredPath)) {
                throw "PR Fast CI is missing $requiredPath"
            }
        }
    }

    It "keeps schema and manifest policies conservative" {
        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\junctions.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $properties = $schema.properties.junctions.items.properties
        Assert-KitEqual ($properties.onTargetConflict.enum -join ",") "fail"
        Assert-KitEqual ($properties.onTargetConflict.default) "fail"
        Assert-KitEqual (($properties.backupRetention.enum | Sort-Object) -join ",") "delete,keep"
        Assert-KitEqual ($properties.backupRetention.default) "keep"
        Assert-KitEqual ($properties.verificationMode.enum -join ",") "countAndSize"
        Assert-KitEqual ($properties.verificationMode.default) "countAndSize"

        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\junctions.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($junction in @($manifest.junctions)) {
            Assert-KitEqual ([string]$junction.onTargetConflict) "fail"
            Assert-KitEqual ([string]$junction.backupRetention) "keep"
            Assert-KitEqual ([string]$junction.verificationMode) "countAndSize"
        }
    }

    It "emits complete transaction report fields and summary semantics" {
        $config = & $script:NewIssue7JunctionConfig
        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewIssue7PreflightResult) `
            -CreateDirectory { } `
            -GetDirectoryStats $script:Stats `
            -CopyDirectory { 1 } `
            -RenameSourceToBackup { } `
            -CreateJunction { 0 } `
            -PathExists { $true } `
            -JunctionQuery $script:VerifyOk

        foreach ($field in @(
            "junctionPath";
            "expectedTarget";
            "planAction";
            "transactionStage";
            "sourceFileCount";
            "sourceBytes";
            "targetFileCount";
            "targetBytes";
            "robocopyExitCode";
            "backupPath";
            "mklinkExitCode";
            "verifiedTarget";
            "backupRetention";
            "rollbackAttempted";
            "rollbackSucceeded";
            "manualRecoveryHint";
            "failurePolicy";
            "onTargetConflict";
            "verificationMode"
        )) {
            if ($null -eq $result.data.PSObject.Properties[$field]) {
                throw "Transaction result data is missing field: $field"
            }
        }

        Assert-KitEqual $result.status "changed"
        Assert-KitEqual $result.changed $true
        Assert-KitEqual $result.data.transactionStage "complete"
        Assert-KitEqual $result.data.sourceFileCount 2
        Assert-KitEqual $result.data.targetFileCount 2
        Assert-KitEqual $result.data.robocopyExitCode 1
        Assert-KitEqual $result.data.mklinkExitCode 0

        $report = New-KitJunctionStateReport -Results @($result)
        Assert-KitEqual $report.junctionSummary.failedRequiredCount 0
        Assert-KitEqual $report.junctionSummary.hasBlockingFailure $false
        Assert-KitEqual $report.junctionSummary.exitCode 0
        $json = $report | ConvertTo-Json -Depth 10
        foreach ($jsonTerm in @("transactionStage", "backupPath", "rollbackAttempted", "manualRecoveryHint")) {
            if (-not $json.Contains($jsonTerm)) {
                throw "Junction report JSON is missing $jsonTerm"
            }
        }
    }

    It "keeps Set-DataJunctions WhatIf as plan-only report output" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-issue7-whatif-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $manifestPath = Join-Path $tempRoot "junctions.json"
        $pathsPath = Join-Path $tempRoot "paths.json"
        $reportPath = Join-Path $tempRoot "junction-report.json"
        $stdoutPath = Join-Path $tempRoot "stdout.txt"
        $stderrPath = Join-Path $tempRoot "stderr.txt"
        $sourcePath = Join-Path $tempRoot "tools\issue7"
        $targetPath = Join-Path $tempRoot "data\issue7"

        try {
            ([ordered]@{
                paths = [ordered]@{
                    DataRoot = Join-Path $tempRoot "data"
                    ToolRoot = Join-Path $tempRoot "tools"
                }
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $pathsPath -Encoding UTF8

            ([ordered]@{
                junctions = @(
                    [ordered]@{
                        description = "Issue7WhatIfJunction"
                        source = '${ToolRoot}\issue7'
                        target = '${DataRoot}\issue7'
                        onTargetConflict = "fail"
                        backupRetention = "keep"
                        verificationMode = "countAndSize"
                    }
                )
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

            $scriptPath = Join-Path $script:RepoRoot "scripts\postdeploy\Set-DataJunctions.ps1"
            $process = Start-Process `
                -FilePath $script:PowerShell `
                -ArgumentList @(
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    $scriptPath,
                    "-ManifestPath",
                    $manifestPath,
                    "-PathsManifestPath",
                    $pathsPath,
                    "-ReportPath",
                    $reportPath,
                    "-WhatIf"
                ) `
                -RedirectStandardOutput $stdoutPath `
                -RedirectStandardError $stderrPath `
                -Wait `
                -PassThru `
                -WindowStyle Hidden

            Assert-KitEqual ([int]$process.ExitCode) 0
            Assert-KitEqual (Test-Path -LiteralPath $sourcePath) $false
            Assert-KitEqual (Test-Path -LiteralPath $targetPath) $false
            Assert-KitEqual (Test-Path -LiteralPath $reportPath) $true

            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            Assert-KitEqual ([int]$report.junctionSummary.exitCode) 0
            Assert-KitEqual ([string]$report.junctionResults[0].status) "whatif"
            Assert-KitEqual ([string]$report.junctionResults[0].data.transactionStage) "plan"
            Assert-KitEqual ([bool]$report.junctionResults[0].changed) $false
            Assert-KitEqual ([bool]$report.junctionResults[0].whatIf) $true
            Assert-KitEqual ($report.junctionResults[0].evidence.plannedSteps -contains "copy") $true
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }

    It "blocks target reparse points before transaction mutation operations" {
        $operations = [ordered]@{ create = 0; copy = 0; rename = 0; mklink = 0 }
        $config = & $script:NewIssue7JunctionConfig
        $query = {
            param([string]$Path, [string]$Role, $JunctionConfig)
            if ($Role -eq "source") {
                return & $script:NewIssue7PathState -Exists $true -IsDirectory $true -IsEmpty $false -SizeBytes 10
            }

            & $script:NewIssue7PathState -Exists $true -IsDirectory $true -IsJunction $true -IsEmpty $null -Target "E:\UnexpectedTarget" -LinkType "Junction" -Attributes "Directory, ReparsePoint"
        }

        $preflight = Test-KitDataJunctionPreflight -JunctionConfig $config -StateQuery $query
        $result = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult $preflight `
            -CreateDirectory { $operations.create++ } `
            -CopyDirectory { $operations.copy++; 0 } `
            -RenameSourceToBackup { $operations.rename++ } `
            -CreateJunction { $operations.mklink++; 0 }

        Assert-KitEqual $result.reason "junction-target-is-reparse-point"
        Assert-KitEqual $operations.create 0
        Assert-KitEqual $operations.copy 0
        Assert-KitEqual $operations.rename 0
        Assert-KitEqual $operations.mklink 0
    }

    It "reports manual recovery guidance for late transaction failures" {
        $config = & $script:NewIssue7JunctionConfig
        $mklinkFailure = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewIssue7PreflightResult) `
            -CreateDirectory { } `
            -GetDirectoryStats $script:Stats `
            -CopyDirectory { 0 } `
            -RenameSourceToBackup { } `
            -CreateJunction { 1 } `
            -PathExists { $false }

        Assert-KitEqual $mklinkFailure.reason "junction-mklink-failed"
        Assert-KitEqual $mklinkFailure.data.rollbackAttempted $true
        Assert-KitNotNullOrEmpty $mklinkFailure.data.manualRecoveryHint

        $finalVerifyFailure = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $config `
            -PreflightResult (& $script:NewIssue7PreflightResult) `
            -CreateDirectory { } `
            -GetDirectoryStats $script:Stats `
            -CopyDirectory { 0 } `
            -RenameSourceToBackup { } `
            -CreateJunction { 0 } `
            -PathExists { $true } `
            -JunctionQuery {
                param([string]$Path, $JunctionConfig)
                [pscustomobject]@{ Exists = $true; IsJunction = $true; Target = "D:\Data\Wrong"; LinkType = "Junction"; Attributes = "Directory, ReparsePoint" }
            }

        Assert-KitEqual $finalVerifyFailure.reason "junction-post-verify-failed"
        Assert-KitNotNullOrEmpty $finalVerifyFailure.data.manualRecoveryHint
        foreach ($errorItem in @($finalVerifyFailure.errors)) {
            if ($errorItem -is [System.Array]) {
                throw "Final verification errors must be a flat array."
            }
        }

        $deleteFailureConfig = & $script:NewIssue7JunctionConfig -BackupRetention "delete"
        $backupDeleteFailure = Invoke-KitDataJunctionTransaction `
            -JunctionConfig $deleteFailureConfig `
            -PreflightResult (& $script:NewIssue7PreflightResult) `
            -CreateDirectory { } `
            -GetDirectoryStats $script:Stats `
            -CopyDirectory { 0 } `
            -RenameSourceToBackup { } `
            -CreateJunction { 0 } `
            -PathExists { $true } `
            -JunctionQuery $script:VerifyOk `
            -RemoveBackup { throw "delete denied" }

        Assert-KitEqual $backupDeleteFailure.reason "junction-backup-delete-failed"
        Assert-KitNotNullOrEmpty $backupDeleteFailure.data.manualRecoveryHint
    }
}
