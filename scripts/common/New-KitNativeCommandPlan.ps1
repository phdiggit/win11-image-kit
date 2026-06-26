#Requires -Version 5.1

function New-KitNativeCommandPlan {
    param(
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return [pscustomobject][ordered]@{
            status = "blocked"
            reason = "native command plan input is missing"
            failureCount = 1
            commands = @()
        }
    }

    $reasons = @()
    $commands = @($InputObject.commands)
    foreach ($command in $commands) {
        if ([string](Get-KitControlledExecutionValue -InputObject $command -Name "actualExitCode" -DefaultValue "") -ne "not-run") {
            $reasons += "actual exit code must remain not-run"
        }
        if ([string](Get-KitControlledExecutionValue -InputObject $command -Name "stdout" -DefaultValue "") -ne "not-captured") {
            $reasons += "stdout must remain not-captured"
        }
        if ([string](Get-KitControlledExecutionValue -InputObject $command -Name "stderr" -DefaultValue "") -ne "not-captured") {
            $reasons += "stderr must remain not-captured"
        }
        if ([string](Get-KitControlledExecutionValue -InputObject $command -Name "status" -DefaultValue "") -ne "planned") {
            $reasons += "command status must remain planned"
        }
    }

    $status = "planned"
    if ($reasons.Count -gt 0) {
        $status = "blocked"
    }

    [pscustomobject][ordered]@{
        status = $status
        reason = if ($reasons.Count -gt 0) { $reasons -join "; " } else { "native command envelope is plan-only" }
        failureCount = $reasons.Count
        commands = $commands
    }
}
