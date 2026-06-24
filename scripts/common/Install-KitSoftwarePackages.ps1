#Requires -Version 5.1

. "$PSScriptRoot\Write-Log.ps1"
. "$PSScriptRoot\Resolve-KitPath.ps1"
. "$PSScriptRoot\Resolve-KitPackagePolicy.ps1"
. "$PSScriptRoot\Test-KitPackageHash.ps1"

function Test-KitCategoryMatch {
    param(
        [AllowEmptyString()]
        [string]$Category,

        [string[]]$Patterns = @()
    )

    if ($Patterns.Count -eq 0) {
        return $true
    }

    foreach ($pattern in $Patterns) {
        if ($Category -like $pattern) {
            return $true
        }
    }

    return $false
}

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

function Invoke-KitMissingSourcePolicy {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        $Policy,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Detail
    )

    $action = Get-KitPackageMissingSourceAction -Policy $Policy
    $packageName = [string]$Package.name

    switch ($action) {
        "fail" {
            Write-KitLog "source-missing: 必需软件包安装介质缺失或不可访问，处理失败：$packageName -> $Source ($Detail)" "ERROR"
            throw "source-missing: 软件包安装介质缺失或不可访问：$packageName -> $Source ($Detail)"
        }
        "manual" {
            Write-KitLog "source-missing: 软件包安装介质缺失，记录为 manual 人工处理并继续：$packageName -> $Source ($Detail)" "WARN"
        }
        default {
            Write-KitLog "source-missing: 软件包安装介质缺失，skipped 跳过并继续：$packageName -> $Source ($Detail)" "WARN"
        }
    }
}

function Install-KitSoftwarePackages {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\software.json",

        [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json",

        [ValidateSet("golden-image", "post-deploy", "manual", "all")]
        [string]$Stage = "golden-image",

        [string[]]$IncludeCategories = @(),

        [string[]]$ExcludeCategories = @(),

        [string[]]$IncludeTypes = @("archive", "zip"),

        [string]$WorkloadName = "软件包",

        [string]$CompletionMessage = "软件包处理完成"
    )

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

        $category = [string]$package.category
        if (-not (Test-KitCategoryMatch -Category $category -Patterns $IncludeCategories)) {
            Write-KitLog "软件包分类不匹配，跳过：$($package.name) ($category)"
            continue
        }

        if ($ExcludeCategories.Count -gt 0 -and (Test-KitCategoryMatch -Category $category -Patterns $ExcludeCategories)) {
            Write-KitLog "软件包分类由其他入口处理，跳过：$($package.name) ($category)"
            continue
        }

        if ($IncludeTypes.Count -gt 0 -and $IncludeTypes -notcontains [string]$package.type) {
            Write-KitLog "当前入口不处理该类型，跳过：$($package.name) ($($package.type))"
            continue
        }

        $archiveFormat = [string]$package.archiveFormat
        if ([string]$package.type -eq "zip" -and [string]::IsNullOrWhiteSpace($archiveFormat)) {
            $archiveFormat = "zip"
        }

        if ([string]::IsNullOrWhiteSpace($archiveFormat)) {
            throw "归档包缺少 archiveFormat：$($package.name)"
        }

        Write-KitLog "处理$WorkloadName：$($package.name)"
        $policy = Resolve-KitPackagePolicy -Package $package
        $source = Resolve-KitPath -Path $package.source -PathMap $pathMap
        $destination = Resolve-KitPath -Path $package.destination -PathMap $pathMap

        if ([string]::IsNullOrWhiteSpace($source)) {
            throw "软件包缺少 source：$($package.name)"
        }

        if ([string]::IsNullOrWhiteSpace($destination)) {
            throw "软件包缺少 destination：$($package.name)"
        }

        try {
            $sourceExists = Test-Path -LiteralPath $source -ErrorAction Stop
        } catch {
            Invoke-KitMissingSourcePolicy -Package $package -Policy $policy -Source $source -Detail $_.Exception.Message
            continue
        }

        if (-not $sourceExists) {
            Invoke-KitMissingSourcePolicy -Package $package -Policy $policy -Source $source -Detail "Test-Path=false"
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

    Write-KitLog $CompletionMessage "OK"
}
