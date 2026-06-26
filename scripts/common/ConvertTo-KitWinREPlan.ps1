#Requires -Version 5.1

function ConvertTo-KitWinREPlan {
    param(
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return [pscustomobject][ordered]@{
            status = "blocked"
            reason = "recovery plan input is missing"
            failureCount = 1
            plannedCommands = @()
        }
    }

    $expectedType = "de94bba4-06d1-4d40-a16a-bfd50179d6ac"
    $expectedAttributes = "0x8000000000000001"
    $reasons = @()
    $windowsVolume = Get-KitControlledExecutionValue -InputObject $InputObject -Name "windowsVolume"
    $efiVolume = Get-KitControlledExecutionValue -InputObject $InputObject -Name "efiVolume"
    $recoveryVolume = Get-KitControlledExecutionValue -InputObject $InputObject -Name "recoveryVolume"

    foreach ($pair in @(
        @{ Name = "Windows"; Value = $windowsVolume },
        @{ Name = "EFI"; Value = $efiVolume },
        @{ Name = "Recovery"; Value = $recoveryVolume }
    )) {
        if ([string]::IsNullOrWhiteSpace([string](Get-KitControlledExecutionValue -InputObject $pair.Value -Name "letter" -DefaultValue ""))) {
            $reasons += "$($pair.Name) logical volume is missing"
        }
    }

    if ([string](Get-KitControlledExecutionValue -InputObject $recoveryVolume -Name "gptType" -DefaultValue "") -ne $expectedType) {
        $reasons += "recovery partition type mismatch"
    }

    if ([string](Get-KitControlledExecutionValue -InputObject $recoveryVolume -Name "gptAttributes" -DefaultValue "") -ne $expectedAttributes) {
        $reasons += "recovery partition attributes mismatch"
    }

    $status = "planned"
    if ($reasons.Count -gt 0) {
        $status = "blocked"
    }

    [pscustomobject][ordered]@{
        status = $status
        reason = if ($reasons.Count -gt 0) { $reasons -join "; " } else { "recovery plan contains required logical volumes" }
        failureCount = $reasons.Count
        windowsVolume = $windowsVolume
        efiVolume = $efiVolume
        recoveryVolume = $recoveryVolume
        winreWim = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "winreWim" -DefaultValue "")
        plannedCommands = @($InputObject.plannedCommands)
    }
}
