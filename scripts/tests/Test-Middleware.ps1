param(
    [string]$ServicesManifestPath = "$PSScriptRoot\..\..\manifests\services.json",
    [switch]$SkipServiceStatus
)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"

$failed = 0
$skipped = 0

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

    if ($SkipServiceStatus) {
        Write-KitLog "仅检查服务声明，未查询服务状态：$($service.name)"
        $skipped++
        continue
    }

    $existing = Get-Service -Name $service.name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-KitLog "服务存在：$($service.name) ($($existing.Status))" "OK"
    } else {
        Write-KitLog "服务尚未注册：$($service.name)" "WARN"
        $skipped++
    }
}

if ($failed -gt 0) {
    Write-KitLog "中间件测试失败：$failed 项失败，$skipped 项跳过。" "ERROR"
    exit 1
}

Write-KitLog "中间件测试完成：0 项失败，$skipped 项跳过。" "OK"
