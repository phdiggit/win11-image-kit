#Requires -Version 5.1

. "$PSScriptRoot\Write-Log.ps1"
. "$PSScriptRoot\Resolve-KitPath.ps1"
. "$PSScriptRoot\Resolve-KitPackagePolicy.ps1"
. "$PSScriptRoot\Test-KitPackageHash.ps1"
. "$PSScriptRoot\New-KitPackageResult.ps1"
. "$PSScriptRoot\Invoke-KitPackageTestCommand.ps1"

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

function New-KitMissingSourcePackageResult {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        $Policy,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$Detail,

        [Parameter(Mandatory)]
        [hashtable]$PathMap,

        [datetime]$StartedAt = (Get-Date)
    )

    $action = Get-KitPackageMissingSourceAction -Policy $Policy
    $status = "skipped"
    $errors = @()
    $skippedReason = ""
    $manualAction = ""

    if ($action -eq "fail") {
        $status = "failed"
        $errors = @("source-missing: $Detail")
    } elseif ($action -eq "manual") {
        $status = "manual"
        $manualAction = "provide-source"
    } else {
        $skippedReason = "source-missing"
    }

    return New-KitPackageResult `
        -Package $Package `
        -Status $status `
        -Reason "source-missing" `
        -Message "软件包安装介质缺失或不可访问" `
        -Source $Source `
        -Destination $Destination `
        -Policy $Policy `
        -Errors $errors `
        -SkippedReason $skippedReason `
        -ManualAction $manualAction `
        -TestCommand (New-KitPackageTestCommandNotRun -Package $Package -PathMap $PathMap -Reason "package-not-successful") `
        -StartedAt $StartedAt `
        -EndedAt (Get-Date)
}

function Get-KitPackageRuntimeFailureAction {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        $Policy
    )

    if ([bool]$Policy.required) {
        return "fail"
    }

    $failurePolicy = [string]$Policy.failurePolicy
    if ($null -ne $Package.PSObject.Properties["failurePolicy"] -and -not [string]::IsNullOrWhiteSpace([string]$Package.failurePolicy)) {
        $failurePolicy = [string]$Package.failurePolicy
    }

    if ($failurePolicy -eq "manual") {
        return "manual"
    }

    if ($failurePolicy -eq "skip") {
        return "skip"
    }

    return "fail"
}

function New-KitHashFailurePackageResult {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        $Policy,

        [Parameter(Mandatory)]
        $HashResult,

        [AllowEmptyString()]
        [string]$Destination,

        [Parameter(Mandatory)]
        [hashtable]$PathMap,

        [datetime]$StartedAt = (Get-Date)
    )

    $action = Get-KitPackageRuntimeFailureAction -Package $Package -Policy $Policy
    $status = "failed"
    $skippedReason = ""
    $manualAction = ""

    if ($action -eq "skip") {
        $status = "skipped"
        $skippedReason = [string]$HashResult.reason
    } elseif ($action -eq "manual") {
        $status = "manual"
        $manualAction = "verify-or-replace-source"
    }

    $evidence = [pscustomobject]@{
        expectedHash = [string]$HashResult.expectedHash
        actualHash = [string]$HashResult.actualHash
        hashReason = [string]$HashResult.reason
    }

    return New-KitPackageResult `
        -Package $Package `
        -Status $status `
        -Reason ([string]$HashResult.reason) `
        -Message ([string]$HashResult.message) `
        -Source ([string]$HashResult.source) `
        -Destination $Destination `
        -Policy $Policy `
        -Evidence $evidence `
        -Errors @([string]$HashResult.message) `
        -SkippedReason $skippedReason `
        -ManualAction $manualAction `
        -TestCommand (New-KitPackageTestCommandNotRun -Package $Package -PathMap $PathMap -Reason "package-not-successful") `
        -StartedAt $StartedAt `
        -EndedAt (Get-Date)
}

function New-KitPackageResultForTestCommandFailure {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        $Policy,

        [Parameter(Mandatory)]
        $TestCommandResult,

        [AllowEmptyString()]
        [string]$Source,

        [AllowEmptyString()]
        [string]$Destination,

        [datetime]$StartedAt = (Get-Date)
    )

    $action = Get-KitPackageTestCommandFailureAction -Package $Package -Policy $Policy
    $status = "failed"
    $skippedReason = ""
    $manualAction = ""
    if ($action -eq "skip") {
        $status = "skipped"
        $skippedReason = "test-command-failed"
    } elseif ($action -eq "manual") {
        $status = "manual"
        $manualAction = "inspect-test-command-failure"
    }

    $errorText = if ([string]::IsNullOrWhiteSpace([string]$TestCommandResult.error)) {
        "testCommand failed"
    } else {
        [string]$TestCommandResult.error
    }

    return New-KitPackageResult `
        -Package $Package `
        -Status $status `
        -Reason "test-command-failed" `
        -Message "软件包验证命令失败" `
        -Source $Source `
        -Destination $Destination `
        -Policy $Policy `
        -Errors @($errorText) `
        -SkippedReason $skippedReason `
        -ManualAction $manualAction `
        -TestCommand $TestCommandResult `
        -StartedAt $StartedAt `
        -EndedAt (Get-Date)
}

function Invoke-KitPackageTestFailurePolicy {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        $Policy,

        [Parameter(Mandatory)]
        $TestCommandResult
    )

    $action = Get-KitPackageTestCommandFailureAction -Package $Package -Policy $Policy
    $packageName = [string]$Package.name
    $errorText = if ([string]::IsNullOrWhiteSpace([string]$TestCommandResult.error)) {
        "testCommand failed"
    } else {
        [string]$TestCommandResult.error
    }

    switch ($action) {
        "fail" {
            Write-KitLog "test-command-failed: 软件包验证命令失败，处理失败：$packageName ($errorText)" "ERROR"
            throw "test-command-failed: 软件包验证命令失败：$packageName ($errorText)"
        }
        "manual" {
            Write-KitLog "test-command-failed: 软件包验证命令失败，记录为 manual 人工检查并继续：$packageName ($errorText)" "WARN"
        }
        default {
            Write-KitLog "test-command-failed: 软件包验证命令失败，skipped 跳过并继续：$packageName ($errorText)" "WARN"
        }
    }
}

function Invoke-KitHashFailurePolicy {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        $Policy,

        [Parameter(Mandatory)]
        $HashResult
    )

    $action = Get-KitPackageRuntimeFailureAction -Package $Package -Policy $Policy
    $packageName = [string]$Package.name
    $reason = [string]$HashResult.reason
    $message = [string]$HashResult.message

    switch ($action) {
        "fail" {
            Write-KitLog "${reason}: 软件包 SHA256 校验失败，处理失败：$packageName ($message)" "ERROR"
            throw "${reason}: 软件包 SHA256 校验失败：$packageName ($message)"
        }
        "manual" {
            Write-KitLog "${reason}: 软件包 SHA256 校验失败，记录为 manual 人工核验并继续：$packageName ($message)" "WARN"
        }
        default {
            Write-KitLog "${reason}: 软件包 SHA256 校验失败，skipped 跳过并继续：$packageName ($message)" "WARN"
        }
    }
}

function Write-KitSoftwarePackageReport {
    param(
        [AllowEmptyString()]
        [string]$Path,

        [switch]$Required,

        [string]$ManifestPath,

        [string]$PathsManifestPath,

        [string]$WorkloadName,

        [string]$Stage,

        [string[]]$IncludeCategories = @(),

        [string[]]$ExcludeCategories = @(),

        [string[]]$IncludeTypes = @(),

        [AllowNull()]
        $PackageResults = @()
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $report = [pscustomobject][ordered]@{
        generatedAt = (Get-Date).ToString("s")
        manifestPath = $ManifestPath
        pathsManifestPath = $PathsManifestPath
        reportType = "software-package-results"
        workloadName = $WorkloadName
        stage = $Stage
        includeCategories = @($IncludeCategories)
        excludeCategories = @($ExcludeCategories)
        includeTypes = @($IncludeTypes)
        packageSummary = Get-KitStepResultSummary -Results $PackageResults
        packageResults = @($PackageResults)
    }

    $written = Write-KitTextFile `
        -Path $Path `
        -Content ($report | ConvertTo-Json -Depth 12) `
        -Description "软件包结果报告" `
        -Required:$Required

    if ($written) {
        Write-KitLog "软件包结果报告已写入：$Path" "OK"
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

        [string]$CompletionMessage = "软件包处理完成",

        [string]$PackageReportPath,

        [switch]$PackageReportRequired
    )

    Write-KitLog "读取软件清单：$ManifestPath"
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
    $packageResults = @()

    try {
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

            $packageStartedAt = Get-Date
            $packageResultRecorded = $false
            $policy = Resolve-KitPackagePolicy -Package $package
            $source = Resolve-KitPath -Path $package.source -PathMap $pathMap
            $destination = Resolve-KitPath -Path $package.destination -PathMap $pathMap

            try {
                $archiveFormat = [string]$package.archiveFormat
                if ([string]$package.type -eq "zip" -and [string]::IsNullOrWhiteSpace($archiveFormat)) {
                    $archiveFormat = "zip"
                }

                if ([string]::IsNullOrWhiteSpace($archiveFormat)) {
                    throw "归档包缺少 archiveFormat：$($package.name)"
                }

                Write-KitLog "处理$WorkloadName：$($package.name)"

                if ([string]::IsNullOrWhiteSpace($source)) {
                    throw "软件包缺少 source：$($package.name)"
                }

                if ([string]::IsNullOrWhiteSpace($destination)) {
                    throw "软件包缺少 destination：$($package.name)"
                }

                try {
                    $sourceExists = Test-Path -LiteralPath $source -ErrorAction Stop
                } catch {
                    $packageResults += New-KitMissingSourcePackageResult -Package $package -Policy $policy -Source $source -Destination $destination -Detail $_.Exception.Message -PathMap $pathMap -StartedAt $packageStartedAt
                    $packageResultRecorded = $true
                    Invoke-KitMissingSourcePolicy -Package $package -Policy $policy -Source $source -Detail $_.Exception.Message
                    continue
                }

                if (-not $sourceExists) {
                    $packageResults += New-KitMissingSourcePackageResult -Package $package -Policy $policy -Source $source -Destination $destination -Detail "Test-Path=false" -PathMap $pathMap -StartedAt $packageStartedAt
                    $packageResultRecorded = $true
                    Invoke-KitMissingSourcePolicy -Package $package -Policy $policy -Source $source -Detail "Test-Path=false"
                    continue
                }

                $hashResult = Test-KitPackageHash -Source $source -ExpectedHash ([string]$package.sha256) -PassThru
                if ($hashResult.status -eq "failed") {
                    $packageResults += New-KitHashFailurePackageResult `
                        -Package $package `
                        -Policy $policy `
                        -HashResult $hashResult `
                        -Destination $destination `
                        -PathMap $pathMap `
                        -StartedAt $packageStartedAt
                    $packageResultRecorded = $true
                    Invoke-KitHashFailurePolicy -Package $package -Policy $policy -HashResult $hashResult
                    continue
                }

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

                $testCommandResult = $null
                if ($WhatIfPreference) {
                    $testCommandResult = New-KitPackageTestCommandNotRun -Package $package -PathMap $pathMap -Reason "whatif-preview"
                } elseif ($Stage -ne "post-deploy") {
                    $testCommandResult = New-KitPackageTestCommandNotRun -Package $package -PathMap $pathMap -Reason "stage-not-executable"
                } else {
                    $testCommandResult = Invoke-KitPackageTestCommand -Package $package -PathMap $pathMap
                }

                if ($null -ne $testCommandResult -and [string]$testCommandResult.status -eq "failed") {
                    $packageResults += New-KitPackageResultForTestCommandFailure `
                        -Package $package `
                        -Policy $policy `
                        -TestCommandResult $testCommandResult `
                        -Source $source `
                        -Destination $destination `
                        -StartedAt $packageStartedAt
                    $packageResultRecorded = $true
                    Invoke-KitPackageTestFailurePolicy -Package $package -Policy $policy -TestCommandResult $testCommandResult
                    continue
                }

                $status = if ($WhatIfPreference) { "whatif" } else { "changed" }
                $reason = if ($WhatIfPreference) { "whatif-preview" } else { "completed" }
                $packageResults += New-KitPackageResult `
                    -Package $package `
                    -Status $status `
                    -Reason $reason `
                    -Source $source `
                    -Destination $destination `
                    -Policy $policy `
                    -TestCommand $testCommandResult `
                    -StartedAt $packageStartedAt `
                    -EndedAt (Get-Date)
                $packageResultRecorded = $true
            } catch {
                if (-not $packageResultRecorded) {
                    $packageResults += New-KitPackageResult `
                        -Package $package `
                        -Status "failed" `
                        -Reason "package-processing-failed" `
                        -Message "软件包处理失败" `
                        -Source $source `
                        -Destination $destination `
                        -Policy $policy `
                        -Errors @($_.Exception.Message) `
                        -TestCommand (New-KitPackageTestCommandNotRun -Package $package -PathMap $pathMap -Reason "package-not-successful") `
                        -StartedAt $packageStartedAt `
                        -EndedAt (Get-Date)
                }

                throw
            }
        }

        Write-KitLog $CompletionMessage "OK"
    } finally {
        Write-KitSoftwarePackageReport `
            -Path $PackageReportPath `
            -Required:$PackageReportRequired `
            -ManifestPath $ManifestPath `
            -PathsManifestPath $PathsManifestPath `
            -WorkloadName $WorkloadName `
            -Stage $Stage `
            -IncludeCategories $IncludeCategories `
            -ExcludeCategories $ExcludeCategories `
            -IncludeTypes $IncludeTypes `
            -PackageResults $packageResults
    }
}
