[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [string]$ManifestPath = "manifests/software.json",
    [string]$PathsManifestPath = "manifests/paths.json",
    [string]$ReportPath,
    [switch]$ReportRequired
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Assert-KitElevation.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPackagePolicy.ps1"
. "$PSScriptRoot\..\common\Test-KitPackageHash.ps1"

$script:InstallerReportItems = @()
$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Resolve-KitRepoPath {
    param(
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }

    return [IO.Path]::GetFullPath((Join-Path -Path $repoRoot -ChildPath $Path))
}

$ManifestPath = Resolve-KitRepoPath -Path $ManifestPath
$PathsManifestPath = Resolve-KitRepoPath -Path $PathsManifestPath

function Resolve-KitInstallerArguments {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        [hashtable]$PathMap
    )

    $resolvedArguments = @()
    foreach ($argument in @($Package.installArgs)) {
        if ([string]::IsNullOrWhiteSpace([string]$argument)) {
            continue
        }

        $resolvedArguments += Resolve-KitPath -Path ([string]$argument) -PathMap $PathMap
    }

    return $resolvedArguments
}

function Get-KitInstallerSuccessExitCodes {
    param(
        [Parameter(Mandatory)]
        $Package
    )

    if ($null -eq $Package.successExitCodes) {
        return @(0)
    }

    $codes = @()
    foreach ($exitCode in @($Package.successExitCodes)) {
        $codes += [int]$exitCode
    }

    if ($codes.Count -eq 0) {
        throw "安装器 successExitCodes 不能为空：$($Package.name)"
    }

    return $codes
}

function Format-KitInstallerCommand {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @()
    )

    $quotedFilePath = '"' + $FilePath + '"'
    if ($Arguments.Count -eq 0) {
        return $quotedFilePath
    }

    return "$quotedFilePath $($Arguments -join ' ')"
}

function Add-KitInstallerReportItem {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Status,

        [string]$Reason,
        [string]$Source,
        [string]$Destination,
        [string]$Command,
        [AllowNull()]
        [int[]]$SuccessExitCodes,
        [AllowNull()]
        [int]$ExitCode,
        [bool]$SilentInstall = $false,
        [string]$Uninstall,
        [bool]$Required = $true,
        [string]$FailurePolicy = "fail",
        [bool]$AllowMissingSource = $false
    )

    $script:InstallerReportItems += [pscustomobject]@{
        name = $Name
        status = $Status
        reason = $Reason
        source = $Source
        destination = $Destination
        command = $Command
        successExitCodes = $SuccessExitCodes
        exitCode = $ExitCode
        silentInstall = $SilentInstall
        uninstall = $Uninstall
        required = [bool]$Required
        failurePolicy = $FailurePolicy
        allowMissingSource = [bool]$AllowMissingSource
    }
}

function Write-KitInstallerManualChecklist {
    $manualItems = @(
        $script:InstallerReportItems |
            Where-Object { $_.status -eq "manual" }
    )

    if ($manualItems.Count -eq 0) {
        return
    }

    Write-KitLog "以下安装器保留为人工处理清单：" "WARN"
    foreach ($item in $manualItems) {
        $commandText = if ([string]::IsNullOrWhiteSpace([string]$item.command)) { "<无命令>" } else { $item.command }
        Write-KitLog ("  {0}: {1}" -f $item.name, $commandText) "WARN"
    }
}

function Write-KitInstallerReport {
    param(
        [AllowEmptyString()]
        [string]$Path,

        [switch]$Required
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $resolvedPath = Resolve-KitRepoPath -Path $Path
    $directory = Split-Path -Path $resolvedPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force -WhatIf:$false | Out-Null
    }

    $summary = [pscustomobject]@{
        total = @($script:InstallerReportItems).Count
        succeeded = @($script:InstallerReportItems | Where-Object { $_.status -eq "succeeded" }).Count
        failed = @($script:InstallerReportItems | Where-Object { $_.status -eq "failed" }).Count
        skipped = @($script:InstallerReportItems | Where-Object { $_.status -eq "skipped" }).Count
        manual = @($script:InstallerReportItems | Where-Object { $_.status -eq "manual" }).Count
        whatif = @($script:InstallerReportItems | Where-Object { $_.status -eq "whatif" }).Count
    }

    $report = [pscustomobject]@{
        generatedAt = (Get-Date).ToString("s")
        manifestPath = $ManifestPath
        reportType = "post-deploy-installer-plan"
        summary = $summary
        items = $script:InstallerReportItems
    }

    $written = Write-KitTextFile `
        -Path $resolvedPath `
        -Content ($report | ConvertTo-Json -Depth 8) `
        -Description "安装器计划报告" `
        -Required:$Required

    if ($written) {
        Write-KitLog "安装器计划报告已写入：$resolvedPath" "OK"
    }
}

function Invoke-KitInstallerPackage {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        [hashtable]$PathMap
    )

    $source = Resolve-KitPath -Path $Package.source -PathMap $PathMap
    $destination = Resolve-KitPath -Path $Package.destination -PathMap $PathMap
    $arguments = Resolve-KitInstallerArguments -Package $Package -PathMap $PathMap
    $successExitCodes = Get-KitInstallerSuccessExitCodes -Package $Package
    $uninstallCommand = Resolve-KitPath -Path ([string]$Package.uninstall) -PathMap $PathMap
    $commandText = Format-KitInstallerCommand -FilePath $source -Arguments $arguments
    $policy = Resolve-KitPackagePolicy -Package $Package
    $missingSourceAction = Get-KitPackageMissingSourceAction -Policy $policy

    if (-not $Package.silentInstall) {
        if ($missingSourceAction -eq "fail") {
            Write-KitLog "安装器必须自动静默处理，但 silentInstall=false：$($Package.name)" "ERROR"
            Add-KitInstallerReportItem `
                -Name ([string]$Package.name) `
                -Status "failed" `
                -Reason "silent-install-required" `
                -Source $source `
                -Destination $destination `
                -Command $commandText `
                -SuccessExitCodes $successExitCodes `
                -SilentInstall $false `
                -Uninstall $uninstallCommand `
                -Required $policy.required `
                -FailurePolicy $policy.failurePolicy `
                -AllowMissingSource $policy.allowMissingSource
            throw "silent-install-required: 必需安装器未声明静默安装：$($Package.name)"
        }

        $manualStatus = "manual"
        if ($missingSourceAction -eq "skip") {
            $manualStatus = "skipped"
            Write-KitLog "安装器未声明静默安装，按策略 skipped 跳过：$($Package.name)" "WARN"
        } else {
            Write-KitLog "安装器未声明静默安装，保留 manual 人工处理：$($Package.name)" "WARN"
        }

        Add-KitInstallerReportItem `
            -Name ([string]$Package.name) `
            -Status $manualStatus `
            -Reason "silentInstall=false" `
            -Source $source `
            -Destination $destination `
            -Command $commandText `
            -SuccessExitCodes $successExitCodes `
            -SilentInstall $false `
            -Uninstall $uninstallCommand `
            -Required $policy.required `
            -FailurePolicy $policy.failurePolicy `
            -AllowMissingSource $policy.allowMissingSource
        return
    }

    $sourceError = ""
    try {
        $sourceExists = Test-Path -LiteralPath $source -ErrorAction Stop
    } catch {
        $sourceExists = $false
        $sourceError = $_.Exception.Message
    }

    if (-not $sourceExists) {
        $sourceDetail = if ([string]::IsNullOrWhiteSpace($sourceError)) { "Test-Path=false" } else { $sourceError }
        $sourceStatus = "skipped"
        if ($missingSourceAction -eq "manual") {
            $sourceStatus = "manual"
            Write-KitLog "source-missing: 安装器不存在，记录为 manual 人工处理并继续：$source ($sourceDetail)" "WARN"
        } elseif ($missingSourceAction -eq "fail") {
            $sourceStatus = "failed"
            Write-KitLog "source-missing: 必需安装器不存在或不可访问，处理失败：$source ($sourceDetail)" "ERROR"
        } else {
            Write-KitLog "source-missing: 安装器不存在，skipped 跳过并继续：$source ($sourceDetail)" "WARN"
        }

        Add-KitInstallerReportItem `
            -Name ([string]$Package.name) `
            -Status $sourceStatus `
            -Reason "source-missing" `
            -Source $source `
            -Destination $destination `
            -Command $commandText `
            -SuccessExitCodes $successExitCodes `
            -SilentInstall $true `
            -Uninstall $uninstallCommand `
            -Required $policy.required `
            -FailurePolicy $policy.failurePolicy `
            -AllowMissingSource $policy.allowMissingSource

        if ($missingSourceAction -eq "fail") {
            throw "source-missing: 必需安装器不存在或不可访问：$($Package.name) -> $source ($sourceDetail)"
        }

        return
    }

    Test-KitPackageHash -Source $source -ExpectedHash ([string]$Package.sha256)

    if (-not $PSCmdlet.ShouldProcess($Package.name, "执行静默安装器：$commandText")) {
        $reason = if ($WhatIfPreference) { "whatif-preview" } else { "shouldprocess-declined" }
        Add-KitInstallerReportItem `
            -Name ([string]$Package.name) `
            -Status "whatif" `
            -Reason $reason `
            -Source $source `
            -Destination $destination `
            -Command $commandText `
            -SuccessExitCodes $successExitCodes `
            -SilentInstall $true `
            -Uninstall $uninstallCommand `
            -Required $policy.required `
            -FailurePolicy $policy.failurePolicy `
            -AllowMissingSource $policy.allowMissingSource
        return
    }

    Write-KitLog "执行静默安装器：$($Package.name)"
    Write-KitLog "安装器命令：$commandText"
    Write-KitLog "允许成功退出码：$($successExitCodes -join ', ')"

    $process = Start-Process -FilePath $source -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    $exitCode = [int]$process.ExitCode
    Write-KitLog "安装器退出码：$($Package.name) -> $exitCode"

    if ($successExitCodes -notcontains $exitCode) {
        Add-KitInstallerReportItem `
            -Name ([string]$Package.name) `
            -Status "failed" `
            -Reason "unexpected-exit-code" `
            -Source $source `
            -Destination $destination `
            -Command $commandText `
            -SuccessExitCodes $successExitCodes `
            -ExitCode $exitCode `
            -SilentInstall $true `
            -Uninstall $uninstallCommand `
            -Required $policy.required `
            -FailurePolicy $policy.failurePolicy `
            -AllowMissingSource $policy.allowMissingSource
        Write-KitLog "静默安装失败：$($Package.name)，退出码不在允许列表内。" "ERROR"
        throw "静默安装失败：$($Package.name)，exit code: $exitCode，allowed: $($successExitCodes -join ', ')，command: $commandText"
    }

    Add-KitInstallerReportItem `
        -Name ([string]$Package.name) `
        -Status "succeeded" `
        -Reason "completed" `
        -Source $source `
        -Destination $destination `
        -Command $commandText `
        -SuccessExitCodes $successExitCodes `
        -ExitCode $exitCode `
        -SilentInstall $true `
        -Uninstall $uninstallCommand `
        -Required $policy.required `
        -FailurePolicy $policy.failurePolicy `
        -AllowMissingSource $policy.allowMissingSource
    Write-KitLog "静默安装完成：$($Package.name)" "OK"
}

Write-KitLog "开始处理部署后软件"
Assert-KitElevation -Operation "部署后软件安装入口" -AllowWhatIfPreview

try {
    $archiveInstaller = "$PSScriptRoot\..\build\Install-PortableApps.ps1"
    if (Test-Path -LiteralPath $archiveInstaller) {
        & $archiveInstaller `
            -ManifestPath $ManifestPath `
            -PathsManifestPath $PathsManifestPath `
            -Stage "post-deploy" `
            -WhatIf:$WhatIfPreference
    } else {
        throw "归档软件安装脚本不存在：$archiveInstaller"
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath

    foreach ($package in $manifest.packages) {
        if ($null -ne $package.enabled -and -not $package.enabled) {
            Write-KitLog "软件包已停用，跳过：$($package.name)"
            continue
        }

        if ([string]$package.stage -ne "post-deploy") {
            continue
        }

        switch ([string]$package.type) {
            "installer" {
                Invoke-KitInstallerPackage -Package $package -PathMap $pathMap -WhatIf:$WhatIfPreference
            }
            "manual" {
                Write-KitLog "手工软件包，跳过自动安装：$($package.name)" "WARN"
            }
        }
    }

    Write-KitInstallerManualChecklist
    Write-KitLog "部署后软件处理完成" "OK"
} finally {
    Write-KitInstallerReport -Path $ReportPath -Required:$ReportRequired
}
