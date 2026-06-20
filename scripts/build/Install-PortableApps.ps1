#Requires -RunAsAdministrator

param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\software.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"

function Expand-KitArchive {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [string]$ArchiveFormat = "zip"
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    switch ($ArchiveFormat) {
        "zip" {
            Expand-Archive -LiteralPath $Source -DestinationPath $Destination -Force
        }
        "tar.gz" {
            if (-not (Get-Command tar.exe -ErrorAction SilentlyContinue)) {
                throw "当前系统找不到 tar.exe，无法解压 tar.gz：$Source"
            }

            & tar.exe -xzf $Source -C $Destination --strip-components 1
            if ($LASTEXITCODE -ne 0) {
                throw "tar.gz 解压失败：$Source"
            }
        }
        default {
            throw "不支持的归档格式：$ArchiveFormat"
        }
    }
}

function Invoke-KitPostInstall {
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

            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-KitLog "确认目录存在：$path"
        }
        default {
            throw "不支持的 postInstall 动作：$($Step.action)"
        }
    }
}

Write-KitLog "读取软件清单：$ManifestPath"
$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath

foreach ($package in $manifest.packages) {
    if ($null -ne $package.enabled -and -not $package.enabled) {
        Write-KitLog "软件包已停用，跳过：$($package.name)"
        continue
    }

    if ($package.type -notin @("archive", "zip")) {
        Write-KitLog "当前脚本只处理归档包，跳过：$($package.name)"
        continue
    }

    $archiveFormat = [string]$package.archiveFormat
    if ([string]::IsNullOrWhiteSpace($archiveFormat)) {
        $archiveFormat = "zip"
    }

    Write-KitLog "安装归档包：$($package.name)"
    $source = Resolve-KitPath -Path $package.source -PathMap $pathMap
    $destination = Resolve-KitPath -Path $package.destination -PathMap $pathMap

    if (-not (Test-Path -LiteralPath $source)) {
        Write-KitLog "安装包不存在：$source" "WARN"
        continue
    }

    Expand-KitArchive -Source $source -Destination $destination -ArchiveFormat $archiveFormat

    if ($package.env) {
        $package.env.PSObject.Properties | ForEach-Object {
            $value = Resolve-KitPath -Path $_.Value -PathMap $pathMap
            [Environment]::SetEnvironmentVariable($_.Name, $value, "Machine")
            Write-KitLog "写入系统环境变量：$($_.Name)"
        }
    }

    if ($package.path) {
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $pathItems = @($machinePath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

        foreach ($pathEntry in @($package.path)) {
            $resolvedPathEntry = Resolve-KitPath -Path $pathEntry -PathMap $pathMap
            if ($pathItems -notcontains $resolvedPathEntry) {
                $pathItems += $resolvedPathEntry
                Write-KitLog "追加系统 PATH：$resolvedPathEntry"
            }
        }

        [Environment]::SetEnvironmentVariable("Path", ($pathItems -join ';'), "Machine")
    }

    if ($package.postInstall) {
        foreach ($step in @($package.postInstall)) {
            Invoke-KitPostInstall -Step $step -PathMap $pathMap
        }
    }
}

Write-KitLog "归档包安装完成" "OK"
