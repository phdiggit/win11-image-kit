param(
    [string]$ServicesManifestPath = "$PSScriptRoot\..\..\manifests\services.json",
    [switch]$SkipServiceStatus,
    [string]$ReportPath,
    [switch]$ReportRequired
)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Test-KitServiceState.ps1"

$failed = 0
$skipped = 0
$serviceResults = @()

if (-not (Test-Path -LiteralPath $ServicesManifestPath)) {
    Write-KitLog "服务清单不存在：$ServicesManifestPath" "ERROR"
    exit 1
}

$manifest = Get-Content -LiteralPath $ServicesManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($service in $manifest.services) {
    if ([string]::IsNullOrWhiteSpace([string]$service.name)) {
        Write-KitLog "服务条目缺少 name" "ERROR"
        $failed++
        continue
    }

    if ([string]::IsNullOrWhiteSpace([string]$service.install)) {
        Write-KitLog "服务缺少 install 命令：$($service.name)" "ERROR"
        $failed++
    }

    $serviceResult = Test-KitServiceState -ServiceConfig $service -WhatIf:$SkipServiceStatus
    $serviceResults += $serviceResult

    switch ($serviceResult.status) {
        "unchanged" {
            Write-KitLog "服务状态符合预期：$($serviceResult.serviceName) ($($serviceResult.actualState))" "OK"
        }
        "whatif" {
            Write-KitLog "仅检查服务声明，未查询服务状态：$($serviceResult.serviceName)"
            $skipped++
        }
        "skipped" {
            Write-KitLog "服务状态验证跳过：$($serviceResult.serviceName)，$($serviceResult.reason)" "WARN"
            $skipped++
        }
        "manual" {
            Write-KitLog "服务状态需要人工确认：$($serviceResult.serviceName)，$($serviceResult.reason)" "WARN"
            $skipped++
        }
        "failed" {
            Write-KitLog "服务状态验证失败：$($serviceResult.serviceName)，$($serviceResult.reason)" "ERROR"
        }
        default {
            Write-KitLog "服务状态验证结果：$($serviceResult.serviceName)，$($serviceResult.status)"
        }
    }
}

$serviceSummary = Get-KitServiceResultSummary -Results $serviceResults
if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $report = New-KitServiceStateReport -Results $serviceResults
    $written = Write-KitTextFile -Path $ReportPath -Content ($report | ConvertTo-Json -Depth 10) -Description "服务状态验证报告" -Required:$ReportRequired
    if ($written) {
        Write-KitLog "服务状态验证报告已写入：$ReportPath" "OK"
    }
}

if ($failed -gt 0 -or $serviceSummary.exitCode -ne 0) {
    Write-KitLog "中间件测试失败：$failed 项声明失败，$($serviceSummary.failedRequiredCount) 项 required 服务失败，$skipped 项跳过。" "ERROR"
    exit 1
}

Write-KitLog "中间件测试完成：0 项声明失败，$($serviceSummary.failedOptionalCount) 项 optional 服务失败，$skipped 项跳过。" "OK"
