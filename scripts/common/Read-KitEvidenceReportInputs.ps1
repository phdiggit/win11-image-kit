#Requires -Version 5.1

function Test-KitEvidenceReportInputPath {
    param(
        [AllowEmptyString()]
        [string]$Path
    )

    $errors = @()
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return @("input path is required")
    }

    if ([IO.Path]::IsPathRooted($Path)) {
        $errors += "input path must be repo-relative: $Path"
    }

    foreach ($pattern in @(
        '(^|[\\/])paths\.local\.json$',
        '(^|[\\/])secrets[\\/]',
        '^[A-Za-z]:[\\/]',
        '^\\\\',
        '(^|[\\/])Users[\\/]'
    )) {
        if ($Path -match $pattern) {
            $errors += "input path is not allowed: $Path"
        }
    }

    @($errors)
}

function New-KitEvidenceDirectoryInputIndex {
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [Parameter(Mandatory)]
        [string]$InputDirectory
    )

    $inputs = @()
    foreach ($producer in @($Manifest.producers | Where-Object { [string]$_.mode -ne "manual" })) {
        $inputs += [pscustomobject][ordered]@{
            producerId = [string]$producer.id
            path = (Join-Path -Path $InputDirectory -ChildPath ("{0}.json" -f $producer.id)).Replace("\", "/")
            expectedReportType = [string]$producer.reportType
            required = [bool]$producer.required
            allowMissing = $false
            allowManual = $false
            allowNotCaptured = $false
        }
    }

    [pscustomobject][ordered]@{
        manifestVersion = 1
        inputSetId = "directory-fallback"
        sourceKind = "fixture"
        inputs = @($inputs)
    }
}

function Read-KitEvidenceReportInputs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        $Manifest,

        [string]$InputManifestPath = "manifests/evidence-report-inputs.json",

        [string]$InputDirectory = "tests/fixtures/evidence-chain/sample-report-inputs"
    )

    $index = $null
    $resolvedInputManifestPath = $null
    $usingDirectoryFallback = $false
    if (-not [string]::IsNullOrWhiteSpace($InputManifestPath)) {
        $resolvedInputManifestPath = Resolve-KitEvidenceRepoPath -RepoRoot $RepoRoot -Path $InputManifestPath
        if (Test-Path -LiteralPath $resolvedInputManifestPath) {
            $index = Read-KitEvidenceJsonFile -Path $resolvedInputManifestPath
        }
    }

    if ($null -eq $index) {
        $index = New-KitEvidenceDirectoryInputIndex -Manifest $Manifest -InputDirectory $InputDirectory
        $usingDirectoryFallback = $true
    }

    $producerIds = @{}
    foreach ($producer in @($Manifest.producers)) {
        $producerIds[[string]$producer.id] = $true
    }

    $records = @()
    $unmatchedInputCount = 0
    $inputPolicyViolationCount = 0

    foreach ($input in @($index.inputs)) {
        $producerId = [string]$input.producerId
        $path = [string]$input.path
        $errors = @()
        if (-not $usingDirectoryFallback) {
            $errors = @(Test-KitEvidenceReportInputPath -Path $path)
        }
        if (-not $producerIds.ContainsKey($producerId)) {
            $errors += "input producerId does not match evidence-chain manifest: $producerId"
            $unmatchedInputCount += 1
        }

        $resolvedPath = $null
        $exists = $false
        $report = $null
        if ($errors.Count -eq 0) {
            $resolvedPath = Resolve-KitEvidenceRepoPath -RepoRoot $RepoRoot -Path $path
            $exists = Test-Path -LiteralPath $resolvedPath
            if ($exists) {
                $report = Read-KitEvidenceJsonFile -Path $resolvedPath
            }
        }

        if ($errors.Count -gt 0) {
            $inputPolicyViolationCount += 1
        }

        $records += [pscustomobject][ordered]@{
            producerId = $producerId
            path = $path
            expectedReportType = [string]$input.expectedReportType
            required = [bool]$input.required
            allowMissing = [bool]$input.allowMissing
            allowManual = [bool]$input.allowManual
            allowNotCaptured = [bool]$input.allowNotCaptured
            exists = [bool]$exists
            report = $report
            errors = @($errors)
        }
    }

    [pscustomobject][ordered]@{
        inputSetId = [string]$index.inputSetId
        sourceKind = [string]$index.sourceKind
        inputManifestPath = $(if ($null -ne $resolvedInputManifestPath -and (Test-Path -LiteralPath $resolvedInputManifestPath)) { $InputManifestPath } else { $null })
        inputs = @($records)
        inputPolicyViolationCount = $inputPolicyViolationCount
        unmatchedInputCount = $unmatchedInputCount
    }
}
