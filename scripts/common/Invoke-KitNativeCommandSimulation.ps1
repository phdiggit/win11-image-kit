#Requires -Version 5.1

function Invoke-KitNativeCommandSimulation {
    [CmdletBinding(DefaultParameterSetName = "InputObject")]
    param(
        [Parameter(ParameterSetName = "InputObject")]
        [AllowNull()]
        $InputObject,

        [Parameter(ParameterSetName = "FixturePath", Mandatory)]
        [string]$FixturePath,

        [Parameter(ParameterSetName = "FixturePath")]
        [string]$RepoRoot
    )

    if ($PSCmdlet.ParameterSetName -eq "FixturePath") {
        if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
            $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
        }

        $resolvedPath = Resolve-KitControlledExecutionRepoPath -RepoRoot $RepoRoot -Path $FixturePath
        $InputObject = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    if ($null -eq $InputObject) {
        return [pscustomobject][ordered]@{
            status = "blocked"
            reason = "native command simulation fixture is missing"
            failureCount = 1
            simulatedCommandCount = 0
            simulatedFailureCount = 0
            command = $null
        }
    }

    $exitCode = [int](Get-KitControlledExecutionValue -InputObject $InputObject -Name "simulatedExitCode" -DefaultValue 1)
    $status = if ($exitCode -eq 0) { "simulated-success" } else { "simulated-failure" }

    [pscustomobject][ordered]@{
        status = $status
        reason = if ($exitCode -eq 0) { "fixture simulation succeeded; no native command executed" } else { "fixture simulation failed; downstream stages must be blocked" }
        failureCount = if ($exitCode -eq 0) { 0 } else { 1 }
        simulatedCommandCount = 1
        simulatedFailureCount = if ($exitCode -eq 0) { 0 } else { 1 }
        command = [pscustomobject][ordered]@{
            id = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "commandId" -DefaultValue "")
            name = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "commandName" -DefaultValue "")
            plannedCommand = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "plannedCommand" -DefaultValue "")
            simulatedExitCode = $exitCode
            simulatedStdout = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "simulatedStdout" -DefaultValue "")
            simulatedStderr = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "simulatedStderr" -DefaultValue "")
            simulated = $true
            executed = $false
        }
    }
}
