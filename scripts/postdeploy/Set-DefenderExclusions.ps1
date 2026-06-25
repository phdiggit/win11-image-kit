[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\defender-exclusions.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json",
    [string]$ReportPath,
    [switch]$ReportRequired
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Assert-KitElevation.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Test-KitDefenderState.ps1"
. "$PSScriptRoot\..\common\Set-KitDefenderExclusionState.ps1"

$script:DefenderEffectiveWhatIf = ([bool]$WhatIfPreference) -or $PSCmdlet.MyInvocation.BoundParameters.ContainsKey("WhatIf") -or ($MyInvocation.Line -match '(^|\s)-WhatIf(\s|$)')
Assert-KitElevation -Operation "Defender 排除项设置" -AllowWhatIfPreview
$script:DefenderEffectiveWhatIf = $script:DefenderEffectiveWhatIf -or ([bool]$WhatIfPreference) -or $PSBoundParameters.ContainsKey("WhatIf") -or (-not (Test-KitIsAdministrator))

function Write-DefenderExclusionReport {
    param(
        [AllowNull()]
        $Results = @(),

        [AllowNull()]
        $StateResults = @()
    )

    $report = New-KitDefenderExclusionReport -Results $Results -StateResults $StateResults -WhatIf:$script:DefenderEffectiveWhatIf
    if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
        $written = Write-KitTextFile -Path $ReportPath -Content ($report | ConvertTo-Json -Depth 12) -Description "Defender 排除项报告" -Required:$ReportRequired
        if ($written) {
            Write-KitLog "Defender 排除项报告已写入：$ReportPath" "OK"
        }
    }

    return $report.defenderSummary
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Write-KitLog "Defender 排除项清单不存在：$ManifestPath" "WARN"
    $summary = Write-DefenderExclusionReport -Results @() -StateResults @()
    return $summary
}

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
$exclusions = @()
if ($manifest.PSObject.Properties.Name -contains "exclusions") {
    $exclusions = @(ConvertTo-KitDefenderExclusionArray -Value $manifest.exclusions)
}

$defenderResults = @(Set-KitDefenderExclusionState `
    -Exclusions $exclusions `
    -PathMap $pathMap `
    -RepoRoot $repoRoot `
    -WhatIf:$script:DefenderEffectiveWhatIf)

$stateResults = @()
if ($manifest.PSObject.Properties.Name -contains "stateChecks") {
    if ($script:DefenderEffectiveWhatIf) {
        $stateResults += Test-KitDefenderState -Config @($manifest.stateChecks) -WhatIf
    } else {
        $stateResults += Test-KitDefenderState -Config @($manifest.stateChecks)
    }
}

$defenderSummary = Write-DefenderExclusionReport -Results $defenderResults -StateResults $stateResults
if ($defenderSummary.exitCode -ne 0) {
    throw "Defender 排除项设置失败：$($defenderSummary.failedRequiredCount) 项 required 检查失败。"
}

Write-KitLog "Defender 排除项设置完成" "OK"
return $defenderSummary
