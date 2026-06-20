param(
    [string]$ScopeManifestPath = "$PSScriptRoot\..\..\manifests\customization-scope.json",
    [switch]$SkipCommandTests,
    [switch]$SkipServiceStatus
)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"

$failed = 0

function Invoke-TestStep {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Script
    )

    Write-KitLog "开始测试：$Name"
    $global:LASTEXITCODE = $null
    & $Script
    $success = $?
    $exitCode = if ($null -ne $global:LASTEXITCODE) { $global:LASTEXITCODE } elseif ($success) { 0 } else { 1 }

    if ($exitCode -eq 0) {
        Write-KitLog "测试步骤通过：$Name" "OK"
    } else {
        Write-KitLog "测试步骤失败：$Name，退出码 $exitCode" "ERROR"
        $script:failed++
    }
}

Write-KitLog "测试部署后关键项"

Invoke-TestStep -Name "项目配置" -Script {
    & "$PSScriptRoot\..\validate\Test-ProjectConfig.ps1" -ScopeManifestPath $ScopeManifestPath
}

if (Test-Path -LiteralPath "D:\") {
    Write-KitLog "D: 存在" "OK"
} else {
    Write-KitLog "D: 不存在" "WARN"
}

Invoke-TestStep -Name "开发环境" -Script {
    & "$PSScriptRoot\Test-DevEnvironment.ps1" -SkipCommandTests:$SkipCommandTests
}

Invoke-TestStep -Name "中间件声明" -Script {
    & "$PSScriptRoot\Test-Middleware.ps1" -SkipServiceStatus:$SkipServiceStatus
}

if ($failed -gt 0) {
    Write-KitLog "部署后测试失败：$failed 个步骤失败。" "ERROR"
    exit 1
}

Write-KitLog "部署后测试通过" "OK"
