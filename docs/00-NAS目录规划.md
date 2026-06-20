# NAS 目录规划

项目根目录：

```text
\\192.168.1.37\backups\win11-image-kit
```

Linux 路径：

```text
/data2/backups/win11-image-kit
```

SSD 临时工作区：

```text
\\192.168.1.37\data1\work\win11-image-kit
```

## 磁盘分工

| 磁盘 | 挂载点 | 用途 |
|---|---|---|
| 1T SSD | `/data1` | 临时工作区、解压、挂载、暂存 |
| 3T HDD | `/data2` | 项目资产、安装包、配置、镜像、日志 |

`/data2/images` 和 `/data2/videos` 是图片/视频媒体库，本项目不使用也不改动。

## 最终目录结构

```text
\\192.168.1.37\backups\win11-image-kit\
  docs\
    legacy\
  scripts\
    legacy\
  configs\
    default-apps\
    jetbrains\
    maven\
    middleware\
    opencode\
    start-menu\
    vscode\
    windows-terminal\
  hardware\
    air15\
      reports\
    future-pc\
      drivers\
      reports\
    main-pc\
      reports\
  images\
    pe\
    win11\
      source-iso\
      golden\
      test\
      archive\
  packages\
    cloud-tools\
    daily-tools\
    database-tools\
    fonts\
      jetbrains-mono\
    ide\
    jdk\
    maven\
    media-tools\
    middleware\
    miniconda\
    network-tools\
    nodejs\
    remote-tools\
    runtime\
    system-tools\
    vscode\
  deploy\
    scripts\
    manifests\
    logs\
      golden-vm\
      air15\
      future-pc\
    reports\
      preflight\
      postdeploy\
      tests\
```

```text
\\192.168.1.37\data1\work\win11-image-kit\
  staging\
  temp\
  mount\
  scratch\
```

## 资产管理原则

- Git 保存源代码性质的内容：文档、脚本、manifest、schema。
- NAS 保存大体积载荷：安装包、压缩包、WIM/ISO、导出的软件配置、日志。
- 本项目自动化脚本优先读取上面的英文项目根目录。
- 旧中文目录可以作为历史来源保留，但新脚本和新文档尽量引用英文项目根目录。
- 不在项目根目录保存授权文件、私钥、token 或破解/绕授权工具。

## 路径变量

```powershell
$NasProjectRoot = "\\192.168.1.37\backups\win11-image-kit"
$ConfigRoot = "$NasProjectRoot\configs"
$PackageRoot = "$NasProjectRoot\packages"
$ImageRoot = "$NasProjectRoot\images\win11"
$DeployRoot = "$NasProjectRoot\deploy"
$WorkRoot = "\\192.168.1.37\data1\work\win11-image-kit"
```

## 当前已归集资产

初次归集已把旧 NAS 结构中与本项目相关的资产复制到英文项目根目录，包括：

- 旧版迁移文档和辅助脚本
- VSCode、Windows Terminal、Maven、JetBrains、开始菜单、默认应用关联配置
- 联想小新 Air15 硬件报告
- Windows PE ISO、Windows 原版 ISO、初版 WIM
- JDK、Maven、Node.js、Miniconda、VSCode 安装包/压缩包
- 数据库和中间件压缩包
- 常用日常、远程、网络、网盘、媒体、IDE、运行库和系统工具

明确跳过：

- 破解或绕授权工具
- Adobe、Visual Studio、VMware 这类应作为还原后手工安装流程的大型软件

## 日常下载池和旧 packages 目录

`\\192.168.1.37\data1\下载` 是日常下载池，用来临时保存从网上下载的安装包、压缩包、视频音频等文件。进入本项目自动化前，应把确认可信、需要复用的安装介质归集到 `\\192.168.1.37\backups\win11-image-kit\packages`。

`\\192.168.1.37\data1\work\win11-image-kit` 是 SSD 临时工作区，用于解压、挂载、测试和暂存，不作为长期归档位置。

早期规划里曾经出现过 `\\192.168.1.37\backups\packages`。现在本项目已经切换为英文自包含根目录，因此该目录不再承担本项目职责；确认没有其它用途后，可以手工清理或保留为空目录。
