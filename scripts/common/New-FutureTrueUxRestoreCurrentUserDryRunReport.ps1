#Requires -Version 5.1

. "$PSScriptRoot\New-FutureTrueUxRestoreAuthorizationReport.ps1"

function Get-FutureTrueUxRestoreCurrentUserEvidenceContract {
    [pscustomobject][ordered]@{
        redactedUserIdentity = "required"
        beforeEvidence = "required"
        dryRunCommandEnvelope = "required"
        rollbackPlan = "required"
        afterEvidencePlaceholder = "required"
        independentVerificationPlaceholder = "required"
        failurePropagation = "required"
        reviewCheckpoint = "required"
        privatePathRedacted = $true
        currentUserConfirmed = $false
        trueExecution = $false
        mutationCount = 0
    }
}

function New-FutureTrueUxRestoreCurrentUserDryRunReport {
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

    $section = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "currentUserDryRun" -DefaultValue $null
    $requiredEvidence = @()
    if ($null -ne $section) {
        $requiredEvidence = @($section.requiredEvidence | ForEach-Object { [string]$_ })
    }

    $missingFields = @()
    foreach ($field in $requiredEvidence) {
        $value = Get-FutureTrueUxRestoreValue -InputObject $Request -Name $field -DefaultValue $null
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
            $missingFields += $field
        }
    }

    $blockedReasons = @()
    if ($null -eq $section) {
        $blockedReasons += "currentUserDryRun manifest section is missing"
    }

    if ($missingFields.Count -gt 0) {
        $blockedReasons += "missing current-user evidence fields: $($missingFields -join ', ')"
    }

    $scope = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "scope" -DefaultValue "")
    if ($scope -ne "current-user") {
        $blockedReasons += "scope must be current-user"
    }

    $claimedScope = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "claimedScope" -DefaultValue "current-user")
    if ($claimedScope -ne "current-user") {
        $blockedReasons += "scope guard blocked $claimedScope evidence claim for current-user"
    }

    $authorizationRequested = [bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "authorizationApproved" -DefaultValue $false)
    $executionRequested = [bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "executionApproved" -DefaultValue $false)
    if ($authorizationRequested -or $executionRequested) {
        $blockedReasons += "dual approval gate is frozen in this stage"
    }
    if ($authorizationRequested -and -not $executionRequested) {
        $blockedReasons += "authorization approval without execution approval cannot execute"
    }
    if ($executionRequested -and -not $authorizationRequested) {
        $blockedReasons += "execution approval without authorization approval cannot execute"
    }

    if ($null -ne $section) {
        foreach ($flagName in @("authorizationApproved", "executionApproved", "allowCurrentUserMutation", "allowDefaultUserFallback", "allowMachineFallback", "allowOfflineImageFallback")) {
            if ([bool](Get-FutureTrueUxRestoreValue -InputObject $section -Name $flagName -DefaultValue $false)) {
                $blockedReasons += "manifest $flagName must remain false"
            }
        }
    }

    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "mutationRequested" -DefaultValue $false)) {
        $blockedReasons += "current-user mutation request is blocked"
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

    $privatePathMatches = @(Test-FutureTrueUxRestorePrivatePath -InputObject $Request)
    if ($privatePathMatches.Count -gt 0) {
        $blockedReasons += "private profile path must be redacted"
    }

    $decision = "dry-run-ready"
    $hardBlockPatterns = @(
        "currentUserDryRun manifest section is missing",
        "scope must be current-user",
        "scope guard blocked",
        "dual approval gate is frozen",
        "cannot execute",
        "must remain false",
        "mutation request",
        "command exit code",
        "manual checklist",
        "handler report",
        "private profile path"
    )
    foreach ($reason in $blockedReasons) {
        foreach ($pattern in $hardBlockPatterns) {
            if ($reason -match [regex]::Escape($pattern)) {
                $decision = "blocked"
            }
        }
    }

    if ($missingFields.Count -gt 0) {
        $decision = "blocked"
    }

    [pscustomobject][ordered]@{
        reportType = "future-true-ux-restore-current-user-dry-run"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        scope = "current-user"
        decision = $decision
        authorizationApproved = $false
        executionApproved = $false
        missingFields = @($missingFields)
        blockedReasons = @($blockedReasons)
        evidenceContract = Get-FutureTrueUxRestoreCurrentUserEvidenceContract
        privatePathMatchCount = $privatePathMatches.Count
        trueExecution = $false
        mutationCount = 0
        commandExitCodeSufficient = $false
        userConfigurationConfirmed = $false
        currentUserConfirmed = $false
        safety = [pscustomobject][ordered]@{
            currentUserMutation = $false
            defaultUserFallback = $false
            machineFallback = $false
            offlineImageFallback = $false
            trueExecution = $false
        }
    }
}
