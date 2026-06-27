#Requires -Version 5.1

function New-KitUserExperienceManualChecklist {
    param(
        [AllowNull()]
        $Handlers = @()
    )

    $items = @()
    foreach ($handler in @($Handlers)) {
        if ([string]$handler.status -notin @("manual", "planned")) {
            continue
        }

        if ([string]$handler.verificationMode -notin @("manual-checklist", "future-real-verification")) {
            continue
        }

        $items += [pscustomobject][ordered]@{
            id = "verify-$($handler.handlerId)"
            scope = [string]$handler.scope
            feature = [string]$handler.handlerType
            reason = $(if ([string]$handler.verificationMode -eq "manual-checklist") { "manual checklist required" } else { "future real verification required" })
            commandExitCodeSufficient = $false
            userConfigurationConfirmed = $false
            status = "manual"
        }
    }

    return @($items)
}
