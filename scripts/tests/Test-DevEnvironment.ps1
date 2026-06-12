$ErrorActionPreference = "Continue"
. "$PSScriptRoot\..\common\Write-Log.ps1"

$commands = @(
    "java -version",
    "mvn -v",
    "node -v",
    "npm -v",
    "python --version",
    "git --version"
)

foreach ($command in $commands) {
    Write-KitLog "Testing: $command"
    cmd.exe /c $command
}
