$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Defender exclusion policy preflight" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitDefenderExclusionPolicy.ps1")

        $script:TempRoot = Join-Path $script:RepoRoot (".tmp\pester-defender-policy-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
        $script:PathMap = @{
            WorkRoot = Join-Path $script:TempRoot "work"
            DeployRoot = Join-Path $script:TempRoot "deploy"
            PackageRoot = Join-Path $script:TempRoot "packages"
            ConfigRoot = Join-Path $script:TempRoot "configs"
            ToolRoot = Join-Path $script:TempRoot "tools"
            DataRoot = Join-Path $script:TempRoot "data"
        }
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "allows kit-managed cache and deploy report paths" {
        $cache = [pscustomobject]@{
            id = "cache"
            type = "path"
            value = '${WorkRoot}\cache'
            scope = "kit-cache"
            reason = "cache"
            required = $false
            failurePolicy = "manual"
        }
        $report = [pscustomobject]@{
            id = "reports"
            type = "path"
            value = '${DeployRoot}\reports'
            scope = "kit-reports"
            reason = "reports"
            required = $false
            failurePolicy = "manual"
        }

        Assert-KitEqual (Test-KitDefenderExclusionPolicy -Exclusion $cache -PathMap $script:PathMap -RepoRoot $script:RepoRoot).policyStatus "allowed"
        Assert-KitEqual (Test-KitDefenderExclusionPolicy -Exclusion $report -PathMap $script:PathMap -RepoRoot $script:RepoRoot).policyStatus "allowed"
    }

    It "blocks broad system and user paths" {
        $paths = @(
            "C:\",
            "D:\",
            "$env:SystemRoot",
            "C:\Windows\System32",
            "$env:ProgramFiles",
            "C:\Users",
            "$env:USERPROFILE",
            (Join-Path $env:USERPROFILE "Desktop"),
            (Join-Path $env:USERPROFILE "Downloads")
        )

        foreach ($path in $paths) {
            $item = [pscustomobject]@{
                id = "blocked"
                type = "path"
                value = $path
                scope = "blocked"
                reason = "blocked"
                required = $false
                failurePolicy = "manual"
            }

            Assert-KitEqual (Test-KitDefenderExclusionPolicy -Exclusion $item -PathMap $script:PathMap -RepoRoot $script:RepoRoot).policyStatus "blocked"
        }
    }

    It "blocks wildcards, path traversal, and UNC share roots" {
        $values = @(
            '${WorkRoot}\*\cache',
            '${WorkRoot}\..\Windows',
            '\\server\share'
        )

        foreach ($value in $values) {
            $item = [pscustomobject]@{
                id = "blocked"
                type = "path"
                value = $value
                scope = "blocked"
                reason = "blocked"
                required = $false
                failurePolicy = "manual"
            }

            Assert-KitEqual (Test-KitDefenderExclusionPolicy -Exclusion $item -PathMap $script:PathMap -RepoRoot $script:RepoRoot).policyStatus "blocked"
        }
    }

    It "allows explicit portable executables under managed roots" {
        $item = [pscustomobject]@{
            id = "portable"
            type = "process"
            value = '${ToolRoot}\portable\App.exe'
            scope = "portable"
            reason = "portable executable"
            required = $false
            failurePolicy = "manual"
        }

        $result = Test-KitDefenderExclusionPolicy -Exclusion $item -PathMap $script:PathMap -RepoRoot $script:RepoRoot

        Assert-KitEqual $result.policyStatus "allowed"
        Assert-KitMatch $result.resolvedValue "portable\\App.exe"
    }

    It "blocks generic process exclusions" {
        foreach ($name in @("powershell.exe", "pwsh.exe", "cmd.exe", "msiexec.exe", "setup.exe", "python.exe", "node.exe")) {
            $item = [pscustomobject]@{
                id = "blocked-process"
                type = "process"
                value = (Join-Path $script:PathMap.ToolRoot $name)
                scope = "blocked-process"
                reason = "generic process"
                required = $false
                failurePolicy = "manual"
            }

            Assert-KitEqual (Test-KitDefenderExclusionPolicy -Exclusion $item -PathMap $script:PathMap -RepoRoot $script:RepoRoot).policyStatus "blocked"
        }
    }

    It "rejects extension type and missing reason or scope" {
        $extension = [pscustomobject]@{
            id = "extension"
            type = "extension"
            value = ".zip"
            scope = "extension"
            reason = "extension"
            required = $false
            failurePolicy = "manual"
        }
        $missingReason = [pscustomobject]@{
            id = "missing-reason"
            type = "path"
            value = '${WorkRoot}\cache'
            scope = ""
            reason = ""
            required = $false
            failurePolicy = "manual"
        }

        Assert-KitEqual (Test-KitDefenderExclusionPolicy -Exclusion $extension -PathMap $script:PathMap -RepoRoot $script:RepoRoot).policyStatus "blocked"
        Assert-KitEqual (Test-KitDefenderExclusionPolicy -Exclusion $missingReason -PathMap $script:PathMap -RepoRoot $script:RepoRoot).policyStatus "blocked"
    }

    It "keeps required and failurePolicy as report semantics rather than bypassing policy" {
        $item = [pscustomobject]@{
            id = "required-blocked"
            type = "path"
            value = "C:\"
            scope = "blocked"
            reason = "blocked"
            required = $true
            failurePolicy = "fail"
        }

        $result = Test-KitDefenderExclusionPolicy -Exclusion $item -PathMap $script:PathMap -RepoRoot $script:RepoRoot

        Assert-KitEqual $result.policyStatus "blocked"
        Assert-KitEqual $result.required $true
        Assert-KitEqual $result.failurePolicy "fail"
    }
}
