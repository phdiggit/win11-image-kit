[CmdletBinding()]
param(
    [string]$ManifestPath = "manifests/evidence-chain.json",
    [string]$InputManifestPath = "manifests/evidence-report-inputs.json",
    [string]$InputDirectory = "tests/fixtures/evidence-chain/sample-report-inputs",
    [string]$ReportPath,
    [ValidateSet("fixture", "local", "ci", "main", "workflow_dispatch", "manual")]
    [string]$SourceKind = "fixture",
    [string]$SourceSha,
    [string]$WorkflowRunUrl,
    [string]$JobUrl,
    [string]$RunId,
    [string]$UpstreamRunId,
    [string]$ArtifactIndexPath = "tests/fixtures/evidence-chain/sample-artifact-index.json"
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

function Test-KitEvidenceRunIdValue {
    param(
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$AllowLifecyclePlaceholder
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    if ($AllowLifecyclePlaceholder -and $Value -in @("manual", "not-captured")) {
        return
    }

    if ($Value -notmatch '^kit-run-[0-9]{8}T[0-9]{6}Z-[A-Fa-f0-9]{7,12}$') {
        Add-KitEvidenceValidationError "$Name must be a valid kit run id: $Value"
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

function Test-KitEvidenceArtifactIndexItem {
    param(
        [Parameter(Mandatory)]
        $Artifact,

        [string[]]$ForbiddenArtifactPatterns = @()
    )

    $path = [string](Get-KitEvidenceValue -InputObject $Artifact -Name "path" -DefaultValue "")
    $logicalName = [string](Get-KitEvidenceValue -InputObject $Artifact -Name "logicalName" -DefaultValue "")
    $private = [bool](Get-KitEvidenceValue -InputObject $Artifact -Name "private" -DefaultValue $false)
    $sha256 = [string](Get-KitEvidenceValue -InputObject $Artifact -Name "sha256" -DefaultValue "")
    $sizeBytes = Get-KitEvidenceValue -InputObject $Artifact -Name "sizeBytes" -DefaultValue $null

    if ([string]::IsNullOrWhiteSpace($path) -and [string]::IsNullOrWhiteSpace($logicalName)) {
        Add-KitEvidenceValidationError "artifact index item must include path or logicalName"
    }

    if ($private) {
        Add-KitEvidenceValidationError "artifact index item must not be private: $path$logicalName"
    }

    if (-not [string]::IsNullOrWhiteSpace($sha256) -and $sha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        Add-KitEvidenceValidationError "artifact sha256 must be 64 hex: $path$logicalName"
    }

    if ($null -ne $sizeBytes) {
        try {
            if ([int64]$sizeBytes -lt 0) {
                Add-KitEvidenceValidationError "artifact sizeBytes must be >= 0: $path$logicalName"
            }
        } catch {
            Add-KitEvidenceValidationError "artifact sizeBytes must be an integer: $path$logicalName"
        }
    }

    Test-KitEvidenceRunIdValue -Value ([string]$Artifact.runId) -Name "artifact.runId" -AllowLifecyclePlaceholder
    Test-KitEvidenceRunIdValue -Value ([string](Get-KitEvidenceValue -InputObject $Artifact -Name "upstreamRunId" -DefaultValue "")) -Name "artifact.upstreamRunId" -AllowLifecyclePlaceholder

    foreach ($pattern in @($ForbiddenArtifactPatterns)) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and $path -match $pattern) {
            Add-KitEvidenceValidationError "artifact index path is not allowed: $path"
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
        $Report,

        [Parameter(Mandatory)]
        $Manifest
    )

    if ([string]$Report.reportType -ne "evidence-chain") {
        Add-KitEvidenceValidationError "reportType must be evidence-chain"
    }

    if ([string]::IsNullOrWhiteSpace([string](Get-KitEvidenceValue -InputObject $Report -Name "inputSetId" -DefaultValue ""))) {
        Add-KitEvidenceValidationError "inputSetId is required"
    }

    Test-KitEvidenceRunIdValue -Value ([string]$Report.runId) -Name "report.runId"
    Test-KitEvidenceRunIdValue -Value ([string](Get-KitEvidenceValue -InputObject $Report -Name "upstreamRunId" -DefaultValue "")) -Name "report.upstreamRunId"

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

        Test-KitEvidenceRunIdValue -Value ([string]$item.runId) -Name ("evidence.runId[{0}]" -f $item.producerId) -AllowLifecyclePlaceholder
        Test-KitEvidenceRunIdValue -Value ([string](Get-KitEvidenceValue -InputObject $item -Name "upstreamRunId" -DefaultValue "")) -Name ("evidence.upstreamRunId[{0}]" -f $item.producerId) -AllowLifecyclePlaceholder

        if ($item.producerId -in @("real-build", "capture", "deploy", "admin-vm-smoke") -and $item.status -eq "passed") {
            Add-KitEvidenceValidationError "PR Fast baseline cannot mark lifecycle placeholder passed: $($item.producerId)"
        }
    }

    foreach ($inputReport in @($Report.inputReports)) {
        Test-KitEvidenceArtifactReference -Artifact ([pscustomobject]@{
            kind = "report"
            path = [string]$inputReport.path
            private = $false
        })

        $producerId = [string]$inputReport.producerId
        $producer = @($Manifest.producers | Where-Object { [string]$_.id -eq $producerId })[0]
        if ($null -eq $producer) {
            Add-KitEvidenceValidationError "input report producerId is not declared: $producerId"
        } elseif ([string]$inputReport.expectedReportType -ne [string]$producer.reportType) {
            Add-KitEvidenceValidationError "input expectedReportType does not match producer $producerId"
        }
    }

    if ($Report.producerNormalization.missingRequiredCount -gt 0) {
        Add-KitEvidenceValidationError "producerNormalization.missingRequiredCount must be zero"
    }
    if ($Report.producerNormalization.reportTypeMismatchCount -gt 0) {
        Add-KitEvidenceValidationError "producerNormalization.reportTypeMismatchCount must be zero"
    }
    if ($Report.producerNormalization.disallowedManualCount -gt 0) {
        Add-KitEvidenceValidationError "producerNormalization.disallowedManualCount must be zero"
    }
    if ($Report.producerNormalization.disallowedNotCapturedCount -gt 0) {
        Add-KitEvidenceValidationError "producerNormalization.disallowedNotCapturedCount must be zero"
    }
    if ($Report.producerNormalization.inputPolicyViolationCount -gt 0) {
        Add-KitEvidenceValidationError "producerNormalization.inputPolicyViolationCount must be zero"
    }

    foreach ($name in @("configRunId", "validateRunId", "buildRunId", "captureRunId", "deployRunId", "acceptanceRunId")) {
        Test-KitEvidenceRunIdValue -Value ([string]$Report.lifecycle.$name) -Name "lifecycle.$name" -AllowLifecyclePlaceholder
    }

    foreach ($stageLink in @($Report.stageLinks)) {
        Test-KitEvidenceRunIdValue -Value ([string]$stageLink.runId) -Name ("stageLinks.runId[{0}]" -f $stageLink.stage) -AllowLifecyclePlaceholder
        Test-KitEvidenceRunIdValue -Value ([string](Get-KitEvidenceValue -InputObject $stageLink -Name "upstreamRunId" -DefaultValue "")) -Name ("stageLinks.upstreamRunId[{0}]" -f $stageLink.stage) -AllowLifecyclePlaceholder
    }

    $forbiddenArtifactPatterns = @()
    if ($null -ne $Manifest.artifactPolicy -and $null -ne $Manifest.artifactPolicy.forbiddenArtifactPatterns) {
        $forbiddenArtifactPatterns = @($Manifest.artifactPolicy.forbiddenArtifactPatterns | ForEach-Object { [string]$_ })
    }
    foreach ($artifact in @($Report.artifactIndex)) {
        Test-KitEvidenceArtifactIndexItem -Artifact $artifact -ForbiddenArtifactPatterns $forbiddenArtifactPatterns
    }

    if ($Report.summary.artifactCount -ne @($Report.artifactIndex).Count) {
        Add-KitEvidenceValidationError "summary.artifactCount does not match artifactIndex"
    }

    if ($Report.redactions.blockedCount -gt 0) {
        Add-KitEvidenceValidationError "redactions.blockedCount must be zero"
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
Test-KitEvidenceRunIdValue -Value $RunId -Name "RunId"
Test-KitEvidenceRunIdValue -Value $UpstreamRunId -Name "UpstreamRunId"
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
    -InputManifestPath $InputManifestPath `
    -InputDirectory $InputDirectory `
    -SourceKind $SourceKind `
    -SourceSha $SourceSha `
    -WorkflowRunUrl $WorkflowRunUrl `
    -JobUrl $JobUrl `
    -RunId $RunId `
    -UpstreamRunId $UpstreamRunId `
    -ArtifactIndexPath $ArtifactIndexPath `
    -RepoRoot $repoRoot

Test-KitEvidenceReport -Report $report -Manifest $manifest

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

if (
    $script:ValidationErrors.Count -gt 0 -or
    $report.summary.failedCount -gt 0 -or
    $report.redactions.blockedCount -gt 0 -or
    $report.producerNormalization.missingRequiredCount -gt 0 -or
    $report.producerNormalization.reportTypeMismatchCount -gt 0 -or
    $report.producerNormalization.disallowedManualCount -gt 0 -or
    $report.producerNormalization.disallowedNotCapturedCount -gt 0 -or
    $report.producerNormalization.inputPolicyViolationCount -gt 0
) {
    exit 1
}

