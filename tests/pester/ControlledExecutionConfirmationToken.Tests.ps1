Describe "Controlled execution confirmation token fixtures" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitControlledExecutionReport.ps1")
    }

    It "passes a token that includes the target disk identity" {
        $input = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\confirmation-token\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $result = Test-KitConfirmationToken -InputObject $input

        Assert-KitEqual $result.status "matched"
        Assert-KitEqual $result.failureCount 0
        Assert-KitMatch $result.token "SAMPLE-DISK-SERIAL-001"
    }

    It "blocks generic and mismatched tokens" {
        foreach ($path in @(
            "tests\fixtures\controlled-execution\confirmation-token\generic-yes.json",
            "tests\fixtures\controlled-execution\confirmation-token\serial-mismatch.json"
        )) {
            $input = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8 | ConvertFrom-Json
            $result = Test-KitConfirmationToken -InputObject $input

            Assert-KitEqual $result.status "blocked"
            if ($result.failureCount -lt 1) {
                throw "Expected confirmation token failure for $path."
            }
        }
    }
}
