#Requires -Version 5.1

function Get-KitEvidenceValue {
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

function Resolve-KitEvidenceRepoPath {
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

function Read-KitEvidenceJsonFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function New-KitEvidenceSource {
    param(
        [Parameter(Mandatory)]
        [string]$SourceKind,

        [string]$SourceSha,

        [string]$WorkflowRunUrl,

        [string]$JobUrl,

        [string]$Command
    )

    $source = [ordered]@{
        kind = $SourceKind
    }

    if (-not [string]::IsNullOrWhiteSpace($SourceSha)) {
        $source.sha = $SourceSha
    }

    if (-not [string]::IsNullOrWhiteSpace($WorkflowRunUrl)) {
        $source.workflowRun = $WorkflowRunUrl
    }

    if (-not [string]::IsNullOrWhiteSpace($JobUrl)) {
        $source.job = $JobUrl
    }

    if (-not [string]::IsNullOrWhiteSpace($Command)) {
        $source.command = $Command
    }

    [pscustomobject]$source
}

function Get-KitEvidenceStatus {
    param(
        [object[]]$Items
    )

    if (@($Items | Where-Object { $_.status -eq "failed" }).Count -gt 0) {
        return "failed"
    }

    if (@($Items | Where-Object { $_.status -eq "manual" }).Count -gt 0) {
        return "manual"
    }

    if (@($Items | Where-Object { $_.status -eq "not-captured" }).Count -gt 0) {
        return "not-captured"
    }

    return "passed"
}

function New-KitEvidenceStageSummary {
    param(
        [Parameter(Mandatory)]
        [string]$Stage,

        [object[]]$EvidenceItems
    )

    $items = @($EvidenceItems | Where-Object { $_.stage -eq $Stage })
    [pscustomobject][ordered]@{
        stage = $Stage
        status = Get-KitEvidenceStatus -Items $items
        producerCount = $items.Count
        passedCount = @($items | Where-Object { $_.status -eq "passed" }).Count
        failedCount = @($items | Where-Object { $_.status -eq "failed" }).Count
        manualCount = @($items | Where-Object { $_.status -eq "manual" }).Count
        notCapturedCount = @($items | Where-Object { $_.status -eq "not-captured" }).Count
    }
}

function New-KitEvidenceItem {
    param(
        [Parameter(Mandatory)]
        $Producer,

        [AllowNull()]
        $InputReport,

        [Parameter(Mandatory)]
        $DefaultSource,

        [Parameter(Mandatory)]
        [datetime]$GeneratedAt
    )

    $producerId = [string]$Producer.id
    $producerMode = [string]$Producer.mode
    $status = [string](Get-KitEvidenceValue -InputObject $InputReport -Name "status" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($status)) {
        if ($producerMode -eq "manual" -and $producerId -eq "admin-vm-smoke") {
            $status = "manual"
        } elseif ($producerMode -eq "manual") {
            $status = "not-captured"
        } else {
            $status = "not-captured"
        }
    }

    $inputGeneratedAt = [string](Get-KitEvidenceValue -InputObject $InputReport -Name "generatedAt" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($inputGeneratedAt)) {
        $inputGeneratedAt = $GeneratedAt.ToString("s")
    }

    $source = Get-KitEvidenceValue -InputObject $InputReport -Name "sourceMetadata" -DefaultValue $DefaultSource
    if ($null -eq $source) {
        $source = $DefaultSource
    }

    $artifactReferences = @(Get-KitEvidenceValue -InputObject $InputReport -Name "artifactReferences" -DefaultValue @())
    if ($artifactReferences.Count -eq 0 -and $producerMode -eq "manual") {
        $artifactReferences = @([pscustomobject][ordered]@{
            kind = "manual-placeholder"
            path = [string]$Producer.entrypoint
            private = $false
        })
    }

    $manual = $status -eq "manual" -or $status -eq "not-captured"
    $reproducibleDefault = -not $manual
    $reproducible = [bool](Get-KitEvidenceValue -InputObject $InputReport -Name "reproducible" -DefaultValue $reproducibleDefault)

    [pscustomobject][ordered]@{
        id = "evidence.$producerId"
        stage = [string]$Producer.stage
        producerId = $producerId
        producerMode = $producerMode
        entrypoint = [string]$Producer.entrypoint
        reportType = [string]$Producer.reportType
        status = $status
        generatedAt = $inputGeneratedAt
        manual = [bool]$manual
        reproducible = $reproducible
        reason = [string](Get-KitEvidenceValue -InputObject $Producer -Name "manualReason" -DefaultValue ([string]$Producer.notes))
        sourceMetadata = $source
        artifactReferences = @($artifactReferences)
    }
}

function New-KitEvidenceChainReport {
    [CmdletBinding()]
    param(
        [string]$ManifestPath = "manifests/evidence-chain.json",

        [string]$InputDirectory = "tests/fixtures/evidence-chain/sample-report-inputs",

        [ValidateSet("fixture", "local", "ci", "main", "workflow_dispatch", "manual")]
        [string]$SourceKind = "fixture",

        [string]$SourceSha,

        [string]$WorkflowRunUrl,

        [string]$JobUrl,

        [string]$Repository = "phdiggit/win11-image-kit",

        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $resolvedManifestPath = Resolve-KitEvidenceRepoPath -RepoRoot $RepoRoot -Path $ManifestPath
    $manifest = Read-KitEvidenceJsonFile -Path $resolvedManifestPath
    $resolvedInputDirectory = Resolve-KitEvidenceRepoPath -RepoRoot $RepoRoot -Path $InputDirectory
    $generatedAt = Get-Date
    $defaultSource = New-KitEvidenceSource -SourceKind $SourceKind -SourceSha $SourceSha -WorkflowRunUrl $WorkflowRunUrl -JobUrl $JobUrl
    $evidenceItems = @()

    foreach ($producer in @($manifest.producers)) {
        $inputReport = $null
        if (Test-Path -LiteralPath $resolvedInputDirectory) {
            $candidatePath = Join-Path -Path $resolvedInputDirectory -ChildPath ("{0}.json" -f $producer.id)
            if (Test-Path -LiteralPath $candidatePath) {
                $inputReport = Read-KitEvidenceJsonFile -Path $candidatePath
            }
        }

        $evidenceItems += New-KitEvidenceItem -Producer $producer -InputReport $inputReport -DefaultSource $defaultSource -GeneratedAt $generatedAt
    }

    $stageSummaries = @()
    foreach ($stage in @($manifest.stages)) {
        $stageSummaries += New-KitEvidenceStageSummary -Stage ([string]$stage) -EvidenceItems $evidenceItems
    }

    $failedCount = @($evidenceItems | Where-Object { $_.status -eq "failed" }).Count
    $manualCount = @($evidenceItems | Where-Object { $_.status -eq "manual" }).Count
    $notCapturedCount = @($evidenceItems | Where-Object { $_.status -eq "not-captured" }).Count
    $status = "passed"
    if ($failedCount -gt 0) {
        $status = "failed"
    } elseif ($manualCount -gt 0) {
        $status = "manual"
    } elseif ($notCapturedCount -gt 0) {
        $status = "not-captured"
    }

    [pscustomobject][ordered]@{
        reportType = "evidence-chain"
        schemaVersion = 1
        generatedAt = $generatedAt.ToString("s")
        repository = $Repository
        chainId = [string]$manifest.chainId
        source = $defaultSource
        status = $status
        summary = [pscustomobject][ordered]@{
            stageCount = @($manifest.stages).Count
            producerCount = @($manifest.producers).Count
            passedCount = @($evidenceItems | Where-Object { $_.status -eq "passed" }).Count
            failedCount = $failedCount
            manualCount = $manualCount
            notCapturedCount = $notCapturedCount
        }
        stages = @($stageSummaries)
        evidence = @($evidenceItems)
        safety = [pscustomobject][ordered]@{
            trueExecution = $false
            localPrivateIncluded = $false
            networkUsed = $false
            mutationUsed = $false
        }
    }
}
