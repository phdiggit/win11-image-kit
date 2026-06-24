$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

Describe "Project config validation" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "默认配置验证可以在子进程中成功运行" {
        $powerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($powerShell)) {
            $powerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $scriptPath = Join-Path $RepoRoot "scripts\validate\Test-ProjectConfig.ps1"
        $output = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1
        $exitCode = $LASTEXITCODE

        Assert-KitEqual $exitCode 0
        Assert-KitMatch ($output -join "`n") "项目配置验证通过"
    }

    It "默认验证不会创建本地验证报告或日志" {
        Assert-KitNullOrEmpty (Get-ChildItem -LiteralPath (Join-Path $RepoRoot "logs") -Filter "project-config-validation-*" -ErrorAction SilentlyContinue)
    }

    It "默认验证不强制访问安装包或 NAS 文件" {
        $powerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($powerShell)) {
            $powerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $scriptPath = Join-Path $RepoRoot "scripts\validate\Test-ProjectConfig.ps1"
        $output = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1

        Assert-KitNotMatch ($output -join "`n") "安装介质不存在或 NAS 不可达"
    }

    It "显式 ReportPath 会写入兼容 results 和 StepResult 摘要" {
        $powerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($powerShell)) {
            $powerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $scriptPath = Join-Path $RepoRoot "scripts\validate\Test-ProjectConfig.ps1"
        $reportPath = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-project-config-{0}.json" -f ([guid]::NewGuid().ToString("N")))
        & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -ReportPath $reportPath | Out-Null
        $exitCode = $LASTEXITCODE

        try {
            Assert-KitEqual $exitCode 0
            Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath $reportPath -ErrorAction SilentlyContinue)

            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            Assert-KitNotNullOrEmpty $report.results
            Assert-KitNotNullOrEmpty $report.stepResults
            Assert-KitNotNullOrEmpty $report.stepSummary
            Assert-KitEqual $report.stepSummary.exitCode 0
            Assert-KitEqual $report.stepSummary.failedRequiredCount 0
        } finally {
            Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
        }
    }
}
