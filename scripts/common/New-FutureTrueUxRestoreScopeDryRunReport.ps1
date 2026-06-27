#Requires -Version 5.1

. "$PSScriptRoot\New-FutureTrueUxRestoreAuthorizationReport.ps1"

function Get-FutureTrueUxRestoreScopeProfile {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("current-user", "default-user", "offline-image", "machine")]
        [string]$Scope
    )

    $profiles = @{
        "current-user" = [pscustomobject][ordered]@{
            sectionName = "currentUserDryRun"
            confirmedName = "currentUserConfirmed"
            mutationFlagNames = @("authorizationApproved", "executionApproved", "allowCurrentUserMutation", "allowDefaultUserFallback", "allowMachineFallback", "allowOfflineImageFallback")
            requestMutationNames = @("mutationRequested", "currentUserMutationRequested")
            contractFields = @("redactedUserIdentity", "beforeEvidence", "dryRunCommandEnvelope", "rollbackPlan", "afterEvidencePlaceholder", "independentVerificationPlaceholder", "failurePropagation", "reviewCheckpoint")
        }
        "default-user" = [pscustomobject][ordered]@{
            sectionName = "defaultUserDryRun"
            confirmedName = "defaultUserConfirmed"
            mutationFlagNames = @("authorizationApproved", "executionApproved", "allowDefaultUserMutation", "allowCurrentUserFallback", "allowMachineFallback", "allowOfflineImageFallback")
            requestMutationNames = @("mutationRequested", "defaultUserMutationRequested", "hiveLoadRequested", "hiveWriteRequested", "profileWriteRequested")
            contractFields = @("templateSource", "defaultUserTargetIdentity", "beforeEvidence", "dryRunCommandEnvelope", "rollbackPlan", "afterEvidencePlaceholder", "independentVerificationPlaceholder", "failurePropagation", "reviewCheckpoint")
        }
        "offline-image" = [pscustomobject][ordered]@{
            sectionName = "offlineImageDryRun"
            confirmedName = "offlineImageConfirmed"
            mutationFlagNames = @("authorizationApproved", "executionApproved", "allowOfflineImageMutation", "allowCurrentMachineFallback", "allowCurrentUserFallback", "allowDefaultUserFallback")
            requestMutationNames = @("mutationRequested", "offlineImageMutationRequested", "mountRequested", "unmountRequested", "imageServicingRequested", "defaultAppImportRequested")
            contractFields = @("imageIdentity", "imageIndex", "mountPathPlaceholder", "beforeEvidence", "dryRunCommandEnvelope", "rollbackOrUnmountPlan", "afterEvidencePlaceholder", "independentVerificationPlaceholder", "failurePropagation", "reviewCheckpoint")
        }
        "machine" = [pscustomobject][ordered]@{
            sectionName = "machineDryRun"
            confirmedName = "machineConfirmed"
            mutationFlagNames = @("authorizationApproved", "executionApproved", "allowMachineMutation", "allowCurrentUserFallback", "allowDefaultUserFallback", "allowOfflineImageFallback")
            requestMutationNames = @("mutationRequested", "machineMutationRequested", "policyWriteRequested", "serviceRequested", "defenderRequested", "registryWriteRequested", "junctionRequested", "sysprepRequested")
            contractFields = @("machineIdentity", "machineSettingTarget", "beforeEvidence", "dryRunCommandEnvelope", "rollbackPlan", "afterEvidencePlaceholder", "independentVerificationPlaceholder", "adminOrVmSmokeBoundary", "failurePropagation", "reviewCheckpoint")
        }
    }

    return $profiles[$Scope]
}

function New-FutureTrueUxRestoreScopeEvidenceContract {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("current-user", "default-user", "offline-image", "machine")]
        [string]$Scope
    )

    $profile = Get-FutureTrueUxRestoreScopeProfile -Scope $Scope
    $contract = [ordered]@{}
    foreach ($field in $profile.contractFields) {
        $contract[$field] = "required"
    }
    $contract["privatePathRedacted"] = $true
    $contract[$profile.confirmedName] = $false
    $contract["trueExecution"] = $false
    $contract["mutationCount"] = 0
    [pscustomobject]$contract
}

function New-FutureTrueUxRestoreSingleScopeDryRunReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [AllowNull()]
        $Request,

        [Parameter(Mandatory)]
        [ValidateSet("current-user", "default-user", "offline-image", "machine")]
        [string]$Scope,

        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $profile = Get-FutureTrueUxRestoreScopeProfile -Scope $Scope
    $section = Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name $profile.sectionName -DefaultValue $null
    $requiredEvidence = @()
    if ($null -ne $section) {
        $requiredEvidence = @($section.requiredEvidence | ForEach-Object { [string]$_ })
    } else {
        $requiredEvidence = @($profile.contractFields)
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
        $blockedReasons += "$($profile.sectionName) manifest section is missing"
    }

    if ($missingFields.Count -gt 0) {
        $blockedReasons += "missing $Scope evidence fields: $($missingFields -join ', ')"
    }

    $requestScope = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "scope" -DefaultValue "")
    if ($requestScope -ne $Scope) {
        $blockedReasons += "scope must be $Scope"
    }

    $claimedScope = [string](Get-FutureTrueUxRestoreValue -InputObject $Request -Name "claimedScope" -DefaultValue $Scope)
    if ($claimedScope -ne $Scope) {
        $blockedReasons += "scope guard blocked $claimedScope evidence claim for $Scope"
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
        foreach ($flagName in @($profile.mutationFlagNames)) {
            if ([bool](Get-FutureTrueUxRestoreValue -InputObject $section -Name $flagName -DefaultValue $false)) {
                $blockedReasons += "manifest $flagName must remain false"
            }
        }
    }

    foreach ($requestFlagName in @($profile.requestMutationNames)) {
        if ([bool](Get-FutureTrueUxRestoreValue -InputObject $Request -Name $requestFlagName -DefaultValue $false)) {
            $blockedReasons += "$Scope mutation request is blocked: $requestFlagName"
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

    $decision = "dry-run-ready"
    if ($missingFields.Count -gt 0 -or $blockedReasons.Count -gt 0) {
        $decision = "blocked"
    }

    $safety = [ordered]@{
        scopeFallback = $false
        trueExecution = $false
    }
    foreach ($flagName in @($profile.mutationFlagNames)) {
        $safety[$flagName] = $false
    }

    $result = [ordered]@{
        reportType = "future-true-ux-restore-scope-dry-run"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        scope = $Scope
        decision = $decision
        authorizationApproved = $false
        executionApproved = $false
        missingFields = @($missingFields)
        blockedReasons = @($blockedReasons)
        evidenceContract = New-FutureTrueUxRestoreScopeEvidenceContract -Scope $Scope
        privatePathMatchCount = $privatePathMatches.Count
        trueExecution = $false
        mutationCount = 0
        commandExitCodeSufficient = $false
        userConfigurationConfirmed = $false
        safety = [pscustomobject]$safety
    }

    $result[$profile.confirmedName] = $false
    [pscustomobject]$result
}

function New-FutureTrueUxRestoreScopeDryRunReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [Parameter(Mandatory)]
        [hashtable]$RequestsByScope,

        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $scopes = @("current-user", "default-user", "offline-image", "machine")
    $scopeReports = @()
    foreach ($scope in $scopes) {
        $request = $null
        if ($RequestsByScope.ContainsKey($scope)) {
            $request = $RequestsByScope[$scope]
        }

        $scopeReports += New-FutureTrueUxRestoreSingleScopeDryRunReport -Manifest $Manifest -Request $request -Scope $scope -RepoRoot $RepoRoot
    }

    $blockedCount = @($scopeReports | Where-Object { $_.decision -eq "blocked" }).Count
    $dryRunReadyCount = @($scopeReports | Where-Object { $_.decision -eq "dry-run-ready" }).Count

    [pscustomobject][ordered]@{
        reportType = "future-true-ux-restore-scope-dry-run-aggregate"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        aggregateDecision = $(if ($blockedCount -gt 0) { "blocked" } else { "dry-run-ready" })
        blockedCount = $blockedCount
        dryRunReadyCount = $dryRunReadyCount
        scopeReports = @($scopeReports)
        trueExecution = $false
        mutationCount = 0
        commandExitCodeSufficient = $false
        userConfigurationConfirmed = $false
    }
}
