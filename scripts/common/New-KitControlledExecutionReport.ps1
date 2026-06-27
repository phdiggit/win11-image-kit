#Requires -Version 5.1

. "$PSScriptRoot\Test-KitControlledExecutionSafety.ps1"
. "$PSScriptRoot\ConvertTo-KitDiskIdentityPlan.ps1"
. "$PSScriptRoot\Test-KitConfirmationToken.ps1"
. "$PSScriptRoot\ConvertTo-KitWimImagePlan.ps1"
. "$PSScriptRoot\ConvertTo-KitWinREPlan.ps1"
. "$PSScriptRoot\New-KitNativeCommandPlan.ps1"
. "$PSScriptRoot\Test-KitControlledExecutionAuthorization.ps1"
. "$PSScriptRoot\Invoke-KitNativeCommandSimulation.ps1"

function Resolve-KitControlledExecutionRepoPath {
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

function New-KitControlledExecutionActionResult {
    param(
        [Parameter(Mandatory)]
        $Action,

        [Parameter(Mandatory)]
        [ValidateSet("planned", "blocked", "failed")]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Reason
    )

    [pscustomobject][ordered]@{
        id = [string](Get-KitControlledExecutionValue -InputObject $Action -Name "id" -DefaultValue "")
        stage = [string](Get-KitControlledExecutionValue -InputObject $Action -Name "stage" -DefaultValue "")
        mode = [string](Get-KitControlledExecutionValue -InputObject $Action -Name "mode" -DefaultValue "")
        entrypoint = [string](Get-KitControlledExecutionValue -InputObject $Action -Name "entrypoint" -DefaultValue "")
        status = $Status
        reason = $Reason
        riskLevel = [string](Get-KitControlledExecutionValue -InputObject $Action -Name "riskLevel" -DefaultValue "")
        requiresAdmin = [bool](Get-KitControlledExecutionValue -InputObject $Action -Name "requiresAdmin" -DefaultValue $false)
        requiresWinPE = [bool](Get-KitControlledExecutionValue -InputObject $Action -Name "requiresWinPE" -DefaultValue $false)
        requiresNetwork = [bool](Get-KitControlledExecutionValue -InputObject $Action -Name "requiresNetwork" -DefaultValue $false)
        requiresReboot = [bool](Get-KitControlledExecutionValue -InputObject $Action -Name "requiresReboot" -DefaultValue $false)
        mutationKind = [string](Get-KitControlledExecutionValue -InputObject $Action -Name "mutationKind" -DefaultValue "")
        evidenceProducer = [string](Get-KitControlledExecutionValue -InputObject $Action -Name "evidenceProducer" -DefaultValue "")
        dependsOn = @((Get-KitControlledExecutionValue -InputObject $Action -Name "dependsOn" -DefaultValue @()) | ForEach-Object { [string]$_ })
        executionPolicy = [string](Get-KitControlledExecutionValue -InputObject $Action -Name "executionPolicy" -DefaultValue "plan-only")
        executed = $false
    }
}

function New-KitControlledExecutionReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [string]$RepoRoot,

        [ValidateSet("dry-run", "what-if", "plan-only")]
        [string]$Mode,

        [AllowNull()]
        $DiskIdentity,

        [AllowNull()]
        $ConfirmationToken,

        [AllowNull()]
        $WimMetadata,

        [AllowNull()]
        $WinREPlan,

        [AllowNull()]
        $NativeCommandPlan,

        [AllowNull()]
        $Authorization,

        [AllowNull()]
        $NativeCommandSimulation,

        [switch]$WhatIf
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    if ([string]::IsNullOrWhiteSpace($Mode)) {
        $Mode = [string](Get-KitControlledExecutionValue -InputObject $Manifest -Name "defaultMode" -DefaultValue "dry-run")
    }

    $manifestErrors = @(Test-KitControlledExecutionSafety -Manifest $Manifest)
    $diskIdentityPlan = ConvertTo-KitDiskIdentityPlan -InputObject $DiskIdentity
    $confirmationTokenPlan = Test-KitConfirmationToken -InputObject $ConfirmationToken
    $wimImagePlan = ConvertTo-KitWimImagePlan -InputObject $WimMetadata
    $winREPlanResult = ConvertTo-KitWinREPlan -InputObject $WinREPlan
    $nativeCommandPlanResult = New-KitNativeCommandPlan -InputObject $NativeCommandPlan
    $authorizationResult = Test-KitControlledExecutionAuthorization -InputObject $Authorization
    $nativeCommandSimulationResult = Invoke-KitNativeCommandSimulation -InputObject $NativeCommandSimulation

    $results = @()
    $resultById = @{}

    foreach ($errorMessage in $manifestErrors) {
        $manifestResult = [pscustomobject][ordered]@{
            id = "manifest-safety"
            stage = "preflight"
            mode = "report-only"
            entrypoint = "manifests/controlled-execution.json"
            status = "failed"
            reason = $errorMessage
            riskLevel = "critical"
            requiresAdmin = $false
            requiresWinPE = $false
            requiresNetwork = $false
            requiresReboot = $false
            mutationKind = "none"
            evidenceProducer = "controlled-execution"
            dependsOn = @()
            executionPolicy = "plan-only"
            executed = $false
        }

        $results += $manifestResult
        $resultById[$manifestResult.id] = $manifestResult
    }

    foreach ($action in @($Manifest.actions)) {
        $entrypoint = [string](Get-KitControlledExecutionValue -InputObject $action -Name "entrypoint" -DefaultValue "")
        $mutationKind = [string](Get-KitControlledExecutionValue -InputObject $action -Name "mutationKind" -DefaultValue "")
        $requiresNetwork = [bool](Get-KitControlledExecutionValue -InputObject $action -Name "requiresNetwork" -DefaultValue $false)
        $actionMode = [string](Get-KitControlledExecutionValue -InputObject $action -Name "mode" -DefaultValue "")
        $stage = [string](Get-KitControlledExecutionValue -InputObject $action -Name "stage" -DefaultValue "")
        $dependsOn = @((Get-KitControlledExecutionValue -InputObject $action -Name "dependsOn" -DefaultValue @()) | ForEach-Object { [string]$_ })
        $status = "planned"
        $reason = "planned only; entrypoint is not invoked"

        if ([string]::IsNullOrWhiteSpace($entrypoint)) {
            $status = "failed"
            $reason = "entrypoint is required"
        } elseif (-not (Test-Path -LiteralPath (Resolve-KitControlledExecutionRepoPath -RepoRoot $RepoRoot -Path $entrypoint))) {
            $status = "failed"
            $reason = "entrypoint is missing"
        } elseif ($mutationKind -ne "none") {
            $status = "blocked"
            $reason = "mutationKind is blocked in the Issue 17 dry-run baseline"
        } elseif ($requiresNetwork) {
            $status = "blocked"
            $reason = "network access is blocked in the Issue 17 dry-run baseline"
        } elseif ($actionMode -eq "manual") {
            $status = "planned"
            $reason = "manual review signal only; no execution"
        }

        foreach ($dependency in $dependsOn) {
            if (-not $resultById.ContainsKey($dependency)) {
                $status = "failed"
                $reason = "unknown dependency: $dependency"
                break
            }

            $dependencyResult = $resultById[$dependency]
            if ($dependencyResult.status -in @("blocked", "failed")) {
                $status = "blocked"
                $reason = "blocked by dependency: $dependency"
                break
            }
        }

        if ([string](Get-KitControlledExecutionValue -InputObject $action -Name "evidenceProducer" -DefaultValue "") -eq "authorization" -and $authorizationResult.failureCount -gt 0) {
            $status = "blocked"
            $reason = $authorizationResult.reason
        }

        if ($stage -eq "native-command-simulation" -and $nativeCommandSimulationResult.failureCount -gt 0) {
            $status = "failed"
            $reason = $nativeCommandSimulationResult.reason
        }

        $actionResult = New-KitControlledExecutionActionResult -Action $action -Status $status -Reason $reason
        $results += $actionResult
        $resultById[$actionResult.id] = $actionResult
    }

    $blockedCount = @($results | Where-Object { $_.status -eq "blocked" }).Count
    $failedCount = @($results | Where-Object { $_.status -eq "failed" }).Count
    $plannedCount = @($results | Where-Object { $_.status -eq "planned" }).Count
    $mutationCount = @($results | Where-Object { $_.mutationKind -ne "none" }).Count
    $dependencyBlockedCount = @($results | Where-Object { $_.reason -like "blocked by dependency:*" }).Count
    $status = "passed"
    if ($blockedCount -gt 0 -or $failedCount -gt 0) {
        $status = "failed"
    }

    if (
        $diskIdentityPlan.mismatchCount -gt 0 -or
        $confirmationTokenPlan.failureCount -gt 0 -or
        $wimImagePlan.failureCount -gt 0 -or
        $winREPlanResult.failureCount -gt 0 -or
        $nativeCommandPlanResult.failureCount -gt 0 -or
        $authorizationResult.failureCount -gt 0 -or
        $nativeCommandSimulationResult.failureCount -gt 0
    ) {
        $status = "failed"
    }

    [pscustomobject][ordered]@{
        reportType = "controlled-execution"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        executionSetId = [string](Get-KitControlledExecutionValue -InputObject $Manifest -Name "executionSetId" -DefaultValue "")
        mode = $Mode
        whatIf = $true
        trueExecution = $false
        status = $status
        summary = [pscustomobject][ordered]@{
            actionCount = @($results).Count
            plannedActionCount = $plannedCount
            blockedActionCount = $blockedCount
            failedCount = $failedCount
            requiresAdminCount = @($results | Where-Object { $_.requiresAdmin }).Count
            requiresWinPECount = @($results | Where-Object { $_.requiresWinPE }).Count
            requiresRebootCount = @($results | Where-Object { $_.requiresReboot }).Count
            requiresNetworkCount = @($results | Where-Object { $_.requiresNetwork }).Count
            mutationActionCount = $mutationCount
            diskIdentityMismatchCount = [int]$diskIdentityPlan.mismatchCount
            confirmationTokenFailureCount = [int]$confirmationTokenPlan.failureCount
            wimValidationFailureCount = [int]$wimImagePlan.failureCount
            winrePlanFailureCount = [int]$winREPlanResult.failureCount
            nativeCommandFailureCount = [int]$nativeCommandPlanResult.failureCount
            authorizationFailureCount = [int]$authorizationResult.failureCount
            executeRequestBlockedCount = [int]$authorizationResult.executeRequestBlockedCount
            simulatedCommandCount = [int]$nativeCommandSimulationResult.simulatedCommandCount
            simulatedFailureCount = [int]$nativeCommandSimulationResult.simulatedFailureCount
            downstreamBlockedCount = [int]$dependencyBlockedCount
            dependencyBlockedCount = [int]$dependencyBlockedCount
        }
        actions = @($results)
        stageResults = @($results)
        inputs = [pscustomobject][ordered]@{
            diskIdentity = $diskIdentityPlan
            confirmationToken = $confirmationTokenPlan
            wimMetadata = $wimImagePlan
            winrePlan = $winREPlanResult
            nativeCommandPlan = $nativeCommandPlanResult
            authorization = $authorizationResult
        }
        authorization = $authorizationResult
        simulation = [pscustomobject][ordered]@{
            status = $nativeCommandSimulationResult.status
            reason = $nativeCommandSimulationResult.reason
            simulatedCommandCount = [int]$nativeCommandSimulationResult.simulatedCommandCount
            simulatedFailureCount = [int]$nativeCommandSimulationResult.simulatedFailureCount
            downstreamBlockedCount = [int]$dependencyBlockedCount
            command = $nativeCommandSimulationResult.command
        }
        safety = [pscustomobject][ordered]@{
            diskMutation = $false
            registryMutation = $false
            networkDownload = $false
            serviceMutation = $false
            profileMutation = $false
            hiveMutation = $false
        }
    }
}

