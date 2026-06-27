#Requires -Version 5.1

. "$PSScriptRoot\New-FutureTrueUxRestoreAuthorizationReport.ps1"

function Get-FutureTrueUxRestoreReviewEvidencePacket {
    param(
        [AllowNull()]
        $Request
    )

    $packet = Get-FutureTrueUxRestoreValue -InputObject $Request -Name "evidencePacket" -DefaultValue $null
    if ($null -ne $packet) {
        return $packet
    }

    return $Request
}

function New-FutureTrueUxRestoreAuthorizationReviewReport {
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

    $section = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "authorizationReview" -DefaultValue $null
    $packet = Get-FutureTrueUxRestoreReviewEvidencePacket -Request $Request
    $requiredFields = @()
    if ($null -ne $section) {
        $requiredFields = @($section.requiredPacketFields | ForEach-Object { [string]$_ })
    }

    $missingFields = @()
    foreach ($field in $requiredFields) {
        $value = Get-FutureTrueUxRestoreValue -InputObject $packet -Name $field -DefaultValue $null
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
            $missingFields += $field
        }
    }

    $blockedReasons = @()
    if ($null -eq $section) {
        $blockedReasons += "authorizationReview manifest section is missing"
    }

    if ($missingFields.Count -gt 0) {
        $blockedReasons += "missing evidence packet fields: $($missingFields -join ', ')"
    }

    $scope = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "scope" -DefaultValue "")
    $packetScope = [string](Get-FutureTrueUxRestoreValue -InputObject $packet -Name "scope" -DefaultValue "")
    $validScopes = @("current-user", "default-user", "offline-image", "machine")
    if ($validScopes -notcontains $scope) {
        $blockedReasons += "request scope must name exactly one supported scope"
    }
    if ($scope -ne $packetScope) {
        $blockedReasons += "scope guard blocked packet scope $packetScope for request scope $scope"
    }

    $scopeGuardAssertion = [string](Get-FutureTrueUxRestoreValue -InputObject $packet -Name "scopeGuardAssertion" -DefaultValue "")
    if ($scopeGuardAssertion -ne $scope) {
        $blockedReasons += "scope guard assertion must match request scope"
    }

    $alternateScopes = @(Get-FutureTrueUxRestoreValue -InputObject $Request -Name "scopes" -DefaultValue @())
    if ($alternateScopes.Count -gt 0) {
        $blockedReasons += "authorization review request must not include multiple scopes"
    }

    $reviewDecision = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "reviewDecision" -DefaultValue "blocked")
    $allowedReviewDecisions = @()
    $forbiddenReviewDecisions = @("execute-ready")
    if ($null -ne $section) {
        $allowedReviewDecisions = @($section.allowedReviewDecisions | ForEach-Object { [string]$_ })
        $forbiddenReviewDecisions = @($section.forbiddenReviewDecisions | ForEach-Object { [string]$_ })
    }
    if ($forbiddenReviewDecisions -contains $reviewDecision) {
        $blockedReasons += "review decision $reviewDecision is forbidden in this stage"
    }
    if ($allowedReviewDecisions.Count -gt 0 -and $allowedReviewDecisions -notcontains $reviewDecision) {
        $blockedReasons += "review decision $reviewDecision is not allowed in this stage"
    }

    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "authorizationApproved" -DefaultValue $false)) {
        $blockedReasons += "authorization approval request is blocked in this stage"
    }
    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "executionApproved" -DefaultValue $false)) {
        $blockedReasons += "execution approval request is blocked in this stage"
    }
    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "executeReady" -DefaultValue $false)) {
        $blockedReasons += "execute-ready request is blocked in this stage"
    }

    if ($null -ne $section) {
        foreach ($flagName in @("authorizationApproved", "executionApproved", "executeReady")) {
            if ([bool](Get-FutureTrueUxRestoreValue -InputObject $section -Name $flagName -DefaultValue $false)) {
                $blockedReasons += "manifest $flagName must remain false"
            }
        }
    }

    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "exitCodeOnlySuccess" -DefaultValue $false)) {
        $blockedReasons += "command exit code alone is not UX success evidence"
    }
    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "manualChecklistAsSuccess" -DefaultValue $false)) {
        $blockedReasons += "manual checklist is not real UX evidence"
    }
    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "handlerReportAsSuccess" -DefaultValue $false)) {
        $blockedReasons += "handler report is not real UX evidence"
    }
    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "dryRunReportAsSuccess" -DefaultValue $false)) {
        $blockedReasons += "dry-run report is not real UX evidence"
    }

    $privatePathMatches = @(Test-FutureTrueUxRestorePrivatePath -InputObject $Request)
    if ($privatePathMatches.Count -gt 0) {
        $blockedReasons += "private path must be redacted"
    }

    $allStrings = @($Request | Get-FutureTrueUxRestoreStrings)
    foreach ($value in $allStrings) {
        if ($value -match '(?i)\b(fixes|closes|resolves)\s+#18\b') {
            $blockedReasons += "auto-close keyword is blocked for Issue #18"
            break
        }
    }

    $evidencePacketStatus = "complete"
    if ($missingFields.Count -gt 0) {
        $evidencePacketStatus = "incomplete"
    }

    $decision = $reviewDecision
    if ($blockedReasons.Count -gt 0) {
        $decision = "blocked"
    }

    [pscustomobject][ordered]@{
        reportType = "future-true-ux-restore-authorization-review"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        scope = $scope
        reviewDecision = $decision
        requestedReviewDecision = $reviewDecision
        missingPacketFields = @($missingFields)
        blockedReasons = @($blockedReasons)
        evidencePacketStatus = $evidencePacketStatus
        authorizationApproved = $false
        executionApproved = $false
        executeReady = $false
        trueExecution = $false
        mutationCount = 0
        commandExitCodeSufficient = $false
        userConfigurationConfirmed = $false
        privatePathMatchCount = $privatePathMatches.Count
        allowedReviewDecisions = @($allowedReviewDecisions)
        forbiddenReviewDecisions = @($forbiddenReviewDecisions)
        evidencePacket = [pscustomobject][ordered]@{
            scope = $packetScope
            targetIdentity = [string](Get-FutureTrueUxRestoreValue -InputObject $packet -Name "targetIdentity" -DefaultValue "")
            requestedMutationType = [string](Get-FutureTrueUxRestoreValue -InputObject $packet -Name "requestedMutationType" -DefaultValue "")
            scopeGuardAssertion = $scopeGuardAssertion
            executeReady = $false
            trueExecution = $false
            mutationCount = 0
            userConfigurationConfirmed = $false
        }
    }
}
