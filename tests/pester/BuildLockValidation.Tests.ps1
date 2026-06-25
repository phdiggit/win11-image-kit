Describe "Build lock validation" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitBuildLock.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitBuildLock.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-build-lock-validation-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory((Join-Path $script:TempRoot "manifests")) | Out-Null
        [IO.Directory]::CreateDirectory((Join-Path $script:TempRoot "scripts\common")) | Out-Null
        [IO.File]::WriteAllBytes((Join-Path $script:TempRoot "manifests\a.json"), [byte[]](97, 98, 99))
        [IO.File]::WriteAllBytes((Join-Path $script:TempRoot "scripts\common\new.ps1"), [byte[]](110, 101, 119))
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    function New-TestBuildLock {
        param(
            [string]$Hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            [string]$Algorithm = "SHA256",
            [bool]$Required = $true,
            [string]$Path = "manifests/a.json",
            [string]$MissingPolicy = "fail",
            [string]$MismatchPolicy = "fail",
            [string]$UntrackedPolicy = "manual"
        )

        [pscustomobject]@{
            lockVersion = 1
            algorithm = $Algorithm
            mode = "verify"
            entries = @([pscustomobject]@{
                path = $Path
                category = "manifest"
                required = $Required
                hash = $Hash
                reason = "fixture"
            })
            watchGlobs = @("manifests/*.json", "scripts/common/*.ps1")
            policy = [pscustomobject]@{
                missingRequired = $MissingPolicy
                hashMismatch = $MismatchPolicy
                untrackedWatchedFile = $UntrackedPolicy
                unsupportedAlgorithm = "fail"
            }
        }
    }

    It "passes matching hashes" {
        $results = @(Test-KitBuildLock -BuildLock (New-TestBuildLock -UntrackedPolicy "pass") -RepoRoot $script:TempRoot)
        $entry = @($results | Where-Object { $_.path -eq "manifests/a.json" })[0]

        Assert-KitEqual $entry.status "passed"
        Assert-KitEqual $entry.exists $true
        Assert-KitEqual $entry.actualHash "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    }

    It "handles missing required files according to policy" {
        $failed = @(Test-KitBuildLock -BuildLock (New-TestBuildLock -Path "manifests/missing.json" -MissingPolicy "fail") -RepoRoot $script:TempRoot)[0]
        $manual = @(Test-KitBuildLock -BuildLock (New-TestBuildLock -Path "manifests/missing.json" -MissingPolicy "manual") -RepoRoot $script:TempRoot)[0]

        Assert-KitEqual $failed.status "failed"
        Assert-KitMatch ($failed.errors -join ";") "required file missing"
        Assert-KitEqual $manual.status "manual"
        Assert-KitMatch ($manual.warnings -join ";") "required file missing"
    }

    It "handles hash mismatch according to policy" {
        $failed = @(Test-KitBuildLock -BuildLock (New-TestBuildLock -Hash ("0" * 64) -MismatchPolicy "fail") -RepoRoot $script:TempRoot)[0]
        $manual = @(Test-KitBuildLock -BuildLock (New-TestBuildLock -Hash ("0" * 64) -MismatchPolicy "manual") -RepoRoot $script:TempRoot)[0]

        Assert-KitEqual $failed.status "failed"
        Assert-KitMatch ($failed.errors -join ";") "hash mismatch"
        Assert-KitEqual $manual.status "manual"
        Assert-KitMatch ($manual.warnings -join ";") "hash mismatch"
    }

    It "fails unsupported algorithms" {
        $result = @(Test-KitBuildLock -BuildLock (New-TestBuildLock -Algorithm "SHA1") -RepoRoot $script:TempRoot)[0]

        Assert-KitEqual $result.status "failed"
        Assert-KitMatch ($result.errors -join ";") "unsupported algorithm"
    }

    It "reports watched files that are not listed in entries" {
        $results = @(Test-KitBuildLock -BuildLock (New-TestBuildLock -UntrackedPolicy "manual") -RepoRoot $script:TempRoot)
        $untracked = @($results | Where-Object { $_.category -eq "untracked" })

        Assert-KitEqual (@($untracked | Where-Object { $_.path -eq "scripts/common/new.ps1" }).Count) 1
        Assert-KitEqual (@($untracked | Where-Object { $_.status -eq "manual" }).Count -gt 0) $true
        Assert-KitMatch (($untracked | ForEach-Object { $_.warnings }) -join ";") "watched file"
    }

    It "does not update the lock file or call business handlers" {
        function Invoke-GoldenImageBuild { }
        function Invoke-PostDeploy { }
        Mock Invoke-GoldenImageBuild { throw "should not build image" }
        Mock Invoke-PostDeploy { throw "should not run postdeploy" }

        $lockPath = Join-Path $script:TempRoot "manifests\build-lock.json"
        $lockJson = (New-TestBuildLock -Hash ("0" * 64)) | ConvertTo-Json -Depth 8
        $lockJson | Set-Content -LiteralPath $lockPath -Encoding UTF8

        $lock = Get-KitBuildLock -Path $lockPath -RepoRoot $script:TempRoot
        Test-KitBuildLock -BuildLock $lock -RepoRoot $script:TempRoot | Out-Null

        Assert-KitEqual (Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8) ($lockJson + [Environment]::NewLine)
        Assert-MockCalled Invoke-GoldenImageBuild -Times 0 -Exactly
        Assert-MockCalled Invoke-PostDeploy -Times 0 -Exactly
    }
}
