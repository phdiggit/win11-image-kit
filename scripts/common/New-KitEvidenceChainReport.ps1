#Requires -Version 5.1

. "$PSScriptRoot\New-KitEvidenceArtifactIndex.ps1"
. "$PSScriptRoot\Test-KitEvidenceRedaction.ps1"
. "$PSScriptRoot\Read-KitEvidenceReportInputs.ps1"
. "$PSScriptRoot\ConvertTo-KitEvidenceProducerItem.ps1"

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

function New-KitEvidenceRunId {
    param(
        [datetime]$GeneratedAt,

        [string]$SourceSha
    )

    $shortSha = "0000000"
    if (-not [string]::IsNullOrWhiteSpace($SourceSha) -and $SourceSha -match '^[A-Fa-f0-9]{7,40}$') {
        $shortSha = $SourceSha.Substring(0, [Math]::Min(8, $SourceSha.Length)).ToLowerInvariant()
    }

    "kit-run-{0}-{1}" -f $GeneratedAt.ToUniversalTime().ToString("yyyyMMddTHHmmssZ"), $shortSha
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
        runId = if ($items.Count -gt 0) { [string]@($items)[0].runId } else { "not-captured" }
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
        [datetime]$GeneratedAt,

        [Parameter(Mandatory)]
        [string]$RunId,

        [string]$UpstreamRunId
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
    $itemRunId = $RunId
    if ($status -eq "not-captured") {
        $itemRunId = "not-captured"
    } elseif ($status -eq "manual") {
        $itemRunId = "manual"
    }

    $item = [ordered]@{
        id = "evidence.$producerId"
        stage = [string]$Producer.stage
        producerId = $producerId
        producerMode = $producerMode
        entrypoint = [string]$Producer.entrypoint
        reportType = [string]$Producer.reportType
        status = $status
        generatedAt = $inputGeneratedAt
        runId = $itemRunId
        manual = [bool]$manual
        reproducible = $reproducible
        reason = [string](Get-KitEvidenceValue -InputObject $Producer -Name "manualReason" -DefaultValue ([string]$Producer.notes))
        sourceMetadata = $source
        artifactReferences = @($artifactReferences)
    }

    if (-not [string]::IsNullOrWhiteSpace($UpstreamRunId) -and $itemRunId -ne $RunId) {
        $item["upstreamRunId"] = $UpstreamRunId
    }

    [pscustomobject]$item
}

function New-KitEvidenceLifecycle {
    param(
        [Parameter(Mandatory)]
        [string]$RunId
    )

    [pscustomobject][ordered]@{
        configRunId = $RunId
        validateRunId = $RunId
        buildRunId = "not-captured"
        captureRunId = "not-captured"
        deployRunId = "not-captured"
        acceptanceRunId = "manual"
    }
}

function New-KitEvidenceStageLinks {
    param(
        [Parameter(Mandatory)]
        [string]$RunId,

        [string]$UpstreamRunId
    )

    $links = @()
    foreach ($stage in @("config", "validate")) {
        $entry = [ordered]@{
            stage = $stage
            runId = $RunId
        }
        if (-not [string]::IsNullOrWhiteSpace($UpstreamRunId)) {
            $entry["upstreamRunId"] = $UpstreamRunId
        }
        $links += [pscustomobject]$entry
    }

    foreach ($stage in @("build", "capture", "deploy")) {
        $links += [pscustomobject][ordered]@{
            stage = $stage
            runId = "not-captured"
            upstreamRunId = $RunId
        }
    }

    $links += [pscustomobject][ordered]@{
        stage = "acceptance"
        runId = "manual"
        upstreamRunId = $RunId
    }

    @($links)
}

function New-KitEvidenceChainReport {
    [CmdletBinding()]
    param(
        [string]$ManifestPath = "manifests/evidence-chain.json",

        [string]$InputManifestPath = "manifests/evidence-report-inputs.json",

        [string]$InputDirectory = "tests/fixtures/evidence-chain/sample-report-inputs",

        [ValidateSet("fixture", "local", "ci", "main", "workflow_dispatch", "manual")]
        [string]$SourceKind = "fixture",

        [string]$SourceSha,

        [string]$WorkflowRunUrl,

        [string]$JobUrl,

        [string]$RunId,

        [string]$UpstreamRunId,

        [string]$ArtifactIndexPath = "tests/fixtures/evidence-chain/sample-artifact-index.json",

        [string]$Repository = "phdiggit/win11-image-kit",

        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $resolvedManifestPath = Resolve-KitEvidenceRepoPath -RepoRoot $RepoRoot -Path $ManifestPath
    $manifest = Read-KitEvidenceJsonFile -Path $resolvedManifestPath
    $generatedAt = (Get-Date).ToUniversalTime()
    if ([string]::IsNullOrWhiteSpace($RunId)) {
        $RunId = New-KitEvidenceRunId -GeneratedAt $generatedAt -SourceSha $SourceSha
    }

    $defaultSource = New-KitEvidenceSource -SourceKind $SourceKind -SourceSha $SourceSha -WorkflowRunUrl $WorkflowRunUrl -JobUrl $JobUrl
    $evidenceItems = @()
    $inputReadResult = Read-KitEvidenceReportInputs -RepoRoot $RepoRoot -Manifest $manifest -InputManifestPath $InputManifestPath -InputDirectory $InputDirectory
    $inputRecordsByProducer = @{}
    foreach ($inputRecord in @($inputReadResult.inputs)) {
        if (-not $inputRecordsByProducer.ContainsKey([string]$inputRecord.producerId)) {
            $inputRecordsByProducer[[string]$inputRecord.producerId] = $inputRecord
        }
    }

    $normalizationResults = @()

    foreach ($producer in @($manifest.producers)) {
        $inputRecord = $null
        if ($inputRecordsByProducer.ContainsKey([string]$producer.id)) {
            $inputRecord = $inputRecordsByProducer[[string]$producer.id]
        } elseif ([bool]$producer.required -and [string]$producer.mode -ne "manual") {
            $inputRecord = [pscustomobject][ordered]@{
                producerId = [string]$producer.id
                path = ""
                expectedReportType = [string]$producer.reportType
                required = $true
                allowMissing = $false
                allowManual = $false
                allowNotCaptured = $false
                exists = $false
                report = $null
                errors = @()
            }
        }

        $normalization = ConvertTo-KitEvidenceProducerItem `
            -Producer $producer `
            -InputRecord $inputRecord `
            -DefaultSource $defaultSource `
            -GeneratedAt $generatedAt `
            -RunId $RunId `
            -UpstreamRunId $RunId
        $normalizationResults += $normalization
        $evidenceItems += $normalization.item
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

    $artifactIndex = @(New-KitEvidenceArtifactIndex -ArtifactIndexPath $ArtifactIndexPath -RunId $RunId -UpstreamRunId $UpstreamRunId -RepoRoot $RepoRoot)
    $forbiddenFieldNames = @("password", "token", "secret", "privateKey", "credential", "username")
    $redactedValue = "<redacted>"
    if ($null -ne $manifest.redactionPolicy) {
        $forbiddenFieldNames = @($manifest.redactionPolicy.forbiddenFieldNames | ForEach-Object { [string]$_ })
        $redactedValue = [string]$manifest.redactionPolicy.redactedValue
    }

    $redactionResults = @()
    foreach ($inputRecord in @($inputReadResult.inputs)) {
        if ($null -ne $inputRecord.report) {
            $redactionResults += Test-KitEvidenceRedaction -InputObject $inputRecord.report -ForbiddenFieldNames $forbiddenFieldNames -RedactedValue $redactedValue
        }
    }
    $redactionResults += Test-KitEvidenceRedaction -InputObject $artifactIndex -ForbiddenFieldNames $forbiddenFieldNames -RedactedValue $redactedValue
    $artifactRedactedCount = @($artifactIndex | Where-Object { $_.redacted }).Count
    $blockedFields = @($redactionResults | ForEach-Object { $_.blockedFields })
    $redactions = [pscustomobject][ordered]@{
        redactedCount = ([int](@($redactionResults | Measure-Object -Property redactedCount -Sum).Sum) + $artifactRedactedCount)
        blockedCount = @($blockedFields).Count
        blockedFields = @($blockedFields)
    }

    $report = [ordered]@{
        reportType = "evidence-chain"
        schemaVersion = 1
        generatedAt = $generatedAt.ToString("s")
        repository = $Repository
        chainId = [string]$manifest.chainId
        runId = $RunId
        inputSetId = [string]$inputReadResult.inputSetId
        source = $defaultSource
        status = $status
        summary = [pscustomobject][ordered]@{
            stageCount = @($manifest.stages).Count
            producerCount = @($manifest.producers).Count
            passedCount = @($evidenceItems | Where-Object { $_.status -eq "passed" }).Count
            failedCount = $failedCount
            manualCount = $manualCount
            notCapturedCount = $notCapturedCount
            artifactCount = $artifactIndex.Count
        }
        stages = @($stageSummaries)
        evidence = @($evidenceItems)
        inputReports = @($inputReadResult.inputs | ForEach-Object {
            [pscustomobject][ordered]@{
                producerId = [string]$_.producerId
                path = [string]$_.path
                expectedReportType = [string]$_.expectedReportType
                required = [bool]$_.required
                allowMissing = [bool]$_.allowMissing
                allowManual = [bool]$_.allowManual
                allowNotCaptured = [bool]$_.allowNotCaptured
                exists = [bool]$_.exists
                reportType = if ($null -ne $_.report) { [string](Get-KitEvidenceValue -InputObject $_.report -Name "reportType" -DefaultValue "") } else { "" }
                status = if ($null -ne $_.report) { [string](Get-KitEvidenceValue -InputObject $_.report -Name "status" -DefaultValue "") } else { "missing" }
            }
        })
        producerNormalization = [pscustomobject][ordered]@{
            normalizedCount = [int](@($normalizationResults | Measure-Object -Property normalizedCount -Sum).Sum)
            missingRequiredCount = [int](@($normalizationResults | Measure-Object -Property missingRequiredCount -Sum).Sum)
            reportTypeMismatchCount = [int](@($normalizationResults | Measure-Object -Property reportTypeMismatchCount -Sum).Sum)
            disallowedManualCount = [int](@($normalizationResults | Measure-Object -Property disallowedManualCount -Sum).Sum)
            disallowedNotCapturedCount = [int](@($normalizationResults | Measure-Object -Property disallowedNotCapturedCount -Sum).Sum)
            inputPolicyViolationCount = [int](@($normalizationResults | Measure-Object -Property inputPolicyViolationCount -Sum).Sum) + [int]$inputReadResult.unmatchedInputCount
            unmatchedInputCount = [int]$inputReadResult.unmatchedInputCount
        }
        lifecycle = New-KitEvidenceLifecycle -RunId $RunId
        stageLinks = @(New-KitEvidenceStageLinks -RunId $RunId -UpstreamRunId $UpstreamRunId)
        artifactIndex = @($artifactIndex)
        redactions = $redactions
        safety = [pscustomobject][ordered]@{
            trueExecution = $false
            localPrivateIncluded = $false
            networkUsed = $false
            mutationUsed = $false
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($UpstreamRunId)) {
        $report["upstreamRunId"] = $UpstreamRunId
    }

    [pscustomobject]$report
}
