Describe "Evidence chain artifact index" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEvidenceChainReport.ps1")
    }

    It "includes valid baseline artifact identity" {
        $report = New-KitEvidenceChainReport -RepoRoot $script:RepoRoot -RunId "kit-run-20260626T123456Z-a659a041"

        Assert-KitEqual $report.summary.artifactCount 4
        foreach ($artifact in @($report.artifactIndex)) {
            Assert-KitEqual $artifact.private $false
            Assert-KitMatch ([string]$artifact.runId) '^(kit-run-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{7,12}|manual|not-captured)$'
            if ($artifact.PSObject.Properties.Name -contains "sha256") {
                Assert-KitMatch ([string]$artifact.sha256) '^[A-Fa-f0-9]{64}$'
            }
            if ($artifact.PSObject.Properties.Name -contains "sizeBytes") {
                Assert-KitEqual ([int64]$artifact.sizeBytes -ge 0) $true
            }
        }
    }

    It "keeps WIM identity as a logical not-captured placeholder" {
        $report = New-KitEvidenceChainReport -RepoRoot $script:RepoRoot -RunId "kit-run-20260626T123456Z-a659a041"
        $wim = @($report.artifactIndex | Where-Object { $_.kind -eq "wim-placeholder" })[0]

        Assert-KitEqual $wim.logicalName "golden-image-wim-not-captured"
        Assert-KitEqual $wim.runId "not-captured"
        Assert-KitEqual $wim.status "not-captured"
        Assert-KitEqual ($wim.PSObject.Properties.Name -contains "sha256") $false
    }

    It "rejects private, absolute, UNC, and paths.local artifacts through validation" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-evidence-artifacts-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        try {
            $badIndexPath = Join-Path $tempRoot "bad-artifacts.json"
            $badIndex = [pscustomobject]@{
                schemaVersion = 1
                runId = "kit-run-20260626T123456Z-a659a041"
                artifacts = @(
                    [pscustomobject]@{ kind = "report"; path = "manifests/paths.local.json"; producerId = "project-config"; stage = "validate"; runId = "kit-run-20260626T123456Z-a659a041"; private = $false; redacted = $false },
                    [pscustomobject]@{ kind = "report"; path = "C:\private\report.json"; producerId = "project-config"; stage = "validate"; runId = "kit-run-20260626T123456Z-a659a041"; private = $false; redacted = $false },
                    [pscustomobject]@{ kind = "report"; path = "\\server\share\report.json"; producerId = "project-config"; stage = "validate"; runId = "kit-run-20260626T123456Z-a659a041"; private = $false; redacted = $false },
                    [pscustomobject]@{ kind = "report"; path = "tests/fixtures/evidence-chain/private.json"; producerId = "project-config"; stage = "validate"; runId = "kit-run-20260626T123456Z-a659a041"; private = $true; redacted = $false }
                )
            }
            $badIndex | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $badIndexPath -Encoding UTF8

            $process = Start-Process -FilePath "powershell" -ArgumentList @(
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-File", (Join-Path $script:RepoRoot "scripts\validate\Test-EvidenceChain.ps1"),
                "-ArtifactIndexPath", $badIndexPath
            ) -NoNewWindow -Wait -PassThru

            Assert-KitEqual $process.ExitCode 1
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }
}
