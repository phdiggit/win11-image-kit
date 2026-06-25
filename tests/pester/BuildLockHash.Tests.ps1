Describe "Build lock hash helper" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitFileHash.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-build-lock-hash-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "creates stable lowercase SHA256 for a fixture file" {
        $fixturePath = Join-Path $script:TempRoot "abc.txt"
        [IO.File]::WriteAllBytes($fixturePath, [byte[]](97, 98, 99))

        $result = Get-KitFileHash -Path $fixturePath -RepoRoot $script:TempRoot

        Assert-KitEqual $result.exists $true
        Assert-KitEqual $result.algorithm "SHA256"
        Assert-KitEqual $result.hash "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        Assert-KitEqual ($result.hash -cmatch '^[a-f0-9]{64}$') $true
        Assert-KitEqual $result.length 3
    }

    It "returns exists false for missing files" {
        $result = Get-KitFileHash -Path "missing.txt" -RepoRoot $script:TempRoot

        Assert-KitEqual $result.exists $false
        Assert-KitEqual $result.hash $null
        Assert-KitEqual $result.path "missing.txt"
    }

    It "does not read directories and does not modify files" {
        $fixturePath = Join-Path $script:TempRoot "stable.txt"
        [IO.File]::WriteAllBytes($fixturePath, [byte[]](115, 116, 97, 98, 108, 101))
        $before = Get-Item -LiteralPath $fixturePath
        $beforeWriteTime = $before.LastWriteTimeUtc
        $beforeLength = $before.Length

        Get-KitFileHash -Path $fixturePath -RepoRoot $script:TempRoot | Out-Null
        $after = Get-Item -LiteralPath $fixturePath

        Assert-KitEqual $after.Length $beforeLength
        Assert-KitEqual $after.LastWriteTimeUtc $beforeWriteTime
        Assert-KitThrows -ScriptBlock {
            Get-KitFileHash -Path $script:TempRoot -RepoRoot $script:TempRoot | Out-Null
        } -ExpectedMessage "directory"
    }
}
