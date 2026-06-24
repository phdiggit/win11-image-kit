[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\services.json",
    [string]$PathsManifestPath = "$PSScriptRoot\..\..\manifests\paths.json",
    [string]$ReportPath,
    [switch]$ReportRequired
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Assert-KitElevation.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Test-KitServiceState.ps1"

Assert-KitElevation -Operation "中间件服务注册" -AllowWhatIfPreview

function Invoke-ServiceInstallCommand {
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [Parameter(Mandatory)]
        [string]$Command
    )

    Write-KitLog "注册服务：$ServiceName"
    Write-KitLog "执行命令：$Command"
    $output = & cmd.exe /d /c $Command 2>&1
    $exitCode = $LASTEXITCODE

    foreach ($line in @($output)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
            Write-KitLog ([string]$line)
        }
    }

    if ($exitCode -ne 0) {
        throw "服务注册命令失败：$ServiceName，exit code: $exitCode"
    }

    Write-KitLog "服务注册完成：$ServiceName" "OK"
}

function Write-MiddlewareServiceReport {
    param(
        [AllowNull()]
        $Results = @()
    )

    $report = New-KitServiceStateReport -Results $Results
    if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
        $written = Write-KitTextFile -Path $ReportPath -Content ($report | ConvertTo-Json -Depth 10) -Description "服务状态验证报告" -Required:$ReportRequired
        if ($written) {
            Write-KitLog "服务状态验证报告已写入：$ReportPath" "OK"
        }
    }

    return $report.serviceSummary
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
$serviceResults = @()

foreach ($service in $manifest.services) {
    if ($WhatIfPreference) {
        $serviceResults += Test-KitServiceState -ServiceConfig $service -WhatIf
        Write-KitLog "WhatIf 预演：未注册或查询服务状态：$($service.name)"
        continue
    }

    if (Get-Service -Name $service.name -ErrorAction SilentlyContinue) {
        Write-KitLog "服务已存在：$($service.name)"
        $serviceResults += Test-KitServiceState -ServiceConfig $service
        continue
    }

    $installCommand = Resolve-KitPath -Path $service.install -PathMap $pathMap
    if ([string]::IsNullOrWhiteSpace($installCommand)) {
        throw "服务缺少 install 命令：$($service.name)"
    }

    if ($PSCmdlet.ShouldProcess($service.name, "注册中间件服务")) {
        Invoke-ServiceInstallCommand -ServiceName $service.name -Command $installCommand
        $serviceResults += Test-KitServiceState -ServiceConfig $service
    }
}

$serviceSummary = Write-MiddlewareServiceReport -Results $serviceResults
if ($serviceSummary.exitCode -ne 0) {
    throw "服务状态验证失败：$($serviceSummary.failedRequiredCount) 项 required 服务失败。"
}
