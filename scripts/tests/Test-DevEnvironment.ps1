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

function Get-TestCommandExecutablePath {
    param(
        [Parameter(Mandatory)]
        [string]$Command
    )

    $trimmed = $Command.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $null
    }

    $candidate = $null
    if ($trimmed.StartsWith('"')) {
        $closingQuoteIndex = $trimmed.IndexOf('"', 1)
        if ($closingQuoteIndex -gt 1) {
            $candidate = $trimmed.Substring(1, $closingQuoteIndex - 1)
        }
    } else {
        $firstToken = ($trimmed -split '\s+', 2)[0]
        if (-not [string]::IsNullOrWhiteSpace($firstToken)) {
            $candidate = $firstToken
        }
    }

    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return $null
    }

    if ([IO.Path]::IsPathRooted($candidate)) {
        return $candidate
    }

    return $null
}

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

    $testExecutablePath = Get-TestCommandExecutablePath -Command $testCommand
    if ($testExecutablePath -and -not (Test-Path -LiteralPath $testExecutablePath)) {
        Write-KitLog "测试目标不存在，按未安装跳过：$($package.name) -> $testExecutablePath" "WARN"
        $skipped++
        continue
    }

    Invoke-TestCommand -Name $package.name -Command $testCommand
}

if ($failed -gt 0) {
    Write-KitLog "开发环境测试失败：$failed 项失败，$skipped 项跳过。" "ERROR"
    exit 1
}

Write-KitLog "开发环境测试完成：0 项失败，$skipped 项跳过。" "OK"
