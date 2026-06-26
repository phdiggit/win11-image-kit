Describe "Evidence chain redaction policy" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitEvidenceRedaction.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEvidenceChainReport.ps1")
    }

    It "counts allowed redacted values" {
        $fixture = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\evidence-chain\sample-redacted-report.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $result = Test-KitEvidenceRedaction -InputObject $fixture

        Assert-KitEqual $result.blockedCount 0
        Assert-KitEqual ($result.redactedCount -gt 0) $true

        $report = New-KitEvidenceChainReport -RepoRoot $script:RepoRoot
        Assert-KitEqual ($report.redactions.redactedCount -gt 0) $true
        Assert-KitEqual $report.redactions.blockedCount 0
    }

    It "walks PSCustomObject properties before generic enumerable handling" {
        $fixture = [pscustomobject][ordered]@{
            nested = [pscustomobject][ordered]@{
                username = "<redacted>"
                values = @(
                    [pscustomobject][ordered]@{
                        token = "<redacted>"
                    }
                )
            }
        }

        $result = Test-KitEvidenceRedaction -InputObject $fixture

        Assert-KitEqual $result.blockedCount 0
        Assert-KitEqual $result.redactedCount 4
    }

    It "detects blocked sensitive field names" {
        $fixture = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\evidence-chain\sample-blocked-sensitive-report.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $result = Test-KitEvidenceRedaction -InputObject $fixture

        Assert-KitEqual $result.blockedCount 1
        Assert-KitMatch ($result.blockedFields -join ";") "password"
    }

    It "fails validation when blocked sensitive data is present in producer input" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-evidence-redaction-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        try {
            Copy-Item -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\evidence-chain\sample-report-inputs\*") -Destination $tempRoot
            Copy-Item -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\evidence-chain\sample-blocked-sensitive-report.json") -Destination (Join-Path $tempRoot "project-config.json") -Force
            $process = Start-Process -FilePath "powershell" -ArgumentList @(
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-File", (Join-Path $script:RepoRoot "scripts\validate\Test-EvidenceChain.ps1"),
                "-InputManifestPath", "tests/fixtures/evidence-chain/no-such-input-index.json",
                "-InputDirectory", $tempRoot
            ) -NoNewWindow -Wait -PassThru

            Assert-KitEqual $process.ExitCode 1
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }
}
