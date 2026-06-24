[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ScopeManifestPath = "manifests/customization-scope.json",
    [string]$PathsManifestPath,
    [string]$LogPath,
    [string]$SummaryReportPath,
    [string]$ReportPath,
    [string]$UserExperienceReportPath,
    [switch]$StrictUserExperience
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
$script:PostDeployReportItems = @()
$script:PostDeployStepResults = @()
$script:PostDeployStartedAt = Get-Date
$script:PostDeployRunStamp = $script:PostDeployStartedAt.ToString("yyyyMMdd-HHmmss")
$script:PostDeployLogPath = $null
$script:PostDeployStatus = "running"
$script:InstallerReportOutputPath = $null
$script:UserExperienceReportOutputPath = $null

function Add-KitPostDeployReportItem {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Status,

        [string]$ScriptPath,
        [string]$Reason
    )

    $script:PostDeployReportItems += [pscustomobject]@{
        name = $Name
        status = $Status
        scriptPath = $ScriptPath
        reason = $Reason
    }
}

function Add-KitPostDeployStepResult {
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

    $script:PostDeployStepResults += New-KitStepResult `
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
        Add-KitPostDeployReportItem -Name $Name -Status "skipped" -ScriptPath $ScriptPath -Reason "disabled"
        Add-KitPostDeployStepResult -Name $Name -LegacyStatus "skipped" -ScriptPath $ScriptPath -Reason "disabled" -StartedAt $stepStartedAt -EndedAt (Get-Date)
        return
    }

    try {
        Invoke-KitStep -Name $Name -ScriptPath $ScriptPath -Arguments $Arguments -Enabled $true -SupportsWhatIf $SupportsWhatIf -ForwardWhatIf $ForwardWhatIf -StepKind $StepKind
        $status = if ($WhatIfPreference) { "whatif" } else { "completed" }
        $reason = if ($WhatIfPreference) { "whatif-preview" } else { "completed" }
        Add-KitPostDeployReportItem -Name $Name -Status $status -ScriptPath $ScriptPath -Reason $reason
        Add-KitPostDeployStepResult -Name $Name -LegacyStatus $status -ScriptPath $ScriptPath -Reason $reason -StartedAt $stepStartedAt -EndedAt (Get-Date)
    } catch {
        $errorMessage = $_.Exception.Message
        Add-KitPostDeployReportItem -Name $Name -Status "failed" -ScriptPath $ScriptPath -Reason $errorMessage
        Add-KitPostDeployStepResult -Name $Name -LegacyStatus "failed" -ScriptPath $ScriptPath -Reason $errorMessage -StartedAt $stepStartedAt -EndedAt (Get-Date)
        throw
    }
}

function Write-KitPostDeployReport {
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
        completed = @($script:PostDeployReportItems | Where-Object { $_.status -eq "completed" }).Count
        whatIf = @($script:PostDeployReportItems | Where-Object { $_.status -eq "whatif" }).Count
        skipped = @($script:PostDeployReportItems | Where-Object { $_.status -eq "skipped" }).Count
        failed = @($script:PostDeployReportItems | Where-Object { $_.status -eq "failed" }).Count
    }
    $stepSummary = Get-KitStepResultSummary -Results $script:PostDeployStepResults
    $installerPackageReport = Get-KitPackageReportReference `
        -Name "部署后软件" `
        -StepName "部署后软件" `
        -Path $script:InstallerReportOutputPath `
        -Required:$installerReportSpec.required `
        -ReportType "post-deploy-installer-plan"
    $packageReports = @()
    if ($null -ne $installerPackageReport) {
        $packageReports += $installerPackageReport
    }
    $packageReportSummary = Get-KitPackageReportAggregate -PackageReports $packageReports

    $report = [pscustomobject]@{
        generatedAt = $finishedAt.ToString("s")
        startedAt = $script:PostDeployStartedAt.ToString("s")
        finishedAt = $finishedAt.ToString("s")
        profile = $scopeConfig.profile
        status = $script:PostDeployStatus
        whatIf = [bool]$WhatIfPreference
        strictUserExperience = [bool]$StrictUserExperience
        logPath = $script:PostDeployLogPath
        installerReportPath = $script:InstallerReportOutputPath
        userExperienceReportPath = $script:UserExperienceReportOutputPath
        reportType = "post-deploy-summary"
        summary = $summary
        steps = $script:PostDeployReportItems
        stepResults = $script:PostDeployStepResults
        stepSummary = $stepSummary
        packageReports = $packageReports
    }

    $written = $false
    if ([IO.Path]::GetExtension($Path).ToLowerInvariant() -eq ".md") {
        $lines = @(
            "# 部署后恢复报告",
            "",
            "- 生成时间：$($report.generatedAt)",
            "- 开始时间：$($report.startedAt)",
            "- 结束时间：$($report.finishedAt)",
            "- Profile：$($report.profile)",
            "- 状态：$($report.status)",
            "- WhatIf：$($report.whatIf)",
            "- 严格用户体验恢复：$($report.strictUserExperience)",
            "- 日志文件：$($report.logPath)",
            "- 安装器报告：$($report.installerReportPath)",
            "- 用户体验报告：$($report.userExperienceReportPath)",
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

        foreach ($step in $script:PostDeployReportItems) {
            $lines += "| $($step.name) | $($step.status) | $($step.scriptPath) | $($step.reason) |"
        }

        $written = Write-KitTextFile -Path $Path -Content $lines -Description "部署后恢复报告" -Required:$Required
    } else {
        $written = Write-KitTextFile -Path $Path -Content ($report | ConvertTo-Json -Depth 12) -Description "部署后恢复报告" -Required:$Required
    }

    if ($written) {
        Write-KitLog "部署后恢复报告已写入：$Path" "OK"
    }
}

Write-KitLog "开始执行部署后恢复"
Assert-KitElevation -Operation "部署后恢复编排" -AllowWhatIfPreview

$ScopeManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $ScopeManifestPath
$scopeConfig = Get-Content -LiteralPath $ScopeManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $PathsManifestPath) {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.pathsManifest
} else {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $PathsManifestPath
}

$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
$reportingConfig = Get-KitReportingSection -ScopeConfig $scopeConfig -Name "postDeploy"

$logSpec = Resolve-KitArtifactSpec `
    -ExplicitPath $LogPath `
    -AutoDirectory $(if ($null -ne $reportingConfig) { [string]$reportingConfig.logDirectory } else { $null }) `
    -FileName ("postdeploy-{0}.log" -f $script:PostDeployRunStamp) `
    -PathMap $pathMap

$summaryReportSpec = Resolve-KitArtifactSpec `
    -ExplicitPath $SummaryReportPath `
    -AutoDirectory $(if ($null -ne $reportingConfig) { [string]$reportingConfig.reportDirectory } else { $null }) `
    -FileName ("postdeploy-summary-{0}.md" -f $script:PostDeployRunStamp) `
    -PathMap $pathMap

$installerReportSpec = Resolve-KitArtifactSpec `
    -ExplicitPath $ReportPath `
    -AutoDirectory $(if ($null -ne $reportingConfig) { [string]$reportingConfig.reportDirectory } else { $null }) `
    -FileName ("postdeploy-installer-{0}.json" -f $script:PostDeployRunStamp) `
    -PathMap $pathMap

$userExperienceReportSpec = Resolve-KitArtifactSpec `
    -ExplicitPath $UserExperienceReportPath `
    -AutoDirectory $(if ($null -ne $reportingConfig) { [string]$reportingConfig.reportDirectory } else { $null }) `
    -FileName ("postdeploy-user-experience-{0}.json" -f $script:PostDeployRunStamp) `
    -PathMap $pathMap

$script:InstallerReportOutputPath = $installerReportSpec.path
$script:UserExperienceReportOutputPath = $userExperienceReportSpec.path

if (-not [string]::IsNullOrWhiteSpace($logSpec.path)) {
    Set-KitLogPath -Path $logSpec.path -Required:$logSpec.required
    $script:PostDeployLogPath = Get-KitLogPath
    if (-not [string]::IsNullOrWhiteSpace($script:PostDeployLogPath)) {
        Write-KitLog "已启用部署后恢复日志文件：$script:PostDeployLogPath" "OK"
    }
}

Write-KitLog ("当前部署 profile：{0}" -f $scopeConfig.profile)
Write-KitLog ("工具根目录：{0}" -f $pathMap["ToolRoot"])
Write-KitLog ("数据根目录：{0}" -f $pathMap["DataRoot"])

try {
    $defenderMode = [string]$scopeConfig.system.windowsDefender.mode
    $defenderEnabled = $defenderMode -eq "enabled-with-exclusions"
    Invoke-KitTrackedStep `
        -Name "Windows Defender 排除项" `
        -ScriptPath "$PSScriptRoot\Set-DefenderExclusions.ps1" `
        -Enabled $defenderEnabled `
        -SupportsWhatIf $true `
        -ForwardWhatIf $WhatIfPreference `
        -StepKind "部署步骤" `
        -Arguments @{
            ManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.system.windowsDefender.exclusionsManifest
            PathsManifestPath = $PathsManifestPath
        }

    Invoke-KitTrackedStep `
        -Name "数据目录 Junction" `
        -ScriptPath "$PSScriptRoot\Set-DataJunctions.ps1" `
        -SupportsWhatIf $true `
        -ForwardWhatIf $WhatIfPreference `
        -StepKind "部署步骤" `
        -Arguments @{
            ManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.applications.junctionsManifest
            PathsManifestPath = $PathsManifestPath
        }

    Invoke-KitTrackedStep `
        -Name "部署后软件" `
        -ScriptPath "$PSScriptRoot\Install-PostDeploySoftware.ps1" `
        -SupportsWhatIf $true `
        -ForwardWhatIf $WhatIfPreference `
        -StepKind "部署步骤" `
        -Arguments @{
            ManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.applications.softwareManifest
            PathsManifestPath = $PathsManifestPath
            ReportPath = $script:InstallerReportOutputPath
            ReportRequired = $installerReportSpec.required
        }

    Invoke-KitTrackedStep `
        -Name "中间件服务注册" `
        -ScriptPath "$PSScriptRoot\Register-MiddlewareServices.ps1" `
        -SupportsWhatIf $true `
        -ForwardWhatIf $WhatIfPreference `
        -StepKind "部署步骤" `
        -Arguments @{
            ManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.applications.servicesManifest
            PathsManifestPath = $PathsManifestPath
        }

    $restoreUserExperience = (
        $scopeConfig.system.startMenu.enabled -or
        (($scopeConfig.system.PSObject.Properties.Name -contains "windowsTerminal") -and $scopeConfig.system.windowsTerminal.enabled) -or
        $scopeConfig.system.defaultApps.enabled -or
        $scopeConfig.system.explorerOptions.enabled -or
        (($scopeConfig.system.PSObject.Properties.Name -contains "vscodePortable") -and $scopeConfig.system.vscodePortable.enabled)
    )
    Invoke-KitTrackedStep `
        -Name "用户体验恢复" `
        -ScriptPath "$PSScriptRoot\Restore-UserExperience.ps1" `
        -Enabled $restoreUserExperience `
        -SupportsWhatIf $true `
        -ForwardWhatIf $WhatIfPreference `
        -StepKind "部署步骤" `
        -Arguments @{
            ScopeManifestPath = $ScopeManifestPath
            PathsManifestPath = $PathsManifestPath
            ReportPath = $script:UserExperienceReportOutputPath
            ReportRequired = $userExperienceReportSpec.required
            Strict = $StrictUserExperience
        }

    $script:PostDeployStatus = "completed"
    Write-KitLog "部署后恢复完成" "OK"
} catch {
    $script:PostDeployStatus = "failed"
    throw
} finally {
    Write-KitPostDeployReport -Path $summaryReportSpec.path -Required:$summaryReportSpec.required
    Clear-KitLogPath
}
