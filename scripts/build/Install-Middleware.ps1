#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"

Write-KitLog "TODO: unpack MySQL, MongoDB, Redis, Kafka, RocketMQ, Elasticsearch, Nacos"
Write-KitLog "Do not start long-lived services in golden image unless they are cleaned before Sysprep." "WARN"
