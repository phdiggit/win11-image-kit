[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ScopeManifestPath = "manifests/customization-scope.json",
    [string]$PathsManifestPath,
    [switch]$SkipPortableApps,
    [switch]$SkipSystemTweaks,
    [switch]$SkipDevRuntime,
    [switch]$SkipMiddleware,
    [string]$LogPath,
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Assert-KitElevation.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Resolve-KitOutputPath.ps1"
. "$PSScriptRoot\..\common\New-StepResult.ps1"
. "$PSScriptRoot\..\common\Get-KitChildReportSummary.ps1"
. "$PSScriptRoot\..\common\Invoke-KitStep.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:BuildReportItems = @()
$script:BuildStepResults = @()
$script:BuildStartedAt = Get-Date
$script:BuildRunStamp = $script:BuildStartedAt.ToString("yyyyMMdd-HHmmss")
$script:BuildLogPath = $null
$script:BuildStatus = "running"
$script:BuildPackageReportSpecs = @()

function Add-KitBuildReportItem {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Status,

        [string]$ScriptPath,
        [string]$Reason
    )

    $script:BuildReportItems += [pscustomobject]@{
        name = $Name
        status = $Status
        scriptPath = $ScriptPath
        reason = $Reason
    }
}

function Add-KitBuildStepResult {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$LegacyStatus,

        [AllowEmptyString()]
        [string]$ScriptPath,

        [AllowEmptyString()]
        [string]$Reason,

        [datetime]$StartedAt = (Get-Date),
        [datetime]$EndedAt = (Get-Date)
    )

    $status = "unchanged"
    $stepReason = "legacy-step-completed-no-structured-result"
    $skippedReason = ""
    $errors = @()
    $whatIfResult = $false

    switch ($LegacyStatus) {
        "skipped" {
            $status = "skipped"
            $stepReason = if ([string]::IsNullOrWhiteSpace($Reason)) { "disabled" } else { $Reason }
            $skippedReason = $stepReason
        }
        "whatif" {
            $status = "whatif"
            $stepReason = if ([string]::IsNullOrWhiteSpace($Reason)) { "whatif-preview" } else { $Reason }
            $whatIfResult = $true
        }
        "failed" {
            $status = "failed"
            $stepReason = $Reason
            $errors = @($Reason)
        }
        default {
            $status = "unchanged"
            $stepReason = "legacy-step-completed-no-structured-result"
        }
    }

    $script:BuildStepResults += New-KitStepResult `
        -Name $Name `
        -Required $true `
        -Status $status `
        -Reason $stepReason `
        -Evidence ([pscustomobject]@{
            scriptPath = $ScriptPath
            legacyStatus = $LegacyStatus
            legacyReason = $Reason
        }) `
        -Errors $errors `
        -SkippedReason $skippedReason `
        -WhatIfResult $whatIfResult `
        -StartedAt $StartedAt `
        -EndedAt $EndedAt
}

function Get-KitReportingSection {
    param(
        [Parameter(Mandatory)]
        $ScopeConfig,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($ScopeConfig.PSObject.Properties.Name -notcontains "reporting") {
        return $null
    }

    if ($ScopeConfig.reporting.PSObject.Properties.Name -notcontains $Name) {
        return $null
    }

    $section = $ScopeConfig.reporting.$Name
    if ($null -eq $section -or -not $section.enabled) {
        return $null
    }

    return $section
}

function Resolve-KitArtifactSpec {
    param(
        [AllowEmptyString()]
        [string]$ExplicitPath,

        [AllowEmptyString()]
        [string]$AutoDirectory,

        [Parameter(Mandatory)]
        [string]$FileName,

        [hashtable]$PathMap
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return [pscustomobject]@{
            path = Resolve-KitOutputPath -Path $ExplicitPath -PathMap $PathMap -RepoRoot $repoRoot
            required = $true
            source = "explicit"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($AutoDirectory)) {
        $directory = Resolve-KitOutputPath -Path $AutoDirectory -PathMap $PathMap -RepoRoot $repoRoot
        return [pscustomobject]@{
            path = Join-Path -Path $directory -ChildPath $FileName
            required = $false
            source = "profile"
        }
    }

    return [pscustomobject]@{
        path = $null
        required = $false
        source = "none"
    }
}

function New-KitBuildPackageReportSpec {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$StepName,

        [Parameter(Mandatory)]
        [string]$FileName,

        [AllowNull()]
        $BuildReportSpec
    )

    if ($null -eq $BuildReportSpec -or [string]::IsNullOrWhiteSpace([string]$BuildReportSpec.path)) {
        return $null
    }

    $reportDirectory = Split-Path -Path ([string]$BuildReportSpec.path) -Parent
    if ([string]::IsNullOrWhiteSpace($reportDirectory)) {
        return $null
    }

    return [pscustomobject]@{
        name = $Name
        stepName = $StepName
        path = Join-Path -Path $reportDirectory -ChildPath $FileName
        required = [bool]$BuildReportSpec.required
    }
}

function Add-KitBuildPackageReportSpec {
    param(
        [AllowNull()]
        $Spec
    )

    if ($null -eq $Spec) {
        return
    }

    $script:BuildPackageReportSpecs += $Spec
}

function Get-KitBuildPackageReportArguments {
    param(
        [AllowNull()]
        $Spec
    )

    if ($null -eq $Spec -or [string]::IsNullOrWhiteSpace([string]$Spec.path)) {
        return @{}
    }

    return @{
        PackageReportPath = [string]$Spec.path
        PackageReportRequired = [bool]$Spec.required
    }
}

function Add-KitBuildPackageReportArguments {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Arguments,

        [AllowNull()]
        $Spec
    )

    foreach ($entry in (Get-KitBuildPackageReportArguments -Spec $Spec).GetEnumerator()) {
        $Arguments[$entry.Key] = $entry.Value
    }

    return $Arguments
}

function Invoke-KitTrackedStep {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [hashtable]$Arguments = @{},

        [bool]$Enabled = $true,

        [bool]$SupportsWhatIf = $false,

        [bool]$ForwardWhatIf = $false,

        [string]$StepKind = "步骤"
    )

    $stepStartedAt = Get-Date
    if (-not $Enabled) {
        Invoke-KitStep -Name $Name -ScriptPath $ScriptPath -Arguments $Arguments -Enabled $false -SupportsWhatIf $SupportsWhatIf -ForwardWhatIf $ForwardWhatIf -StepKind $StepKind
        Add-KitBuildReportItem -Name $Name -Status "skipped" -ScriptPath $ScriptPath -Reason "disabled"
        Add-KitBuildStepResult -Name $Name -LegacyStatus "skipped" -ScriptPath $ScriptPath -Reason "disabled" -StartedAt $stepStartedAt -EndedAt (Get-Date)
        return
    }

    try {
        Invoke-KitStep -Name $Name -ScriptPath $ScriptPath -Arguments $Arguments -Enabled $true -SupportsWhatIf $SupportsWhatIf -ForwardWhatIf $ForwardWhatIf -StepKind $StepKind
        $status = if ($WhatIfPreference) { "whatif" } else { "completed" }
        $reason = if ($WhatIfPreference) { "whatif-preview" } else { "completed" }
        Add-KitBuildReportItem -Name $Name -Status $status -ScriptPath $ScriptPath -Reason $reason
        Add-KitBuildStepResult -Name $Name -LegacyStatus $status -ScriptPath $ScriptPath -Reason $reason -StartedAt $stepStartedAt -EndedAt (Get-Date)
    } catch {
        $errorMessage = $_.Exception.Message
        Add-KitBuildReportItem -Name $Name -Status "failed" -ScriptPath $ScriptPath -Reason $errorMessage
        Add-KitBuildStepResult -Name $Name -LegacyStatus "failed" -ScriptPath $ScriptPath -Reason $errorMessage -StartedAt $stepStartedAt -EndedAt (Get-Date)
        throw
    }
}

function Write-KitBuildReport {
    param(
        [AllowEmptyString()]
        [string]$Path,

        [bool]$Required
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $finishedAt = Get-Date
    $summary = [pscustomobject]@{
        completed = @($script:BuildReportItems | Where-Object { $_.status -eq "completed" }).Count
        whatIf = @($script:BuildReportItems | Where-Object { $_.status -eq "whatif" }).Count
        skipped = @($script:BuildReportItems | Where-Object { $_.status -eq "skipped" }).Count
        failed = @($script:BuildReportItems | Where-Object { $_.status -eq "failed" }).Count
    }
    $stepSummary = Get-KitStepResultSummary -Results $script:BuildStepResults
    $packageReports = @(
        foreach ($packageReportSpec in $script:BuildPackageReportSpecs) {
            Get-KitPackageReportReference `
                -Name ([string]$packageReportSpec.name) `
                -StepName ([string]$packageReportSpec.stepName) `
                -Path ([string]$packageReportSpec.path) `
                -Required:([bool]$packageReportSpec.required)
        }
    )
    $packageReportSummary = Get-KitPackageReportAggregate -PackageReports $packageReports
    $childReportSummary = Get-KitChildReportBlockingSummary -PackageReports $packageReports

    $report = [pscustomobject]@{
        generatedAt = $finishedAt.ToString("s")
        startedAt = $script:BuildStartedAt.ToString("s")
        finishedAt = $finishedAt.ToString("s")
        profile = $scopeConfig.profile
        status = $script:BuildStatus
        whatIf = [bool]$WhatIfPreference
        logPath = $script:BuildLogPath
        reportType = "golden-image-build-summary"
        summary = $summary
        steps = $script:BuildReportItems
        stepResults = $script:BuildStepResults
        stepSummary = $stepSummary
        childReportSummary = $childReportSummary
        packageReports = $packageReports
    }

    $written = $false
    if ([IO.Path]::GetExtension($Path).ToLowerInvariant() -eq ".md") {
        $lines = @(
            "# 金镜像构建报告",
            "",
            "- 生成时间：$($report.generatedAt)",
            "- 开始时间：$($report.startedAt)",
            "- 结束时间：$($report.finishedAt)",
            "- Profile：$($report.profile)",
            "- 状态：$($report.status)",
            "- WhatIf：$($report.whatIf)",
            "- 日志文件：$($report.logPath)",
            "- 完成：$($summary.completed)",
            "- 预演：$($summary.whatIf)",
            "- 跳过：$($summary.skipped)",
            "- 失败：$($summary.failed)",
            "- StepResult 总数：$($stepSummary.total)",
            "- StepResult 阻断失败：$($stepSummary.failedRequiredCount)",
            "- StepResult changed：$($stepSummary.statusCounts.changed)",
            "- StepResult unchanged：$($stepSummary.statusCounts.unchanged)",
            "- StepResult skipped：$($stepSummary.statusCounts.skipped)",
            "- StepResult manual：$($stepSummary.statusCounts.manual)",
            "- StepResult whatif：$($stepSummary.statusCounts.whatif)",
            "- StepResult failed：$($stepSummary.statusCounts.failed)",
            "- 子报告总数：$($childReportSummary.reports)",
            "- 子报告存在：$($childReportSummary.existing)",
            "- 子报告缺失：$($childReportSummary.missing)",
            "- 子报告 required 失败：$($childReportSummary.failedRequired)",
            "- 子报告 optional 失败：$($childReportSummary.failedOptional)",
            "- 子报告阻断失败：$($childReportSummary.hasBlockingFailure)",
            "- 子报告建议 exitCode：$($childReportSummary.exitCode)",
            "- 软件包子报告：$($packageReportSummary.reports)",
            "- 软件包子报告存在：$($packageReportSummary.existing)",
            "- 软件包失败：$($packageReportSummary.failedRequired + $packageReportSummary.failedOptional)",
            "- 软件包跳过：$($packageReportSummary.skipped)",
            "- 软件包人工处理：$($packageReportSummary.manual)",
            "- 软件包预演：$($packageReportSummary.whatif)",
            "",
            "| 软件包子报告 | 步骤 | 存在 | 路径 | 摘要错误 |",
            "|---|---|---|---|---|"
        )

        foreach ($packageReport in $packageReports) {
            $lines += "| $($packageReport.name) | $($packageReport.stepName) | $($packageReport.exists) | $($packageReport.path) | $($packageReport.error) |"
        }

        $lines += @(
            "",
            "| 步骤 | 状态 | 脚本 | 备注 |",
            "|---|---|---|---|"
        )

        foreach ($step in $script:BuildReportItems) {
            $lines += "| $($step.name) | $($step.status) | $($step.scriptPath) | $($step.reason) |"
        }

        $written = Write-KitTextFile -Path $Path -Content $lines -Description "构建报告" -Required:$Required
    } else {
        $written = Write-KitTextFile -Path $Path -Content ($report | ConvertTo-Json -Depth 12) -Description "构建报告" -Required:$Required
    }

    if ($written) {
        Write-KitLog "构建报告已写入：$Path" "OK"
    }
}

Write-KitLog "开始执行金镜像构建编排"
Assert-KitElevation -Operation "金镜像构建编排" -AllowWhatIfPreview

$ScopeManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $ScopeManifestPath
$scopeConfig = Get-Content -LiteralPath $ScopeManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $PathsManifestPath) {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.pathsManifest
} else {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $PathsManifestPath
}

$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
$reportingConfig = Get-KitReportingSection -ScopeConfig $scopeConfig -Name "build"

$logSpec = Resolve-KitArtifactSpec `
    -ExplicitPath $LogPath `
    -AutoDirectory $(if ($null -ne $reportingConfig) { [string]$reportingConfig.logDirectory } else { $null }) `
    -FileName ("golden-image-build-{0}.log" -f $script:BuildRunStamp) `
    -PathMap $pathMap

$reportSpec = Resolve-KitArtifactSpec `
    -ExplicitPath $ReportPath `
    -AutoDirectory $(if ($null -ne $reportingConfig) { [string]$reportingConfig.reportDirectory } else { $null }) `
    -FileName ("golden-image-build-{0}.md" -f $script:BuildRunStamp) `
    -PathMap $pathMap

if (-not [string]::IsNullOrWhiteSpace($logSpec.path)) {
    Set-KitLogPath -Path $logSpec.path -Required:$logSpec.required
    $script:BuildLogPath = Get-KitLogPath
    if (-not [string]::IsNullOrWhiteSpace($script:BuildLogPath)) {
        Write-KitLog "已启用构建日志文件：$script:BuildLogPath" "OK"
    }
}

Write-KitLog ("当前构建 profile：{0}" -f $scopeConfig.profile)
Write-KitLog ("工具根目录：{0}" -f $pathMap["ToolRoot"])
Write-KitLog ("安装包根目录：{0}" -f $pathMap["PackageRoot"])

$portablePackageReportSpec = New-KitBuildPackageReportSpec `
    -Name "归档包" `
    -StepName "golden-image 通用归档软件包" `
    -FileName ("software-portable-packages-{0}.json" -f $script:BuildRunStamp) `
    -BuildReportSpec $reportSpec

$devRuntimePackageReportSpec = New-KitBuildPackageReportSpec `
    -Name "开发运行时" `
    -StepName "golden-image 开发运行时" `
    -FileName ("software-dev-runtime-packages-{0}.json" -f $script:BuildRunStamp) `
    -BuildReportSpec $reportSpec

$middlewarePackageReportSpec = New-KitBuildPackageReportSpec `
    -Name "中间件准备" `
    -StepName "golden-image 中间件准备" `
    -FileName ("software-middleware-packages-{0}.json" -f $script:BuildRunStamp) `
    -BuildReportSpec $reportSpec

try {
    if (-not $SkipPortableApps) {
        Add-KitBuildPackageReportSpec -Spec $portablePackageReportSpec
    }
    $portableArguments = @{
        ManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.applications.softwareManifest
        PathsManifestPath = $PathsManifestPath
        Stage = "golden-image"
    }
    $portableArguments = Add-KitBuildPackageReportArguments -Arguments $portableArguments -Spec $portablePackageReportSpec

    Invoke-KitTrackedStep `
        -Name "golden-image 通用归档软件包" `
        -ScriptPath "$PSScriptRoot\Install-PortableApps.ps1" `
        -Enabled (-not $SkipPortableApps) `
        -SupportsWhatIf $true `
        -ForwardWhatIf $WhatIfPreference `
        -StepKind "构建步骤" `
        -Arguments $portableArguments

    if (-not $SkipDevRuntime) {
        Add-KitBuildPackageReportSpec -Spec $devRuntimePackageReportSpec
    }
    $devRuntimeArguments = @{
        ManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.applications.softwareManifest
        PathsManifestPath = $PathsManifestPath
        Stage = "golden-image"
    }
    $devRuntimeArguments = Add-KitBuildPackageReportArguments -Arguments $devRuntimeArguments -Spec $devRuntimePackageReportSpec

    Invoke-KitTrackedStep `
        -Name "golden-image 开发运行时" `
        -ScriptPath "$PSScriptRoot\Install-DevRuntime.ps1" `
        -Enabled (-not $SkipDevRuntime) `
        -SupportsWhatIf $true `
        -ForwardWhatIf $WhatIfPreference `
        -StepKind "构建步骤" `
        -Arguments $devRuntimeArguments

    if (-not $SkipMiddleware) {
        Add-KitBuildPackageReportSpec -Spec $middlewarePackageReportSpec
    }
    $middlewareArguments = @{
        ManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.applications.softwareManifest
        PathsManifestPath = $PathsManifestPath
        Stage = "golden-image"
    }
    $middlewareArguments = Add-KitBuildPackageReportArguments -Arguments $middlewareArguments -Spec $middlewarePackageReportSpec

    Invoke-KitTrackedStep `
        -Name "golden-image 中间件准备" `
        -ScriptPath "$PSScriptRoot\Install-Middleware.ps1" `
        -Enabled (-not $SkipMiddleware) `
        -SupportsWhatIf $true `
        -ForwardWhatIf $WhatIfPreference `
        -StepKind "构建步骤" `
        -Arguments $middlewareArguments

    $systemTweaksEnabled = (
        $scopeConfig.system.contextMenu.enabled -or
        $scopeConfig.system.explorerOptions.enabled
    )
    Invoke-KitTrackedStep `
        -Name "系统级配置" `
        -ScriptPath "$PSScriptRoot\Set-SystemTweaks.ps1" `
        -Enabled ($systemTweaksEnabled -and -not $SkipSystemTweaks) `
        -SupportsWhatIf $true `
        -ForwardWhatIf $WhatIfPreference `
        -StepKind "构建步骤" `
        -Arguments @{
            PathsManifestPath = $PathsManifestPath
        }

    $script:BuildStatus = "completed"
    Write-KitLog "金镜像构建编排完成" "OK"
} catch {
    $script:BuildStatus = "failed"
    throw
} finally {
    Write-KitBuildReport -Path $reportSpec.path -Required:$reportSpec.required
    Clear-KitLogPath
}
