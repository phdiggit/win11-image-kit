Describe "Issue 14 CI policy" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:Workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8
    }

    It "keeps PR Validate and non-PR Full Validate split" {
        Assert-KitMatch $script:Workflow "pull_request:"
        Assert-KitMatch $script:Workflow "workflow_dispatch:"
        Assert-KitMatch $script:Workflow "push:"
        Assert-KitMatch $script:Workflow "name:\s+Validate"
        Assert-KitMatch $script:Workflow "if:\s*github\.event_name == 'pull_request'"
        Assert-KitMatch $script:Workflow "name:\s+Full Validate"
        Assert-KitMatch $script:Workflow "if:\s*github\.event_name != 'pull_request'"
    }

    It "keeps PR fast path static, fixture, and report-only" {
        foreach ($term in @(
            "Run JSON parse check with Windows PowerShell",
            "Run PowerShell parse check with Windows PowerShell",
            "Run project config validation with Windows PowerShell",
            "Run PSScriptAnalyzer with Windows PowerShell",
            "Run fast Pester tests with Windows PowerShell"
        )) {
            Assert-KitMatch $script:Workflow ([regex]::Escape($term))
        }

        foreach ($pattern in @(
            "Invoke-GoldenImageBuild",
            "\bdism(\.exe)?\b",
            "\bsysprep(\.exe)?\b",
            "winget\s+(install|uninstall|upgrade)",
            "choco\s+(install|uninstall|upgrade)",
            "msiexec\s+/(i|x)",
            "\bInstall-Package\b",
            "\bUninstall-Package\b",
            "\bSet-Service\b",
            "\bStart-Service\b",
            "\bStop-Service\b",
            "sc\.exe\s+(config|delete|stop|start)",
            "Invoke-WebRequest",
            "Invoke-RestMethod",
            "Start-BitsTransfer",
            "\breg\s+(load|unload|add|delete)",
            "\bSet-ItemProperty\b",
            "\bNew-ItemProperty\b",
            "Install-Module"
        )) {
            Assert-KitNotMatch $script:Workflow $pattern
        }
    }

    It "documents CI split in Issue 14 runbook" {
        $doc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\40-issue14-quality-gates.md") -Raw -Encoding UTF8

        foreach ($term in @(
            'The PR gate is the `Validate` job',
            "runs only when ``github.event_name == 'pull_request'``",
            'The heavier validation job is `Full Validate`',
            "runs only when ``github.event_name != 'pull_request'``",
            'Full Validate` being skipped on pull requests is expected'
        )) {
            Assert-KitMatch $doc ([regex]::Escape($term))
        }
    }
}
