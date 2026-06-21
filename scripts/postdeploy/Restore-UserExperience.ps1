#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ScopeManifestPath = "$PSScriptRoot\..\..\manifests\customization-scope.json",
    [string]$PathsManifestPath,
    [switch]$Strict,
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Invoke-KitStep.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:UserExperienceReportItems = @()

function Add-KitUserExperienceReportItem {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Reason,

        [string]$Source,
        [string]$Destination,
        [string]$Advice,
        [string[]]$Details = @()
    )

    $script:UserExperienceReportItems += [pscustomobject]@{
        name = $Name
        status = $Status
        reason = $Reason
        source = $Source
        destination = $Destination
        advice = $Advice
        details = @($Details | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
}

function Write-KitUserExperienceReport {
    param(
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $resolvedPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $Path
    $directory = Split-Path -Path $resolvedPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force -WhatIf:$false | Out-Null
    }

    $summary = [pscustomobject]@{
        succeeded = @($script:UserExperienceReportItems | Where-Object { $_.status -eq "succeeded" }).Count
        skipped = @($script:UserExperienceReportItems | Where-Object { $_.status -eq "skipped" }).Count
        missing = @($script:UserExperienceReportItems | Where-Object { $_.status -eq "missing" }).Count
        whatIf = @($script:UserExperienceReportItems | Where-Object { $_.status -eq "whatif" }).Count
    }

    $report = [pscustomobject]@{
        generatedAt = (Get-Date).ToString("s")
        reportType = "post-deploy-user-experience"
        strict = [bool]$Strict
        scopeManifestPath = $ScopeManifestPath
        summary = $summary
        items = $script:UserExperienceReportItems
    }

    if ([IO.Path]::GetExtension($resolvedPath).ToLowerInvariant() -eq ".md") {
        $lines = @(
            "# 用户体验恢复报告",
            "",
            "- 生成时间：$($report.generatedAt)",
            "- 严格模式：$($report.strict)",
            "- 成功：$($summary.succeeded)",
            "- 预演：$($summary.whatIf)",
            "- 跳过：$($summary.skipped)",
            "- 缺失：$($summary.missing)",
            "",
            "| 项目 | 状态 | 原因 | 来源 | 目标 | 建议 |",
            "|---|---|---|---|---|---|"
        )

        foreach ($item in $script:UserExperienceReportItems) {
            $name = ([string]$item.name).Replace("|", "\|")
            $status = ([string]$item.status).Replace("|", "\|")
            $reason = ([string]$item.reason).Replace("|", "\|")
            $source = ([string]$item.source).Replace("|", "\|")
            $destination = ([string]$item.destination).Replace("|", "\|")
            $advice = ([string]$item.advice).Replace("|", "\|")
            $lines += "| $name | $status | $reason | $source | $destination | $advice |"
        }

        Set-Content -LiteralPath $resolvedPath -Value $lines -Encoding UTF8 -WhatIf:$false
    } else {
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedPath -Encoding UTF8 -WhatIf:$false
    }

    Write-KitLog "用户体验恢复报告已写入：$resolvedPath" "OK"
}

function Test-KitDirectoryHasContent {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    return @(
        Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    ).Count -gt 0
}

function Ensure-KitDirectory {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Description
    )

    if (Test-Path -LiteralPath $Path) {
        Write-KitLog "$Description 已存在：$Path" "OK"
        return "existing"
    }

    if ($PSCmdlet.ShouldProcess($Path, "创建 $Description")) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-KitLog "$Description 已创建：$Path" "OK"
        return "created"
    }

    Write-KitLog "预演创建 $Description：$Path"
    return "whatif"
}

function Register-KitMissingTemplate {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Reason,

        [Parameter(Mandatory)]
        [string]$Source,

        [string]$Destination,
        [string]$Advice,
        [string[]]$Details = @()
    )

    $message = "$Name 缺少配置模板，跳过自动恢复：$Source"
    if (-not [string]::IsNullOrWhiteSpace($Advice)) {
        $message = "$message。$Advice"
    }

    Write-KitLog $message "WARN"
    Add-KitUserExperienceReportItem `
        -Name $Name `
        -Status "missing" `
        -Reason $Reason `
        -Source $Source `
        -Destination $Destination `
        -Advice $Advice `
        -Details $Details

    if ($Strict) {
        throw "$Name 缺少配置模板，严格模式下停止执行：$Source"
    }
}

function Set-KitRegistryDword {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [int]$Value
    )

    $target = "{0}\{1}" -f $Path, $Name
    if ($PSCmdlet.ShouldProcess($target, "设置 DWORD 值为 $Value")) {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
        Write-KitLog "已设置资源管理器选项：$target = $Value" "OK"
    }
}

function Copy-KitConfigFile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$Description,

        [string]$Advice
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Register-KitMissingTemplate `
            -Name $Description `
            -Reason "source-missing" `
            -Source $Source `
            -Destination $Destination `
            -Advice $Advice
        return
    }

    if ($PSCmdlet.ShouldProcess($Destination, "复制 $Description")) {
        $destinationDirectory = Split-Path -Path $Destination -Parent
        if (-not (Test-Path -LiteralPath $destinationDirectory)) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        }

        Copy-Item -LiteralPath $Source -Destination $Destination -Force
        Write-KitLog "$Description 已复制：$Destination" "OK"
        Add-KitUserExperienceReportItem `
            -Name $Description `
            -Status "succeeded" `
            -Reason "completed" `
            -Source $Source `
            -Destination $Destination `
            -Advice $Advice
    } else {
        Write-KitLog "预演恢复 $Description：$Source -> $Destination"
        Add-KitUserExperienceReportItem `
            -Name $Description `
            -Status "whatif" `
            -Reason "whatif-preview" `
            -Source $Source `
            -Destination $Destination `
            -Advice $Advice
    }
}

function Copy-KitConfigDirectory {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$Description,

        [string]$Advice,

        [switch]$PrepareDestinationWhenMissing
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        $details = @()
        if ($PrepareDestinationWhenMissing) {
            $state = Ensure-KitDirectory -Path $Destination -Description $Description -WhatIf:$WhatIfPreference
            $details += "destinationState=$state"
        }

        Register-KitMissingTemplate `
            -Name $Description `
            -Reason "source-missing" `
            -Source $Source `
            -Destination $Destination `
            -Advice $Advice `
            -Details $details
        return
    }

    if (-not (Test-KitDirectoryHasContent -Path $Source)) {
        $details = @("sourceState=empty")
        if ($PrepareDestinationWhenMissing) {
            $state = Ensure-KitDirectory -Path $Destination -Description $Description -WhatIf:$WhatIfPreference
            $details += "destinationState=$state"
        }

        Register-KitMissingTemplate `
            -Name $Description `
            -Reason "source-empty" `
            -Source $Source `
            -Destination $Destination `
            -Advice $Advice `
            -Details $details
        return
    }

    if ($PSCmdlet.ShouldProcess($Destination, "恢复 $Description")) {
        if (-not (Test-Path -LiteralPath $Destination)) {
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        }

        foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
            Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
        }

        Write-KitLog "$Description 已恢复：$Destination" "OK"
        Add-KitUserExperienceReportItem `
            -Name $Description `
            -Status "succeeded" `
            -Reason "completed" `
            -Source $Source `
            -Destination $Destination `
            -Advice $Advice
    } else {
        Write-KitLog "预演恢复 $Description：$Source -> $Destination"
        Add-KitUserExperienceReportItem `
            -Name $Description `
            -Status "whatif" `
            -Reason "whatif-preview" `
            -Source $Source `
            -Destination $Destination `
            -Advice $Advice
    }
}

function Import-KitDefaultAppAssociations {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$AssociationFile,

        [string]$Advice
    )

    if (-not (Test-Path -LiteralPath $AssociationFile)) {
        Register-KitMissingTemplate `
            -Name "默认应用关联" `
            -Reason "source-missing" `
            -Source $AssociationFile `
            -Advice $Advice
        return
    }

    if ($PSCmdlet.ShouldProcess($AssociationFile, "导入默认应用关联")) {
        Write-KitLog "导入默认应用关联：$AssociationFile"
        $argument = "/Import-DefaultAppAssociations:$AssociationFile"
        $output = & dism.exe /Online $argument 2>&1
        $exitCode = $LASTEXITCODE

        foreach ($line in @($output)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                Write-KitLog ([string]$line)
            }
        }

        if ($exitCode -ne 0) {
            throw "默认应用关联导入失败，exit code: $exitCode"
        }

        Write-KitLog "默认应用关联导入完成" "OK"
        Add-KitUserExperienceReportItem `
            -Name "默认应用关联" `
            -Status "succeeded" `
            -Reason "completed" `
            -Source $AssociationFile `
            -Advice $Advice
    } else {
        Write-KitLog "预演导入默认应用关联：$AssociationFile"
        Add-KitUserExperienceReportItem `
            -Name "默认应用关联" `
            -Status "whatif" `
            -Reason "whatif-preview" `
            -Source $AssociationFile `
            -Advice $Advice
    }
}

Write-KitLog "开始恢复用户体验配置"

$ScopeManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $ScopeManifestPath
$scopeConfig = Get-Content -LiteralPath $ScopeManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $PathsManifestPath) {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.pathsManifest
} else {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $PathsManifestPath
}

$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath

try {
    if ($scopeConfig.system.defaultApps.enabled) {
        $associationFile = Resolve-KitPath -Path $scopeConfig.system.defaultApps.associationFile -PathMap $pathMap
        Import-KitDefaultAppAssociations `
            -AssociationFile $associationFile `
            -Advice "请补充 DefaultAppAssoc.xml，或在新机上手动导出并导入默认应用关联。" `
            -WhatIf:$WhatIfPreference
    } else {
        Write-KitLog "默认应用关联已停用，跳过"
        Add-KitUserExperienceReportItem -Name "默认应用关联" -Status "skipped" -Reason "disabled"
    }

    if ($scopeConfig.system.explorerOptions.enabled) {
        $advancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        $hideFileExt = if ($scopeConfig.system.explorerOptions.showFileExtensions) { 0 } else { 1 }
        $hidden = if ($scopeConfig.system.explorerOptions.showHiddenFiles) { 1 } else { 2 }

        Set-KitRegistryDword -Path $advancedPath -Name "HideFileExt" -Value $hideFileExt -WhatIf:$WhatIfPreference
        Set-KitRegistryDword -Path $advancedPath -Name "Hidden" -Value $hidden -WhatIf:$WhatIfPreference

        Add-KitUserExperienceReportItem `
            -Name "资源管理器选项" `
            -Status $(if ($WhatIfPreference) { "whatif" } else { "succeeded" }) `
            -Reason $(if ($WhatIfPreference) { "whatif-preview" } else { "completed" }) `
            -Destination $advancedPath
    } else {
        Write-KitLog "资源管理器选项已停用，跳过"
        Add-KitUserExperienceReportItem -Name "资源管理器选项" -Status "skipped" -Reason "disabled"
    }

    if ($scopeConfig.system.startMenu.enabled) {
        $startMenuConfigRoot = Resolve-KitPath -Path $scopeConfig.system.startMenu.config -PathMap $pathMap
        $layoutFile = Join-Path -Path $startMenuConfigRoot -ChildPath "LayoutModification.json"
        $defaultProfileLayout = "C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.json"
        Copy-KitConfigFile `
            -Source $layoutFile `
            -Destination $defaultProfileLayout `
            -Description "开始菜单默认布局" `
            -Advice '请在 ${ConfigRoot}\start-menu 下提供 LayoutModification.json，或在目标机器上手动固定开始菜单。' `
            -WhatIf:$WhatIfPreference
    } else {
        Write-KitLog "开始菜单配置已停用，跳过"
        Add-KitUserExperienceReportItem -Name "开始菜单默认布局" -Status "skipped" -Reason "disabled"
    }

    if (($scopeConfig.system.PSObject.Properties.Name -contains "windowsTerminal") -and $scopeConfig.system.windowsTerminal.enabled) {
        $terminalSource = Resolve-KitPath -Path $scopeConfig.system.windowsTerminal.source -PathMap $pathMap
        $terminalDestination = Resolve-KitPath -Path $scopeConfig.system.windowsTerminal.destination -PathMap $pathMap
        Copy-KitConfigDirectory `
            -Source $terminalSource `
            -Destination $terminalDestination `
            -Description "Windows Terminal 配置模板" `
            -Advice '请在 ${ConfigRoot}\windows-terminal 下提供 settings.json 或相关片段，再重新执行恢复脚本。' `
            -WhatIf:$WhatIfPreference
    } else {
        Write-KitLog "Windows Terminal 配置恢复已停用，跳过"
        Add-KitUserExperienceReportItem -Name "Windows Terminal 配置模板" -Status "skipped" -Reason "disabled"
    }

    if (($scopeConfig.system.PSObject.Properties.Name -contains "vscodePortable") -and $scopeConfig.system.vscodePortable.enabled) {
        $vscodeSource = Resolve-KitPath -Path $scopeConfig.system.vscodePortable.source -PathMap $pathMap
        $vscodeDestination = Resolve-KitPath -Path $scopeConfig.system.vscodePortable.destination -PathMap $pathMap
        Copy-KitConfigDirectory `
            -Source $vscodeSource `
            -Destination $vscodeDestination `
            -Description "VSCode 便携版 data 配置目录" `
            -Advice '请在 ${ConfigRoot}\vscode-portable\data 下补充模板，或后续用 Settings Sync / 手工设置完成恢复。' `
            -PrepareDestinationWhenMissing `
            -WhatIf:$WhatIfPreference
    } else {
        Write-KitLog "VSCode 便携版 data 配置目录恢复已停用，跳过"
        Add-KitUserExperienceReportItem -Name "VSCode 便携版 data 配置目录" -Status "skipped" -Reason "disabled"
    }
} finally {
    Write-KitUserExperienceReport -Path $ReportPath
}

Write-KitLog "用户体验配置恢复完成" "OK"
