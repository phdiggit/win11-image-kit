[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ScopeManifestPath = "manifests/customization-scope.json",
    [string]$PathsManifestPath,
    [string]$ConfigRoot,
    [string]$DefaultAppsTemplate,
    [string]$StartMenuTemplate,
    [ValidateSet("default-user", "current-user", "offline-image", "machine")]
    [string]$Scope = "default-user",
    [ValidateSet("plan-only", "report-only", "fixture")]
    [string]$Mode = "plan-only",
    [switch]$Strict,
    [switch]$Apply,
    [switch]$Execute,
    [string]$ReportPath,
    [switch]$ReportRequired
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Invoke-KitStep.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Test-KitConfigState.ps1"
. "$PSScriptRoot\..\common\New-KitUserExperienceHandlerReport.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:UserExperienceReportItems = @()
$script:UserExperienceStateResults = @()

function Read-KitUxJsonFile {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Add-KitUserExperienceReportItem {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$Reason,
        [string]$Source,
        [string]$Destination,
        [string]$Advice,
        [string[]]$Details = @()
    )

    $script:UserExperienceReportItems += [pscustomobject][ordered]@{
        name = $Name
        status = $Status
        reason = $Reason
        source = $Source
        destination = $Destination
        advice = $Advice
        details = @($Details | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
}

function Get-KitUserExperienceStateChecks {
    param([AllowNull()]$ScopeConfig)

    if ($null -eq $ScopeConfig -or $null -eq $ScopeConfig.system) {
        return @()
    }

    $checks = @()
    foreach ($sectionName in @("explorerOptions", "startMenu", "windowsTerminal", "defaultApps", "vscodePortable")) {
        if ($ScopeConfig.system.PSObject.Properties.Name -notcontains $sectionName) {
            continue
        }

        $section = $ScopeConfig.system.$sectionName
        if ($null -ne $section -and $section.PSObject.Properties.Name -contains "stateChecks") {
            $checks += @($section.stateChecks)
        }
    }

    return @($checks)
}

function Get-KitUserExperienceReportItemState {
    param([Parameter(Mandatory)][string]$SettingName)

    $item = @($script:UserExperienceReportItems | Where-Object { $_.name -eq $SettingName } | Select-Object -First 1)
    if ($item.Count -eq 0) {
        return [pscustomobject]@{ found = $false; value = $null }
    }

    return [pscustomobject]@{ found = $true; value = [string]$item[0].status }
}

function Invoke-KitUserExperienceStateChecks {
    if ($null -eq $script:scopeConfig) {
        $script:UserExperienceStateResults = @()
        return
    }

    $stateChecks = @(Get-KitUserExperienceStateChecks -ScopeConfig $script:scopeConfig)
    if ($stateChecks.Count -eq 0) {
        $script:UserExperienceStateResults = @()
        return
    }

    $query = {
        param($Check, [string]$Domain, [string]$SettingName)
        Get-KitUserExperienceReportItemState -SettingName $SettingName
    }

    $script:UserExperienceStateResults = @(Test-KitConfigState -Config $stateChecks -ConfigQuery $query -WhatIf:$WhatIfPreference)
}

function Write-KitUserExperienceReport {
    param(
        [AllowNull()]$Report,
        [string]$Path,
        [switch]$Required
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $resolvedPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $Path
    $directory = Split-Path -Path $resolvedPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $content = if ([IO.Path]::GetExtension($resolvedPath).ToLowerInvariant() -eq ".md") {
        @(
            "# User Experience Restore Report",
            "",
            "- Mode: $($Report.mode)",
            "- Status: $($Report.status)",
            "- True execution: $($Report.trueExecution)",
            "- Handler executions: $($Report.summary.handlerExecutionCount)",
            "- Blocked handlers: $($Report.summary.blockedHandlerCount)",
            "- Manual checklist: $($Report.summary.manualChecklistCount)"
        ) -join "`n"
    } else {
        $Report | ConvertTo-Json -Depth 16
    }

    $content | Set-Content -LiteralPath $resolvedPath -Encoding UTF8 -WhatIf:$false
    Write-KitLog "User experience restore report written: $resolvedPath" "OK"
}

function ConvertTo-KitUxTemplateSources {
    param([AllowNull()]$Metadata)

    if ($null -eq $Metadata) {
        return @()
    }

    return @([pscustomobject][ordered]@{
        templateId = [string](Get-KitUserExperienceValue -InputObject $Metadata -Name "templateId" -DefaultValue "")
        templateType = [string](Get-KitUserExperienceValue -InputObject $Metadata -Name "templateType" -DefaultValue "")
        targetScope = [string](Get-KitUserExperienceValue -InputObject $Metadata -Name "targetScope" -DefaultValue "")
        sourceWindows = (Get-KitUserExperienceValue -InputObject $Metadata -Name "sourceWindows" -DefaultValue $null)
        targetApps = @($Metadata.targetApps)
        executed = $false
    })
}

Write-KitLog "Start user experience restore plan"

$ScopeManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $ScopeManifestPath
$script:scopeConfig = Read-KitUxJsonFile -Path $ScopeManifestPath
if ($null -eq $script:scopeConfig) {
    throw "Unable to read user experience scope manifest: $ScopeManifestPath"
}

if (-not $PathsManifestPath) {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $script:scopeConfig.pathsManifest
} else {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $PathsManifestPath
}

$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
if ([string]::IsNullOrWhiteSpace($ConfigRoot)) {
    $ConfigRoot = Join-Path -Path $repoRoot -ChildPath "configs"
}

$defaultMetadataPath = if ([string]::IsNullOrWhiteSpace($DefaultAppsTemplate)) {
    Join-Path -Path $ConfigRoot -ChildPath "default-apps\default-apps.metadata.json"
} else {
    Resolve-KitRepoPath -RepoRoot $repoRoot -Path $DefaultAppsTemplate
}

$startMetadataPath = if ([string]::IsNullOrWhiteSpace($StartMenuTemplate)) {
    Join-Path -Path $ConfigRoot -ChildPath "start-menu\start-menu.metadata.json"
} else {
    Resolve-KitRepoPath -RepoRoot $repoRoot -Path $StartMenuTemplate
}

$defaultMetadata = Read-KitUxJsonFile -Path $defaultMetadataPath
$startMetadata = Read-KitUxJsonFile -Path $startMetadataPath

$requestedApply = [bool]($Apply -or $Execute)
$defaultApps = $null
if ($script:scopeConfig.system.defaultApps.enabled) {
    $defaultTemplateMetadataId = [string](Get-KitUserExperienceValue -InputObject $defaultMetadata -Name "templateId" -DefaultValue "default-apps-metadata-missing")
    $defaultKnownCapability = $null -ne $defaultMetadata
    $defaultAssociations = @()
    foreach ($targetApp in @($defaultMetadata.targetApps)) {
        $defaultAssociations += [pscustomobject][ordered]@{
            progId = [string](Get-KitUserExperienceValue -InputObject $targetApp -Name "progId" -DefaultValue "")
            appIdentity = [string](Get-KitUserExperienceValue -InputObject $targetApp -Name "logicalName" -DefaultValue "")
            knownCapability = [bool](Get-KitUserExperienceValue -InputObject $targetApp -Name "knownCapability" -DefaultValue $defaultKnownCapability)
        }
    }

    $defaultApps = [pscustomobject][ordered]@{
        handlerId = "default-apps-default-user"
        handlerType = "default-apps"
        scope = "default-user"
        mode = $Mode
        source = "config-metadata"
        templateMetadataId = $defaultTemplateMetadataId
        supportStatus = "planned-supported"
        verificationMode = "future-real-verification"
        requestedApply = $requestedApply
        mutationRequested = $false
        associations = $defaultAssociations
    }
    Add-KitUserExperienceReportItem -Name "Default app associations" -Status "planned" -Reason "report-only-handler" -Source $defaultMetadataPath -Advice "Plan-only output is not real UX evidence."
} else {
    Add-KitUserExperienceReportItem -Name "Default app associations" -Status "skipped" -Reason "disabled"
}

$startMenu = $null
if ($script:scopeConfig.system.startMenu.enabled) {
    $startTemplateMetadataId = [string](Get-KitUserExperienceValue -InputObject $startMetadata -Name "templateId" -DefaultValue "start-menu-metadata-missing")
    $startPins = @($startMetadata.targetApps)
    $startMenu = [pscustomobject][ordered]@{
        handlerId = "start-menu-default-user"
        handlerType = "start-menu"
        scope = "default-user"
        mode = $Mode
        source = "config-metadata"
        templateMetadataId = $startTemplateMetadataId
        supportStatus = "planned-supported"
        verificationMode = "future-real-verification"
        requestedApply = $requestedApply
        mutationRequested = $false
        profileWriteRequested = $false
        pins = $startPins
    }
    Add-KitUserExperienceReportItem -Name "Start menu default layout" -Status "planned" -Reason "report-only-handler" -Source $startMetadataPath -Advice "Default User plan is not current-user success evidence."
} else {
    Add-KitUserExperienceReportItem -Name "Start menu default layout" -Status "skipped" -Reason "disabled"
}

$taskbar = [pscustomobject][ordered]@{
    handlerId = "taskbar-current-user"
    handlerType = "taskbar"
    scope = "current-user"
    mode = $Mode
    source = "manual-checklist"
    templateMetadataId = ""
    supportStatus = "manual-or-future"
    verificationMode = "manual-checklist"
    requestedApply = $requestedApply
    mutationRequested = $false
    registryWriteRequested = $false
    pins = @()
}

Add-KitUserExperienceReportItem -Name "Taskbar layout" -Status "manual" -Reason "manual-checklist" -Advice "Manual checklist only; no taskbar mutation."
Add-KitUserExperienceReportItem -Name "Explorer options" -Status "planned" -Reason "report-only-handler" -Advice "No user registry mutation in this stage."
Add-KitUserExperienceReportItem -Name "Windows Terminal template" -Status "planned" -Reason "report-only-handler"
Add-KitUserExperienceReportItem -Name "VSCode portable data directory" -Status "planned" -Reason "report-only-handler"

Invoke-KitUserExperienceStateChecks

$templateSources = @()
$templateSources += ConvertTo-KitUxTemplateSources -Metadata $defaultMetadata
$templateSources += ConvertTo-KitUxTemplateSources -Metadata $startMetadata

$scopeMapping = [pscustomobject][ordered]@{
    defaultUserIsCurrentUser = $false
    offlineImageIsCurrentMachine = $false
    scopes = @("default-user", "current-user", "offline-image", "machine")
}

$report = New-KitUserExperienceHandlerReport `
    -Mode $Mode `
    -Scope $Scope `
    -RequestedApply:$requestedApply `
    -DefaultApps $defaultApps `
    -StartMenu $startMenu `
    -Taskbar $taskbar `
    -TemplateSources $templateSources `
    -ScopeMapping $scopeMapping `
    -LegacyItems $script:UserExperienceReportItems `
    -UserExperienceResults $script:UserExperienceStateResults

$report | Add-Member -NotePropertyName strict -NotePropertyValue ([bool]$Strict)
$report | Add-Member -NotePropertyName scopeManifestPath -NotePropertyValue $ScopeManifestPath
$report | Add-Member -NotePropertyName userExperienceSummary -NotePropertyValue (Get-KitConfigStateResultSummary -Results $script:UserExperienceStateResults)

Write-KitUserExperienceReport -Report $report -Path $ReportPath -Required:$ReportRequired
Write-KitLog "User experience restore plan generated" "OK"

$report

if ($requestedApply -or ($Strict -and $report.status -ne "planned")) {
    exit 1
}
