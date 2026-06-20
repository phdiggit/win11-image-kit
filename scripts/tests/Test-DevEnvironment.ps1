param(
    [string]$SoftwareManifestPath = "$PSScriptRoot\..\..\manifests\software.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json",
    [switch]$SkipCommandTests
)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"

$failed = 0
$skipped = 0

function Invoke-TestCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Command
    )

    Write-KitLog "测试命令：$Name -> $Command"
    cmd.exe /c $Command
    if ($LASTEXITCODE -eq 0) {
        Write-KitLog "测试通过：$Name" "OK"
    } else {
        Write-KitLog "测试失败：$Name，退出码 $LASTEXITCODE" "ERROR"
        $script:failed++
    }
}

if (-not (Test-Path -LiteralPath $SoftwareManifestPath)) {
    Write-KitLog "软件清单不存在：$SoftwareManifestPath" "ERROR"
    exit 1
}

$manifest = Get-Content -LiteralPath $SoftwareManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath

foreach ($package in $manifest.packages) {
    if ($null -ne $package.enabled -and -not $package.enabled) {
        Write-KitLog "软件包已停用，跳过测试：$($package.name)"
        $skipped++
        continue
    }

    if ([string]::IsNullOrWhiteSpace([string]$package.test)) {
        Write-KitLog "软件包未声明测试命令：$($package.name)" "WARN"
        $skipped++
        continue
    }

    $testCommand = Resolve-KitPath -Path $package.test -PathMap $pathMap
    if ($SkipCommandTests) {
        Write-KitLog "仅检查测试命令声明，未执行：$($package.name) -> $testCommand"
        continue
    }

    Invoke-TestCommand -Name $package.name -Command $testCommand
}

if ($failed -gt 0) {
    Write-KitLog "开发环境测试失败：$failed 项失败，$skipped 项跳过。" "ERROR"
    exit 1
}

Write-KitLog "开发环境测试完成：0 项失败，$skipped 项跳过。" "OK"
