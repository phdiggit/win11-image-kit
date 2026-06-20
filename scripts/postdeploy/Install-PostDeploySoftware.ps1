#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\software.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Test-KitPackageHash.ps1"

function Invoke-KitInstallerPackage {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        [hashtable]$PathMap
    )

    if (-not $Package.silentInstall) {
        Write-KitLog "安装器未声明静默安装，保留人工处理：$($Package.name)" "WARN"
        return
    }

    $source = Resolve-KitPath -Path $Package.source -PathMap $PathMap
    if (-not (Test-Path -LiteralPath $source)) {
        Write-KitLog "安装器不存在：$source" "WARN"
        return
    }

    Test-KitPackageHash -Source $source -ExpectedHash ([string]$Package.sha256)
    $arguments = @($Package.installArgs | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })

    if ($PSCmdlet.ShouldProcess($Package.name, "执行静默安装器")) {
        Write-KitLog "执行静默安装器：$($Package.name)"
        $process = Start-Process -FilePath $source -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
        if ($process.ExitCode -ne 0) {
            throw "静默安装失败：$($Package.name)，exit code: $($process.ExitCode)"
        }

        Write-KitLog "静默安装完成：$($Package.name)" "OK"
    }
}

Write-KitLog "开始处理部署后软件"

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

Write-KitLog "部署后软件处理完成" "OK"
