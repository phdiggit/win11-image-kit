[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/evidence-chain.json",
    [string]$InputDirectory = "tests/fixtures/evidence-chain/sample-report-inputs",
    [string]$ReportPath,
    [ValidateSet("fixture", "local", "ci", "main", "workflow_dispatch", "manual")]
    [string]$SourceKind = "fixture",
    [string]$SourceSha,
    [string]$WorkflowRunUrl,
    [string]$JobUrl
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\New-KitEvidenceChainReport.ps1"

function Add-KitEvidenceValidationError {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $script:ValidationErrors += $Message
    Write-Host ("[ERROR] {0}" -f $Message) -ForegroundColor Red
}

function Resolve-KitEvidenceValidationPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }

    return [IO.Path]::GetFullPath((Join-Path -Path $RepoRoot -ChildPath $Path))
}

function Test-KitEvidenceGithubActionsUrl {
    param(
        [AllowEmptyString()]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return
    }

    if ($Url -notmatch '^https://github\.com/.+/actions/runs/[0-9]+') {
        Add-KitEvidenceValidationError "$Name must be a GitHub Actions URL: $Url"
    }
}

function Test-KitEvidenceArtifactReference {
    param(
        [Parameter(Mandatory)]
        $Artifact
    )

    $path = [string](Get-KitEvidenceValue -InputObject $Artifact -Name "path" -DefaultValue "")
    $private = [bool](Get-KitEvidenceValue -InputObject $Artifact -Name "private" -DefaultValue $false)
    if ($private) {
        Add-KitEvidenceValidationError "artifact reference must not be private: $path"
    }

    foreach ($pattern in @(
        '(^|[\\/])paths\.local\.json$',
        '(^|[\\/])secrets[\\/]',
        '^[A-Za-z]:[\\/]',
        '^\\\\',
        'Users[\\/]'
    )) {
        if ($path -match $pattern) {
            Add-KitEvidenceValidationError "artifact reference is not allowed in evidence chain: $path"
        }
    }
}

function Test-KitEvidenceManifest {
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $allowedStages = @("config", "validate", "build", "capture", "deploy", "acceptance")
    $allowedModes = @("static", "fixture", "report-only", "manual")
    $seenProducers = @{}

    foreach ($stage in @($Manifest.stages)) {
        if ($allowedStages -notcontains [string]$stage) {
            Add-KitEvidenceValidationError "invalid evidence chain stage: $stage"
        }
    }

    foreach ($producer in @($Manifest.producers)) {
        $id = [string]$producer.id
        if ([string]::IsNullOrWhiteSpace($id)) {
            Add-KitEvidenceValidationError "producer id is required"
            continue
        }

        $key = $id.ToLowerInvariant()
        if ($seenProducers.ContainsKey($key)) {
            Add-KitEvidenceValidationError "duplicate producer id: $id"
        } else {
            $seenProducers[$key] = $true
        }

        if ($allowedStages -notcontains [string]$producer.stage) {
            Add-KitEvidenceValidationError "producer $id has invalid stage: $($producer.stage)"
        }

        if ($allowedModes -notcontains [string]$producer.mode) {
            Add-KitEvidenceValidationError "producer $id has invalid mode: $($producer.mode)"
        }

        if ([string]$producer.mode -eq "true-execution") {
            Add-KitEvidenceValidationError "producer $id must not use true-execution mode"
        }

        $entrypoint = [string]$producer.entrypoint
        if ([string]::IsNullOrWhiteSpace($entrypoint)) {
            Add-KitEvidenceValidationError "producer $id missing entrypoint"
        } elseif ($entrypoint -like "manual://*") {
            if ([string]$producer.mode -ne "manual") {
                Add-KitEvidenceValidationError "producer $id uses manual entrypoint without manual mode"
            }
        } else {
            $resolved = Resolve-KitEvidenceValidationPath -RepoRoot $RepoRoot -Path $entrypoint
            if (-not (Test-Path -LiteralPath $resolved)) {
                Add-KitEvidenceValidationError "producer $id entrypoint missing: $entrypoint"
            }
        }
    }
}

function Test-KitEvidenceReport {
    param(
        [Parameter(Mandatory)]
        $Report
    )

    if ([string]$Report.reportType -ne "evidence-chain") {
        Add-KitEvidenceValidationError "reportType must be evidence-chain"
    }

    if ($Report.summary.failedCount -ne @($Report.evidence | Where-Object { $_.status -eq "failed" }).Count) {
        Add-KitEvidenceValidationError "failedCount does not match failed evidence"
    }

    if ($Report.summary.manualCount -ne @($Report.evidence | Where-Object { $_.status -eq "manual" }).Count) {
        Add-KitEvidenceValidationError "manualCount does not match manual evidence"
    }

    if ($Report.summary.notCapturedCount -ne @($Report.evidence | Where-Object { $_.status -eq "not-captured" }).Count) {
        Add-KitEvidenceValidationError "notCapturedCount does not match not-captured evidence"
    }

    foreach ($item in @($Report.evidence)) {
        if (($item.status -eq "manual" -or $item.status -eq "not-captured") -and -not $item.manual) {
            Add-KitEvidenceValidationError "manual/not-captured evidence must be explicitly manual: $($item.producerId)"
        }

        if (($item.status -eq "manual" -or $item.status -eq "not-captured") -and $item.reproducible) {
            Add-KitEvidenceValidationError "manual/not-captured evidence must not be marked reproducible: $($item.producerId)"
        }

        foreach ($artifact in @($item.artifactReferences)) {
            Test-KitEvidenceArtifactReference -Artifact $artifact
        }
    }

    if ($Report.safety.trueExecution) {
        Add-KitEvidenceValidationError "safety.trueExecution must be false"
    }
    if ($Report.safety.localPrivateIncluded) {
        Add-KitEvidenceValidationError "safety.localPrivateIncluded must be false"
    }
    if ($Report.safety.networkUsed) {
        Add-KitEvidenceValidationError "safety.networkUsed must be false"
    }
    if ($Report.safety.mutationUsed) {
        Add-KitEvidenceValidationError "safety.mutationUsed must be false"
    }
}

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:ValidationErrors = @()

if (-not [string]::IsNullOrWhiteSpace($SourceSha) -and $SourceSha -notmatch '^[A-Fa-f0-9]{40}$') {
    Add-KitEvidenceValidationError "SourceSha must be a 40-character Git SHA: $SourceSha"
}
Test-KitEvidenceGithubActionsUrl -Url $WorkflowRunUrl -Name "WorkflowRunUrl"
Test-KitEvidenceGithubActionsUrl -Url $JobUrl -Name "JobUrl"

$resolvedManifestPath = Resolve-KitEvidenceValidationPath -RepoRoot $repoRoot -Path $ManifestPath
if (-not (Test-Path -LiteralPath $resolvedManifestPath)) {
    Add-KitEvidenceValidationError "manifest not found: $ManifestPath"
    exit 1
}

$manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
Test-KitEvidenceManifest -Manifest $manifest -RepoRoot $repoRoot

$report = New-KitEvidenceChainReport `
    -ManifestPath $ManifestPath `
    -InputDirectory $InputDirectory `
    -SourceKind $SourceKind `
    -SourceSha $SourceSha `
    -WorkflowRunUrl $WorkflowRunUrl `
    -JobUrl $JobUrl `
    -RepoRoot $repoRoot

Test-KitEvidenceReport -Report $report

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = Resolve-KitEvidenceValidationPath -RepoRoot $repoRoot -Path $ReportPath
    $reportDirectory = Split-Path -Path $resolvedReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
    Write-Host "Evidence chain report written: $resolvedReportPath"
}

$report

if ($script:ValidationErrors.Count -gt 0 -or $report.summary.failedCount -gt 0) {
    exit 1
}

