#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\software.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json",
    [ValidateSet("golden-image", "post-deploy", "manual", "all")]
    [string]$Stage = "golden-image"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"

function Expand-KitArchive {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [string]$ArchiveFormat = "zip"
    )

    if ($PSCmdlet.ShouldProcess($Destination, "创建归档包目标目录")) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    switch ($ArchiveFormat) {
        "zip" {
            if ($PSCmdlet.ShouldProcess("$Source -> $Destination", "解压 zip 归档")) {
                Expand-Archive -LiteralPath $Source -DestinationPath $Destination -Force
            }
        }
        "tar.gz" {
            if (-not (Get-Command tar.exe -ErrorAction SilentlyContinue)) {
                throw "当前系统找不到 tar.exe，无法解压 tar.gz：$Source"
            }

            if ($PSCmdlet.ShouldProcess("$Source -> $Destination", "解压 tar.gz 归档")) {
                & tar.exe -xzf $Source -C $Destination --strip-components 1
                if ($LASTEXITCODE -ne 0) {
                    throw "tar.gz 解压失败：$Source"
                }
            }
        }
        default {
            throw "不支持的归档格式：$ArchiveFormat"
        }
    }
}

function Invoke-KitPostInstall {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        $Step,

        [Parameter(Mandatory)]
        [hashtable]$PathMap
    )

    switch ([string]$Step.action) {
        "ensure-directory" {
            $path = Resolve-KitPath -Path $Step.path -PathMap $PathMap
            if ([string]::IsNullOrWhiteSpace($path)) {
                throw "ensure-directory 缺少 path"
            }

            if ($PSCmdlet.ShouldProcess($path, "确认目录存在")) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
                Write-KitLog "确认目录存在：$path"
            }
        }
        default {
            throw "不支持的 postInstall 动作：$($Step.action)"
        }
    }
}

function Test-KitPackageHash {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [AllowEmptyString()]
        [string]$ExpectedHash
    )

    if ([string]::IsNullOrWhiteSpace($ExpectedHash)) {
        return
    }

    if ($ExpectedHash -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "SHA256 格式无效：$Source"
    }

    $actualHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $ExpectedHash.ToLowerInvariant()) {
        throw "SHA256 校验失败：$Source"
    }

    Write-KitLog "SHA256 校验通过：$Source" "OK"
}

Write-KitLog "读取软件清单：$ManifestPath"
$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath

foreach ($package in $manifest.packages) {
    if ($null -ne $package.enabled -and -not $package.enabled) {
        Write-KitLog "软件包已停用，跳过：$($package.name)"
        continue
    }

    $packageStage = [string]$package.stage
    if ([string]::IsNullOrWhiteSpace($packageStage)) {
        throw "软件包缺少 stage：$($package.name)"
    }

    if ($Stage -ne "all" -and $packageStage -ne $Stage) {
        Write-KitLog "软件包阶段不匹配，跳过：$($package.name) ($packageStage)"
        continue
    }

    if ($package.type -notin @("archive", "zip")) {
        Write-KitLog "当前脚本只处理归档包，跳过：$($package.name) ($($package.type))"
        continue
    }

    $archiveFormat = [string]$package.archiveFormat
    if ([string]::IsNullOrWhiteSpace($archiveFormat)) {
        throw "归档包缺少 archiveFormat：$($package.name)"
    }

    Write-KitLog "安装归档包：$($package.name)"
    $source = Resolve-KitPath -Path $package.source -PathMap $pathMap
    $destination = Resolve-KitPath -Path $package.destination -PathMap $pathMap

    if (-not (Test-Path -LiteralPath $source)) {
        Write-KitLog "安装包不存在：$source" "WARN"
        continue
    }

    Test-KitPackageHash -Source $source -ExpectedHash ([string]$package.sha256)
    Expand-KitArchive -Source $source -Destination $destination -ArchiveFormat $archiveFormat -WhatIf:$WhatIfPreference

    if ($package.env) {
        $package.env.PSObject.Properties | ForEach-Object {
            $value = Resolve-KitPath -Path $_.Value -PathMap $pathMap
            if ($PSCmdlet.ShouldProcess($_.Name, "写入系统环境变量")) {
                [Environment]::SetEnvironmentVariable($_.Name, $value, "Machine")
                Write-KitLog "写入系统环境变量：$($_.Name)"
            }
        }
    }

    if ($package.path) {
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $pathItems = @($machinePath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $pendingPathItems = @()

        foreach ($pathEntry in @($package.path)) {
            $resolvedPathEntry = Resolve-KitPath -Path $pathEntry -PathMap $pathMap
            if ($pathItems -notcontains $resolvedPathEntry) {
                $pathItems += $resolvedPathEntry
                $pendingPathItems += $resolvedPathEntry
            }
        }

        if ($pendingPathItems.Count -gt 0 -and $PSCmdlet.ShouldProcess("Machine PATH", "追加 $($pendingPathItems -join ';')")) {
            [Environment]::SetEnvironmentVariable("Path", ($pathItems -join ';'), "Machine")
            foreach ($pendingPathItem in $pendingPathItems) {
                Write-KitLog "追加系统 PATH：$pendingPathItem"
            }
        }
    }

    if ($package.postInstall) {
        foreach ($step in @($package.postInstall)) {
            Invoke-KitPostInstall -Step $step -PathMap $pathMap -WhatIf:$WhatIfPreference
        }
    }
}

Write-KitLog "归档包安装完成" "OK"
