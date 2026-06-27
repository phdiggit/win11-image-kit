Describe "User experience restore validation runner" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-user-experience-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null

        $script:InvokeUxProcess = {
            param(
                [Parameter(Mandatory)]
                [string]$ReportPath,

                [string]$ExtraArguments = ""
            )

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:RepoRoot\scripts\validate\Test-UserExperienceRestore.ps1`" -ReportPath `"$ReportPath`" $ExtraArguments"
            $psi.WorkingDirectory = $script:RepoRoot
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $process = [System.Diagnostics.Process]::Start($psi)
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()

            [pscustomobject]@{
                exitCode = $process.ExitCode
                stdout = $stdout
                stderr = $stderr
            }
        }
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "passes the baseline fixture set" {
        $reportPath = Join-Path $script:TempRoot "ux-report.json"
        $process = & $script:InvokeUxProcess -ReportPath $reportPath
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $process.exitCode 0
        Assert-KitEqual $report.status "passed"
        Assert-KitMatch $process.stdout "User experience restore report written"
    }

    It "fails blocked and unsupported fixture cases" {
        $cases = @(
            @{ Name = "unsupported"; Args = "-WindowsContextPath `"tests\fixtures\user-experience\windows-context\unsupported-build.json`""; Count = "unsupportedVersionCount" },
            @{ Name = "missing-build"; Args = "-WindowsContextPath `"tests\fixtures\user-experience\windows-context\missing-build.json`""; Count = "missingBuildCount" },
            @{ Name = "mutation"; Args = "-DefaultAppsPath `"tests\fixtures\user-experience\default-apps\mutation-request.json`""; Count = "blockedCount" },
            @{ Name = "unknown"; Args = "-DefaultAppsPath `"tests\fixtures\user-experience\default-apps\unknown-progid.json`""; Count = "missingCapabilityCount" },
            @{ Name = "profile-write"; Args = "-StartMenuPath `"tests\fixtures\user-experience\start-menu\profile-write-request.json`""; Count = "blockedCount" },
            @{ Name = "registry-write"; Args = "-TaskbarPath `"tests\fixtures\user-experience\taskbar\registry-write-request.json`""; Count = "blockedCount" },
            @{ Name = "private-path"; Args = "-LocalPrivatePath `"tests\fixtures\user-experience\local-private-path.json`""; Count = "localPrivatePathCount" },
            @{ Name = "unsupported-capability"; Args = "-CapabilityMatrixPath `"tests\fixtures\user-experience\capability-matrix\unsupported-feature.json`""; Count = "unsupportedCapabilityCount" },
            @{ Name = "scope-mismatch"; Args = "-TemplateMetadataPath `"tests\fixtures\user-experience\template-metadata\scope-mismatch.json`""; Count = "scopeMismatchCount" },
            @{ Name = "template-failure"; Args = "-TemplateMetadataPath `"tests\fixtures\user-experience\template-metadata\missing-source-build.json`""; Count = "templateMetadataFailureCount" },
            @{ Name = "verification-exit-code"; Args = "-VerificationPlanPath `"tests\fixtures\user-experience\verification\exit-code-claims-success.json`""; Count = "exitCodeOnlySuccessClaimCount" },
            @{ Name = "verification-user-config"; Args = "-VerificationPlanPath `"tests\fixtures\user-experience\verification\user-config-confirmed-without-real-evidence.json`""; Count = "userConfigurationFalseClaimCount" },
            @{ Name = "scope-claim"; Args = "-ScopeSemanticsPath `"tests\fixtures\user-experience\scope-semantics\default-profile-claims-current-user.json`""; Count = "scopeMismatchCount" }
        )

        foreach ($case in $cases) {
            $reportPath = Join-Path $script:TempRoot ("{0}.json" -f $case.Name)
            $process = & $script:InvokeUxProcess -ReportPath $reportPath -ExtraArguments $case.Args
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

            Assert-KitEqual $process.exitCode 1
            Assert-KitEqual $report.status "failed"
            if ($report.summary.($case.Count) -lt 1) {
                throw "Expected $($case.Count) to be greater than zero."
            }
            Assert-KitEqual $report.trueExecution $false
        }
    }
}
