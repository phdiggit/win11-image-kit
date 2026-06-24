#Requires -Version 5.1

. "$PSScriptRoot\Resolve-KitPath.ps1"

function Test-KitPackageHasTestCommand {
    param(
        [AllowNull()]
        $Package
    )

    return (
        $null -ne $Package -and
        $null -ne $Package.PSObject -and
        $null -ne $Package.PSObject.Properties["testCommand"] -and
        $null -ne $Package.testCommand
    )
}

function Get-KitPackageTestCommandSuccessExitCodes {
    param(
        [Parameter(Mandatory)]
        $TestCommand
    )

    if ($null -eq $TestCommand.PSObject.Properties["successExitCodes"] -or $null -eq $TestCommand.successExitCodes) {
        return @(0)
    }

    $codes = @()
    foreach ($exitCode in @($TestCommand.successExitCodes)) {
        $codes += [int]$exitCode
    }

    if ($codes.Count -eq 0) {
        throw "testCommand successExitCodes cannot be empty"
    }

    return $codes
}

function Resolve-KitPackageTestCommandConfig {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        [hashtable]$PathMap
    )

    if (-not (Test-KitPackageHasTestCommand -Package $Package)) {
        return $null
    }

    $testCommand = $Package.testCommand
    $command = Resolve-KitPath -Path ([string]$testCommand.command) -PathMap $PathMap
    if ([string]::IsNullOrWhiteSpace($command)) {
        throw "testCommand command is required: $($Package.name)"
    }

    $arguments = @()
    if ($null -ne $testCommand.PSObject.Properties["arguments"] -and $null -ne $testCommand.arguments) {
        foreach ($argument in @($testCommand.arguments)) {
            $arguments += Resolve-KitPath -Path ([string]$argument) -PathMap $PathMap
        }
    }

    $timeoutSeconds = 60
    if ($null -ne $testCommand.PSObject.Properties["timeoutSeconds"] -and $null -ne $testCommand.timeoutSeconds) {
        $timeoutSeconds = [int]$testCommand.timeoutSeconds
    }

    if ($timeoutSeconds -le 0) {
        throw "testCommand timeoutSeconds must be greater than 0: $($Package.name)"
    }

    [pscustomobject]@{
        command = $command
        arguments = @($arguments)
        successExitCodes = @(Get-KitPackageTestCommandSuccessExitCodes -TestCommand $testCommand)
        timeoutSeconds = $timeoutSeconds
    }
}

function New-KitPackageTestCommandResultObject {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("success", "failed", "skipped", "manual", "notRun")]
        [string]$Status,

        [AllowEmptyString()]
        [string]$Command,

        [string[]]$Arguments = @(),

        [AllowNull()]
        [Nullable[int]]$ExitCode = $null,

        [int[]]$SuccessExitCodes = @(0),

        [long]$DurationMs = 0,

        [AllowEmptyString()]
        [string]$Error,

        [AllowEmptyString()]
        [string]$Reason
    )

    [pscustomobject][ordered]@{
        status = $Status
        command = $Command
        arguments = @($Arguments)
        exitCode = $ExitCode
        successExitCodes = @($SuccessExitCodes)
        durationMs = [long]$DurationMs
        error = $Error
        reason = $Reason
    }
}

function New-KitPackageTestCommandNotRun {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        [hashtable]$PathMap,

        [Parameter(Mandatory)]
        [string]$Reason
    )

    if (-not (Test-KitPackageHasTestCommand -Package $Package)) {
        return $null
    }

    try {
        $config = Resolve-KitPackageTestCommandConfig -Package $Package -PathMap $PathMap
        return New-KitPackageTestCommandResultObject `
            -Status "notRun" `
            -Command ([string]$config.command) `
            -Arguments @($config.arguments) `
            -SuccessExitCodes @($config.successExitCodes) `
            -Reason $Reason
    } catch {
        return New-KitPackageTestCommandResultObject `
            -Status "notRun" `
            -Command "" `
            -Arguments @() `
            -SuccessExitCodes @(0) `
            -Error $_.Exception.Message `
            -Reason $Reason
    }
}

function Get-KitPackageTestCommandFailureAction {
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        $Policy
    )

    if ([bool]$Policy.required) {
        return "fail"
    }

    $failurePolicy = [string]$Policy.failurePolicy
    if ((Test-KitPackageHasTestCommand -Package $Package) -and
        $null -ne $Package.testCommand.PSObject.Properties["failurePolicy"] -and
        -not [string]::IsNullOrWhiteSpace([string]$Package.testCommand.failurePolicy)) {
        $failurePolicy = [string]$Package.testCommand.failurePolicy
    }

    if ($failurePolicy -eq "manual") {
        return "manual"
    }

    if ($failurePolicy -eq "skip") {
        return "skip"
    }

    return "fail"
}

function Invoke-KitPackageTestCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Package,

        [Parameter(Mandatory)]
        [hashtable]$PathMap,

        [AllowNull()]
        [scriptblock]$Invoker = $null
    )

    if (-not (Test-KitPackageHasTestCommand -Package $Package)) {
        return $null
    }

    $started = Get-Date
    $config = $null
    try {
        $config = Resolve-KitPackageTestCommandConfig -Package $Package -PathMap $PathMap
        if ($null -ne $Invoker) {
            $invokeResult = & $Invoker -Command ([string]$config.command) -Arguments @($config.arguments) -TimeoutSeconds ([int]$config.timeoutSeconds)
            $exitCode = [int]$invokeResult.ExitCode
        } else {
            $startArgs = @{
                FilePath = [string]$config.command
                PassThru = $true
                WindowStyle = "Hidden"
            }
            if (@($config.arguments).Count -gt 0) {
                $startArgs["ArgumentList"] = @($config.arguments)
            }

            $process = Start-Process @startArgs
            $completed = $process.WaitForExit(([int]$config.timeoutSeconds) * 1000)
            if (-not $completed) {
                try {
                    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                } catch {
                    # best effort cleanup for timed out test command
                }

                return New-KitPackageTestCommandResultObject `
                    -Status "failed" `
                    -Command ([string]$config.command) `
                    -Arguments @($config.arguments) `
                    -SuccessExitCodes @($config.successExitCodes) `
                    -DurationMs ([long]((Get-Date) - $started).TotalMilliseconds) `
                    -Error "testCommand timed out after $($config.timeoutSeconds) seconds" `
                    -Reason "timeout"
            }

            $exitCode = [int]$process.ExitCode
        }

        $status = if (@($config.successExitCodes) -contains $exitCode) { "success" } else { "failed" }
        $reason = if ($status -eq "success") { "completed" } else { "unexpected-exit-code" }
        $error = if ($status -eq "success") { "" } else { "testCommand exit code $exitCode is not in successExitCodes: $(@($config.successExitCodes) -join ', ')" }

        return New-KitPackageTestCommandResultObject `
            -Status $status `
            -Command ([string]$config.command) `
            -Arguments @($config.arguments) `
            -ExitCode $exitCode `
            -SuccessExitCodes @($config.successExitCodes) `
            -DurationMs ([long]((Get-Date) - $started).TotalMilliseconds) `
            -Error $error `
            -Reason $reason
    } catch {
        $command = ""
        $arguments = @()
        $successExitCodes = @(0)
        if ($null -ne $config) {
            $command = [string]$config.command
            $arguments = @($config.arguments)
            $successExitCodes = @($config.successExitCodes)
        }

        return New-KitPackageTestCommandResultObject `
            -Status "failed" `
            -Command $command `
            -Arguments @($arguments) `
            -SuccessExitCodes @($successExitCodes) `
            -DurationMs ([long]((Get-Date) - $started).TotalMilliseconds) `
            -Error $_.Exception.Message `
            -Reason "exception"
    }
}
