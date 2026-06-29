#Requires -Version 5.1

. "$PSScriptRoot\New-FutureTrueUxRestoreAuthorizationReport.ps1"

function Get-FutureTrueUxRestoreAuditText {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function New-FutureTrueUxRestoreAuditPattern {
    param(
        [Parameter(Mandatory)]
        [string[]]$Parts
    )

    [regex]::Escape(($Parts -join ""))
}

function New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [AllowNull()]
        $Request,

        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $section = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "endToEndNoExecutionReadinessAudit" -DefaultValue $null
    $requiredLayers = @(
        "authorization-intake",
        "current-user-dry-run",
        "default-user-dry-run",
        "offline-image-dry-run",
        "machine-dry-run",
        "authorization-review",
        "mock-review-drill",
        "negative-review-drill",
        "approval-checklist-ergonomics",
        "integrated-packet-preview",
        "human-authorization-handoff"
    )
    $forbiddenStates = @("execute-ready", "executed", "completed", "issue-18-complete", "closure-ready")
    if ($null -ne $section) {
        $requiredLayers = @($section.requiredLayers | ForEach-Object { [string]$_ })
        $forbiddenStates = @($section.forbiddenStates | ForEach-Object { [string]$_ })
    }

    $caseId = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "caseId" -DefaultValue "repo-state")
    $requestedDecision = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "auditDecision" -DefaultValue "audit-ready")
    $blockingReasons = @()
    $needsReworkReasons = @()

    if ($null -eq $section) {
        $blockingReasons += "endToEndNoExecutionReadinessAudit manifest section is missing"
    } elseif ($section.enabled -ne $true) {
        $blockingReasons += "endToEndNoExecutionReadinessAudit must remain enabled"
    }

    $layerManifestMap = [ordered]@{
        "authorization-intake" = $Manifest
        "current-user-dry-run" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "currentUserDryRun" -DefaultValue $null
        "default-user-dry-run" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "defaultUserDryRun" -DefaultValue $null
        "offline-image-dry-run" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "offlineImageDryRun" -DefaultValue $null
        "machine-dry-run" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "machineDryRun" -DefaultValue $null
        "authorization-review" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "authorizationReview" -DefaultValue $null
        "mock-review-drill" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "mockReviewDrill" -DefaultValue $null
        "negative-review-drill" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "negativeReviewDrill" -DefaultValue $null
        "approval-checklist-ergonomics" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "approvalChecklistErgonomics" -DefaultValue $null
        "integrated-packet-preview" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "integratedPacketPreview" -DefaultValue $null
        "human-authorization-handoff" = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "humanAuthorizationHandoff" -DefaultValue $null
    }

    $omittedLayers = @((Get-FutureTrueUxRestoreValue -InputObject $Request -Name "omittedLayers" -DefaultValue @()) | ForEach-Object { [string]$_ })
    $missingLayers = @()
    foreach ($layer in $requiredLayers) {
        if ($omittedLayers -contains $layer -or $null -eq $layerManifestMap[$layer]) {
            $missingLayers += $layer
        }
    }
    if ($missingLayers.Count -gt 0) {
        $needsReworkReasons += "missing required layers: $($missingLayers -join ', ')"
    }

    $flagDrift = @()
    foreach ($layer in $requiredLayers) {
        $layerObject = $layerManifestMap[$layer]
        if ($null -eq $layerObject) {
            continue
        }

        foreach ($flagName in @("authorizationApproved", "executionApproved", "executeReady", "trueExecution")) {
            if ([bool](Get-FutureTrueUxRestoreValue -InputObject $layerObject -Name $flagName -DefaultValue $false)) {
                $flagDrift += "$layer.$flagName"
            }
        }
        if ([int](Get-FutureTrueUxRestoreValue -InputObject $layerObject -Name "mutationCount" -DefaultValue 0) -ne 0) {
            $flagDrift += "$layer.mutationCount"
        }
    }
    foreach ($flagName in @("authorizationApproved", "executionApproved", "executeReady", "trueExecution")) {
        if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name $flagName -DefaultValue $false)) {
            $flagDrift += "request.$flagName"
        }
        if ($null -ne $section -and [bool](Get-FutureTrueUxRestoreValue -InputObject $section -Name $flagName -DefaultValue $false)) {
            $flagDrift += "audit.$flagName"
        }
    }
    if ([int](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "mutationCount" -DefaultValue 0) -ne 0) {
        $flagDrift += "request.mutationCount"
    }
    if ($null -ne $section -and [int](Get-FutureTrueUxRestoreValue -InputObject $section -Name "mutationCount" -DefaultValue 0) -ne 0) {
        $flagDrift += "audit.mutationCount"
    }
    if ($flagDrift.Count -gt 0) {
        $blockingReasons += "execution flags drifted: $($flagDrift -join ', ')"
    }

    $qualityGatePath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path "manifests/quality-gates.json"
    $qualityGateIds = @()
    if (Test-Path -LiteralPath $qualityGatePath) {
        $qualityGateIds = @((Get-Content -LiteralPath $qualityGatePath -Raw -Encoding UTF8 | ConvertFrom-Json).gates.id)
    }
    $requiredGateIds = @(
        "future-true-ux-restore-authorization",
        "future-true-ux-current-user-dry-run",
        "future-true-ux-scope-dry-run",
        "future-true-ux-authorization-review",
        "future-true-ux-mock-review-drill",
        "future-true-ux-negative-review-drill",
        "future-true-ux-approval-checklist-ergonomics",
        "future-true-ux-integrated-packet-preview",
        "future-true-ux-human-authorization-handoff",
        "future-true-ux-end-to-end-no-execution-readiness-audit"
    )
    $missingGateIds = @()
    foreach ($gateId in $requiredGateIds) {
        if ($qualityGateIds -notcontains $gateId) {
            $missingGateIds += $gateId
        }
    }
    if ($missingGateIds.Count -gt 0) {
        $needsReworkReasons += "missing quality gates: $($missingGateIds -join ', ')"
    }

    $requiredDocs = @(
        @{ Path = "docs/archive/future-true-ux-restore/06-no-execution-audit/102-future-true-ux-restore-end-to-end-no-execution-readiness-audit.md"; Status = "end-to-end-no-execution-readiness-audit" },
        @{ Path = "docs/archive/future-true-ux-restore/06-no-execution-audit/103-future-true-ux-restore-state-name-separation-matrix.md"; Status = "state-name-separation-matrix" },
        @{ Path = "docs/archive/future-true-ux-restore/06-no-execution-audit/104-future-true-ux-restore-artifact-chain-consistency-index.md"; Status = "artifact-chain-consistency-index" },
        @{ Path = "docs/archive/future-true-ux-restore/06-no-execution-audit/105-future-true-ux-restore-no-execution-stop-line.md"; Status = "no-execution-stop-line" }
    )
    $missingDocs = @()
    $missingDocStatuses = @()
    foreach ($doc in $requiredDocs) {
        $resolvedDoc = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path $doc.Path
        $text = Get-FutureTrueUxRestoreAuditText -Path $resolvedDoc
        if ([string]::IsNullOrWhiteSpace($text)) {
            $missingDocs += $doc.Path
        } elseif ($text -notmatch ('Status:\s*`{0}`' -f [regex]::Escape($doc.Status))) {
            $missingDocStatuses += $doc.Path
        }
    }
    if ($missingDocs.Count -gt 0) {
        $needsReworkReasons += "missing audit docs: $($missingDocs -join ', ')"
    }
    if ($missingDocStatuses.Count -gt 0) {
        $needsReworkReasons += "missing audit doc status markers: $($missingDocStatuses -join ', ')"
    }

    $docRoot = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path "docs"
    $futureDocs = @(Get-ChildItem -LiteralPath $docRoot -Filter "*future-true-ux-restore*.md" -Recurse | Where-Object { $_.Name -match '^\d+' })
    $autoCloseMatches = @()
    $statePromotionMatches = @()
    $evidencePromotionMatches = @()
    $stopLineSeen = $false
    foreach ($docFile in $futureDocs) {
        $text = Get-FutureTrueUxRestoreAuditText -Path $docFile.FullName
        if ($text -match '(?i)\b(fixes|closes|resolves)\s+#18\b') {
            $autoCloseMatches += $docFile.Name
        }
        if ($text -match '(?i)\b(no-execution stop line|stops before human authorization|stops at review readiness)\b') {
            $stopLineSeen = $true
        }
        foreach ($line in @($text -split "`r?`n")) {
            if ($line -match '(?i)\b(handoff-ready-for-human-review|packet-preview-ready|approval-checklist-ready|authorization-review-ready)\b.*\b(is|becomes|promotes to|counts as)\b.*\b(authorization-review-ready|execute-ready|closure-ready)\b' -and $line -notmatch '(?i)\bnot\b') {
                $statePromotionMatches += "$($docFile.Name): $line"
            }
            if ($line -match '(?i)\b(CI|dry-run|handler report|manual checklist|mock packet|negative drill|approval checklist|packet preview|handoff report)\b.*\b(is|counts as|promotes to|can be treated as)\b.*\b(true UX restore evidence|real restore evidence|real UX evidence)\b' -and $line -notmatch '(?i)\bnot\b') {
                $evidencePromotionMatches += "$($docFile.Name): $line"
            }
        }
    }
    if ($autoCloseMatches.Count -gt 0) {
        $blockingReasons += "Issue 18 auto-close terms found: $($autoCloseMatches -join ', ')"
    }
    if ($statePromotionMatches.Count -gt 0) {
        $blockingReasons += "state promotion wording found"
    }
    if ($evidencePromotionMatches.Count -gt 0) {
        $needsReworkReasons += "review material promoted into real evidence"
    }

    $requestText = (@($Request | Get-FutureTrueUxRestoreStrings) -join "`n")
    if ($requestText -match '(?i)\b(fixes|closes|resolves)\s+#18\b') {
        $blockingReasons += "request contains Issue 18 auto-close wording"
    }
    if ($requestText -match '(?i)\b(handoff-ready-for-human-review|packet-preview-ready|approval-checklist-ready|authorization-review-ready)\b.*\b(is|becomes|promotes to|counts as)\b.*\b(authorization-review-ready|execute-ready|closure-ready)\b' -and $requestText -notmatch '(?i)\bnot\b') {
        $blockingReasons += "request promotes separated states"
    }
    if ($requestText -match '(?i)\b(CI|dry-run|handler report|manual checklist|mock packet|negative drill|approval checklist|packet preview|handoff report)\b.*\b(is|counts as|promotes to|can be treated as)\b.*\b(true UX restore evidence|real restore evidence|real UX evidence)\b' -and $requestText -notmatch '(?i)\bnot\b') {
        $needsReworkReasons += "request promotes review material into real evidence"
    }

    $commandPatterns = @(
        (New-FutureTrueUxRestoreAuditPattern -Parts @("Start", "-", "Process")),
        (New-FutureTrueUxRestoreAuditPattern -Parts @("Invoke", "-", "Expression")),
        (New-FutureTrueUxRestoreAuditPattern -Parts @("Set", "-", "Item", "Property")),
        (New-FutureTrueUxRestoreAuditPattern -Parts @("New", "-", "Item", "Property")),
        (New-FutureTrueUxRestoreAuditPattern -Parts @("Remove", "-", "Appx", "Package")),
        (New-FutureTrueUxRestoreAuditPattern -Parts @("Add", "-", "Mp", "Preference")),
        "\b$(([char]100).ToString())$(([char]105).ToString())$(([char]115).ToString())$(([char]109).ToString())\b",
        "\b$(([char]119).ToString())$(([char]105).ToString())$(([char]110).ToString())$(([char]103).ToString())$(([char]101).ToString())$(([char]116).ToString())\b",
        "\b$(([char]99).ToString())$(([char]104).ToString())$(([char]111).ToString())$(([char]99).ToString())$(([char]111).ToString())\b",
        "\b$(([char]109).ToString())$(([char]115).ToString())$(([char]105).ToString())$(([char]101).ToString())$(([char]120).ToString())$(([char]101).ToString())$(([char]99).ToString())\b",
        (New-FutureTrueUxRestoreAuditPattern -Parts @("Invoke", "-", "Web", "Request")),
        (New-FutureTrueUxRestoreAuditPattern -Parts @("Invoke", "-", "Rest", "Method")),
        (New-FutureTrueUxRestoreAuditPattern -Parts @("Install", "-", "Module"))
    )
    $scriptScanPaths = @(
        "scripts/common/New-FutureTrueUxRestoreEndToEndNoExecutionReadinessAuditReport.ps1",
        "scripts/validate/Test-FutureTrueUxRestoreEndToEndNoExecutionReadinessAudit.ps1"
    )
    $dangerousScriptMatches = @()
    foreach ($relativePath in $scriptScanPaths) {
        $scriptPath = Resolve-FutureTrueUxRestoreRepoPath -RepoRoot $RepoRoot -Path $relativePath
        $scriptText = Get-FutureTrueUxRestoreAuditText -Path $scriptPath
        foreach ($pattern in $commandPatterns) {
            if ($scriptText -match $pattern) {
                $dangerousScriptMatches += "$relativePath"
                break
            }
        }
    }
    $dangerousRequestMatches = @()
    foreach ($pattern in $commandPatterns) {
        if ($requestText -match $pattern) {
            $dangerousRequestMatches += $pattern
        }
    }
    if ($dangerousScriptMatches.Count -gt 0) {
        $blockingReasons += "dangerous command vocabulary found in audit scripts: $($dangerousScriptMatches -join ', ')"
    }
    if ($dangerousRequestMatches.Count -gt 0) {
        $blockingReasons += "dangerous command vocabulary found in request"
    }

    $closurePrepMatches = @()
    foreach ($docFile in $futureDocs) {
        if ($docFile.Name -match '(?i)(completion-summary|close-preparation|main-validation-evidence|main-evidence|closure-ready)') {
            $closurePrepMatches += $docFile.Name
        }
    }
    if ($closurePrepMatches.Count -gt 0) {
        $blockingReasons += "Future True UX Restore closure-prep artifact found: $($closurePrepMatches -join ', ')"
    }

    $requiresStopLine = [bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "requiresRunnerStopLine" -DefaultValue $false)
    $hasFixtureStopLine = [bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "hasRunnerStopLine" -DefaultValue $true)
    if ((-not $stopLineSeen) -or ($requiresStopLine -and -not $hasFixtureStopLine)) {
        $needsReworkReasons += "no-execution stop-line language is missing"
    }

    $decision = $requestedDecision
    if ($blockingReasons.Count -gt 0) {
        $decision = "blocked"
    } elseif ($needsReworkReasons.Count -gt 0) {
        $decision = "needs-rework"
    }

    [pscustomobject][ordered]@{
        reportType = "future-true-ux-restore-end-to-end-no-execution-readiness-audit"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        caseId = $caseId
        auditDecision = $decision
        requestedAuditDecision = $requestedDecision
        requiredLayers = @($requiredLayers)
        missingLayers = @($missingLayers)
        forbiddenStates = @($forbiddenStates)
        flagDrift = @($flagDrift)
        missingQualityGates = @($missingGateIds)
        missingDocs = @($missingDocs)
        missingDocStatuses = @($missingDocStatuses)
        autoCloseMatches = @($autoCloseMatches)
        statePromotionMatches = @($statePromotionMatches)
        evidencePromotionMatches = @($evidencePromotionMatches)
        dangerousScriptMatches = @($dangerousScriptMatches)
        dangerousRequestMatchCount = $dangerousRequestMatches.Count
        closurePrepMatches = @($closurePrepMatches)
        stopLineSeen = [bool]$stopLineSeen
        blockingReasons = @($blockingReasons)
        needsReworkReasons = @($needsReworkReasons)
        authorizationApproved = $false
        executionApproved = $false
        executeReady = $false
        trueExecution = $false
        mutationCount = 0
    }
}
