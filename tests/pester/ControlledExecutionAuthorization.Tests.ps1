Describe "Controlled execution authorization contract" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitControlledExecutionSafety.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitControlledExecutionAuthorization.ps1")

        $script:ReadAuthorizationFixture = {
            param([string]$Name)
            Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\authorization\$Name.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }

    It "passes the matched fixture without allowing true execution" {
        $result = Test-KitControlledExecutionAuthorization -InputObject (& $script:ReadAuthorizationFixture -Name "matched")

        Assert-KitEqual $result.status "planned"
        Assert-KitEqual $result.failureCount 0
        Assert-KitEqual $result.trueExecutionAllowed $false
    }

    It "blocks execute requests in the current Issue 17 stage" {
        $result = Test-KitControlledExecutionAuthorization -InputObject (& $script:ReadAuthorizationFixture -Name "execute-request-blocked")

        Assert-KitEqual $result.status "blocked"
        Assert-KitEqual $result.executeRequestBlockedCount 1
        Assert-KitMatch $result.reason "not implemented/enabled"
    }

    It "blocks missing token, missing disk identity, and stale run IDs" {
        foreach ($name in @("missing-token", "missing-disk-identity", "stale-runid")) {
            $result = Test-KitControlledExecutionAuthorization -InputObject (& $script:ReadAuthorizationFixture -Name $name)
            Assert-KitEqual $result.status "blocked"
            if ($result.failureCount -lt 1) {
                throw "Expected authorization failure count for $name."
            }
        }
    }

    It "keeps token match insufficient for true execution" {
        $input = & $script:ReadAuthorizationFixture -Name "matched"
        $input.trueExecutionAllowed = $true
        $result = Test-KitControlledExecutionAuthorization -InputObject $input

        Assert-KitEqual $result.status "blocked"
        Assert-KitEqual $result.trueExecutionAllowed $false
        Assert-KitMatch $result.reason "trueExecutionAllowed"
    }
}
