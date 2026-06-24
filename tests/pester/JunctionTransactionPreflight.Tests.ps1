$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Junction transaction preflight" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitJunctionPreflight.ps1")
        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }
    }

    function New-TestJunctionConfig {
        param(
            [string]$Source = "C:\Source",
            [string]$Target = "D:\Data\Target",
            [string]$OnTargetConflict = "fail"
        )

        [pscustomobject]@{
            name = "PesterJunction"
            description = "PesterJunction"
            source = $Source
            target = $Target
            required = $true
            failurePolicy = "fail"
            onTargetConflict = $OnTargetConflict
            backupRetention = "keep"
            verificationMode = "countAndSize"
        }
    }

    function New-TestPathState {
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

    It "records an existing expected junction as unchanged" {
        $junction = New-TestJunctionConfig -Target "D:\Data\Expected"
        $query = {
            param([string]$Path, [string]$Role, $JunctionConfig)
            if ($Role -eq "source") {
                return New-TestPathState -Exists $true -IsDirectory $true -IsJunction $true -Target "D:\Data\Expected\" -LinkType "Junction" -Attributes "Directory, ReparsePoint"
            }

            New-TestPathState -Exists $true -IsDirectory $true -IsEmpty $false
        }

        $result = Test-KitDataJunctionPreflight -JunctionConfig $junction -StateQuery $query

        Assert-KitEqual $result.status "unchanged"
        Assert-KitEqual $result.reason "junction-state-ok"
        Assert-KitEqual $result.planAction "unchanged"
        Assert-KitEqual $result.actualTarget "D:\Data\Expected\"
    }

    It "blocks an existing junction that points at the wrong target" {
        $junction = New-TestJunctionConfig -Target "D:\Data\Expected"
        $query = {
            param([string]$Path, [string]$Role, $JunctionConfig)
            if ($Role -eq "source") {
                return New-TestPathState -Exists $true -IsDirectory $true -IsJunction $true -Target "D:\Data\Actual" -LinkType "Junction" -Attributes "Directory, ReparsePoint"
            }

            New-TestPathState -Exists $true -IsDirectory $true -IsEmpty $true
        }

        $result = Test-KitDataJunctionPreflight -JunctionConfig $junction -StateQuery $query

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-target-mismatch"
        Assert-KitMatch $result.errors[0] "expectedTarget=D:\\Data\\Expected"
        Assert-KitMatch $result.errors[0] "actualTarget=D:\\Data\\Actual"
    }

    It "blocks a non-empty target when onTargetConflict uses the default fail policy" {
        $junction = New-TestJunctionConfig
        $query = {
            param([string]$Path, [string]$Role, $JunctionConfig)
            if ($Role -eq "source") {
                return New-TestPathState -Exists $true -IsDirectory $true -IsEmpty $false -SizeBytes 10
            }

            New-TestPathState -Exists $true -IsDirectory $true -IsEmpty $false
        }

        $result = Test-KitDataJunctionPreflight -JunctionConfig $junction -StateQuery $query

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.reason "junction-target-conflict"
        Assert-KitEqual $result.planAction "block"
    }

    It "blocks same-path and parent-child path risks before querying disk state" {
        $samePath = New-TestJunctionConfig -Source "C:\Data\Same\" -Target "c:\data\same"
        $samePathResult = Test-KitDataJunctionPreflight -JunctionConfig $samePath -StateQuery { throw "state query should not run for same paths" }

        $parentChild = New-TestJunctionConfig -Source "C:\Data" -Target "C:\Data\Nested"
        $parentChildResult = Test-KitDataJunctionPreflight -JunctionConfig $parentChild -StateQuery { throw "state query should not run for parent-child paths" }

        Assert-KitEqual $samePathResult.status "failed"
        Assert-KitEqual $samePathResult.reason "junction-path-cycle-risk"
        Assert-KitMatch $samePathResult.errors[0] "same-path"
        Assert-KitEqual $parentChildResult.status "failed"
        Assert-KitEqual $parentChildResult.reason "junction-path-cycle-risk"
        Assert-KitMatch $parentChildResult.errors[0] "target-under-source"
    }

    It "blocks migration when the target drive does not have enough estimated free space" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-junction-space-{0}" -f ([guid]::NewGuid().ToString("N")))
        $source = Join-Path $tempRoot "source"
        $target = Join-Path $tempRoot "target"
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        try {
            $junction = New-TestJunctionConfig -Source $source -Target $target
            $query = {
                param([string]$Path, [string]$Role, $JunctionConfig)
                if ($Role -eq "source") {
                    return New-TestPathState -Exists $true -IsDirectory $true -IsEmpty $false -SizeBytes 100
                }

                New-TestPathState -Exists $false -IsDirectory $false -IsEmpty $null
            }
            $space = {
                param([string]$Path, $JunctionConfig)
                50
            }

            $result = Test-KitDataJunctionPreflight -JunctionConfig $junction -StateQuery $query -TargetAvailableBytesQuery $space

            Assert-KitEqual $result.status "failed"
            Assert-KitEqual $result.reason "junction-target-space-insufficient"
            Assert-KitMatch $result.errors[0] "sourceBytes=100"
            Assert-KitMatch $result.errors[0] "availableBytes=50"
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }

    It "writes a WhatIf plan without creating target directories or mutating source paths" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-junction-preflight-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $manifestPath = Join-Path $tempRoot "junctions.json"
        $pathsPath = Join-Path $tempRoot "paths.json"
        $reportPath = Join-Path $tempRoot "junction-report.json"
        $stdoutPath = Join-Path $tempRoot "stdout.txt"
        $stderrPath = Join-Path $tempRoot "stderr.txt"
        $sourcePath = Join-Path $tempRoot "tools\example"
        $targetPath = Join-Path $tempRoot "data\example"

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
                        description = "PreflightOnlyJunction"
                        source = '${ToolRoot}\example'
                        target = '${DataRoot}\example'
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

            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $reportedJunction = @($report.junctionResults)[0]
            Assert-KitEqual $reportedJunction.status "whatif"
            Assert-KitEqual $reportedJunction.reason "junction-migration-planned"
            Assert-KitEqual $reportedJunction.planAction "create-target-and-junction"
            Assert-KitEqual $report.junctionSummary.exitCode 0
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }

    It "accepts Junction policy schema fields and rejects invalid policy values" {
        $schemaPath = Join-Path $script:RepoRoot "schemas\junctions.schema.json"
        $schema = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $properties = $schema.properties.junctions.items.properties

        Assert-KitEqual ($properties.PSObject.Properties.Name -contains "onTargetConflict") $true
        Assert-KitEqual ($properties.onTargetConflict.enum -contains "fail") $true
        Assert-KitEqual ($properties.onTargetConflict.enum -contains "overwrite") $false
        Assert-KitEqual ($properties.backupRetention.enum -contains "keep") $true
        Assert-KitEqual ($properties.backupRetention.enum -contains "purge") $false
        Assert-KitEqual ($properties.verificationMode.enum -contains "countAndSize") $true
        Assert-KitEqual ($properties.verificationMode.enum -contains "hash") $false
    }
}
