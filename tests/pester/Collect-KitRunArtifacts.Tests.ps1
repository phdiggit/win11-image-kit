$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

function New-TestRunRoot {
    $root = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-run-{0}" -f ([guid]::NewGuid().ToString("N")))
    New-Item -ItemType Directory -Path (Join-Path $root "logs") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root "reports") -Force | Out-Null
    return $root
}

function Invoke-CollectArtifacts {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $powerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
    if ([string]::IsNullOrWhiteSpace($powerShell)) {
        $powerShell = (Get-Command pwsh -ErrorAction Stop).Source
    }

    $scriptPath = Join-Path $RepoRoot "scripts\dev\Collect-KitRunArtifacts.ps1"
    $output = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1

    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = ($output -join "`n")
    }
}

function Expand-TestArchive {
    param(
        [Parameter(Mandatory)]
        [string]$ArchivePath
    )

    $extractRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-zip-{0}" -f ([guid]::NewGuid().ToString("N")))
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $extractRoot -Force
    return $extractRoot
}

Describe "Collect-KitRunArtifacts" {
    BeforeEach {
        $script:TempPaths = @()
    }

    AfterEach {
        foreach ($path in $script:TempPaths) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "RunRoot 不存在时失败" {
        $missingRoot = Join-Path ([IO.Path]::GetTempPath()) ("missing-{0}" -f ([guid]::NewGuid().ToString("N")))
        $destination = Join-Path ([IO.Path]::GetTempPath()) ("artifacts-{0}.zip" -f ([guid]::NewGuid().ToString("N")))
        $script:TempPaths += $destination

        $result = Invoke-CollectArtifacts -Arguments @("-RunRoot", $missingRoot, "-DestinationPath", $destination)

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch $result.Output "RunRoot"
        Assert-KitNullOrEmpty (Get-ChildItem -LiteralPath $destination -ErrorAction SilentlyContinue)
    }

    It "收集 logs/*.log 和 reports/*.json 并生成 manifest" {
        $runRoot = New-TestRunRoot
        $script:TempPaths += $runRoot
        Set-Content -LiteralPath (Join-Path $runRoot "logs\validation.log") -Value "validation ok" -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $runRoot "reports\validation.json") -Value '{"ok":true}' -Encoding UTF8
        $destination = Join-Path $runRoot "artifacts.zip"

        $result = Invoke-CollectArtifacts -Arguments @("-RunRoot", $runRoot, "-DestinationPath", $destination)
        Assert-KitEqual $result.ExitCode 0
        Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath $destination -ErrorAction SilentlyContinue)

        $extractRoot = Expand-TestArchive -ArchivePath $destination
        $script:TempPaths += $extractRoot
        Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath (Join-Path $extractRoot "logs\validation.log") -ErrorAction SilentlyContinue)
        Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath (Join-Path $extractRoot "reports\validation.json") -ErrorAction SilentlyContinue)
        Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath (Join-Path $extractRoot "artifact-manifest.json") -ErrorAction SilentlyContinue)
    }

    It "manifest 包含相对路径、文件大小和 SHA256" {
        $runRoot = New-TestRunRoot
        $script:TempPaths += $runRoot
        $logPath = Join-Path $runRoot "logs\validation.log"
        Set-Content -LiteralPath $logPath -Value "validation ok" -Encoding UTF8
        $destination = Join-Path $runRoot "artifacts.zip"

        $result = Invoke-CollectArtifacts -Arguments @("-RunRoot", $runRoot, "-DestinationPath", $destination)
        Assert-KitEqual $result.ExitCode 0

        $extractRoot = Expand-TestArchive -ArchivePath $destination
        $script:TempPaths += $extractRoot
        $manifest = Get-Content -LiteralPath (Join-Path $extractRoot "artifact-manifest.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $included = @($manifest.includedFiles | Where-Object { $_.relativePath -eq "logs\validation.log" })

        Assert-KitEqual @($included).Count 1
        Assert-KitEqual ([int64]$included[0].length) ([int64](Get-Item -LiteralPath $logPath).Length)
        Assert-KitMatch $included[0].sha256 "^[a-f0-9]{64}$"
        Assert-KitEqual $manifest.fileCount 1
    }

    It "默认排除镜像、安装包、密钥和证书" {
        $runRoot = New-TestRunRoot
        $script:TempPaths += $runRoot
        foreach ($extension in @(".wim", ".iso", ".exe", ".msi", ".key", ".pfx")) {
            Set-Content -LiteralPath (Join-Path $runRoot "logs\blocked$extension") -Value "blocked" -Encoding UTF8
        }
        Set-Content -LiteralPath (Join-Path $runRoot "logs\keep.log") -Value "keep" -Encoding UTF8
        $destination = Join-Path $runRoot "artifacts.zip"

        $result = Invoke-CollectArtifacts -Arguments @("-RunRoot", $runRoot, "-DestinationPath", $destination)
        Assert-KitEqual $result.ExitCode 0

        $extractRoot = Expand-TestArchive -ArchivePath $destination
        $script:TempPaths += $extractRoot
        Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath (Join-Path $extractRoot "logs\keep.log") -ErrorAction SilentlyContinue)
        foreach ($extension in @(".wim", ".iso", ".exe", ".msi", ".key", ".pfx")) {
            Assert-KitNullOrEmpty (Get-ChildItem -LiteralPath (Join-Path $extractRoot "logs\blocked$extension") -ErrorAction SilentlyContinue)
        }

        $manifest = Get-Content -LiteralPath (Join-Path $extractRoot "artifact-manifest.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-KitEqual @($manifest.skippedFiles | Where-Object { $_.reason -eq "blocked-extension" }).Count 6
    }

    It "不收集 RunRoot 外部文件" {
        $runRoot = New-TestRunRoot
        $outsideRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-outside-{0}" -f ([guid]::NewGuid().ToString("N")))
        $script:TempPaths += $runRoot
        $script:TempPaths += $outsideRoot
        New-Item -ItemType Directory -Path $outsideRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $outsideRoot "outside.log") -Value "outside" -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $runRoot "logs\inside.log") -Value "inside" -Encoding UTF8
        $destination = Join-Path $runRoot "artifacts.zip"

        $result = Invoke-CollectArtifacts -Arguments @("-RunRoot", $runRoot, "-DestinationPath", $destination)
        Assert-KitEqual $result.ExitCode 0

        $extractRoot = Expand-TestArchive -ArchivePath $destination
        $script:TempPaths += $extractRoot
        Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath (Join-Path $extractRoot "logs\inside.log") -ErrorAction SilentlyContinue)
        Assert-KitNullOrEmpty (Get-ChildItem -LiteralPath (Join-Path $extractRoot "outside.log") -ErrorAction SilentlyContinue)
    }

    It "DestinationPath 已存在且未传 Force 时失败" {
        $runRoot = New-TestRunRoot
        $script:TempPaths += $runRoot
        Set-Content -LiteralPath (Join-Path $runRoot "logs\validation.log") -Value "validation" -Encoding UTF8
        $destination = Join-Path $runRoot "artifacts.zip"
        Set-Content -LiteralPath $destination -Value "old" -Encoding UTF8

        $result = Invoke-CollectArtifacts -Arguments @("-RunRoot", $runRoot, "-DestinationPath", $destination)

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch $result.Output "DestinationPath"
    }

    It "-Force 可以覆盖旧 zip" {
        $runRoot = New-TestRunRoot
        $script:TempPaths += $runRoot
        Set-Content -LiteralPath (Join-Path $runRoot "logs\validation.log") -Value "validation" -Encoding UTF8
        $destination = Join-Path $runRoot "artifacts.zip"
        Set-Content -LiteralPath $destination -Value "old" -Encoding UTF8

        $result = Invoke-CollectArtifacts -Arguments @("-RunRoot", $runRoot, "-DestinationPath", $destination, "-Force")

        Assert-KitEqual $result.ExitCode 0
        $extractRoot = Expand-TestArchive -ArchivePath $destination
        $script:TempPaths += $extractRoot
        Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath (Join-Path $extractRoot "artifact-manifest.json") -ErrorAction SilentlyContinue)
    }

    It "-WhatIf 不实际创建 zip" {
        $runRoot = New-TestRunRoot
        $script:TempPaths += $runRoot
        Set-Content -LiteralPath (Join-Path $runRoot "logs\validation.log") -Value "validation" -Encoding UTF8
        $destination = Join-Path $runRoot "artifacts.zip"

        $result = Invoke-CollectArtifacts -Arguments @("-RunRoot", $runRoot, "-DestinationPath", $destination, "-WhatIf")

        Assert-KitEqual $result.ExitCode 0
        Assert-KitNullOrEmpty (Get-ChildItem -LiteralPath $destination -ErrorAction SilentlyContinue)
    }
}
