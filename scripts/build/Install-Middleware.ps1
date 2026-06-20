#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"

Write-KitLog "待实现：解压 MySQL、MongoDB、Redis、Kafka、RocketMQ、Elasticsearch、Nacos"
Write-KitLog "注意：金镜像中尽量不要长期启动服务；如启动过，Sysprep 前必须清理。" "WARN"
