# NAS Directory Plan

Project root:

```text
\\192.168.1.37\backups\win11-image-kit
```

Linux path:

```text
/data2/backups/win11-image-kit
```

Fast workspace:

```text
\\192.168.1.37\data1\work\win11-image-kit
```

## Disk Roles

| Disk | Mount | Role |
|---|---|---|
| 1T SSD | `/data1` | temporary work, staging, mount, scratch |
| 3T HDD | `/data2` | project assets, packages, configs, images, logs |

`/data2/images` and `/data2/videos` are media libraries and are not used by this project.

## Final Layout

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

## Asset Policy

- Git stores source: docs, scripts, manifests, schemas.
- NAS stores payloads: installers, archives, WIM/ISO files, exported configs, logs.
- Project automation should read from the English project root above.
- Legacy Chinese folders may remain as historical sources, but new project references should prefer the English root.
- Do not store license files, private keys, tokens, or crack tools in the project root.

## Path Variables

```powershell
$NasProjectRoot = "\\192.168.1.37\backups\win11-image-kit"
$ConfigRoot = "$NasProjectRoot\configs"
$PackageRoot = "$NasProjectRoot\packages"
$ImageRoot = "$NasProjectRoot\images\win11"
$DeployRoot = "$NasProjectRoot\deploy"
$WorkRoot = "\\192.168.1.37\data1\work\win11-image-kit"
```

## Current Staged Assets

The initial staging copied project-related assets from the previous NAS layout into the English project root, including:

- Legacy migration document and helper scripts
- VSCode, Windows Terminal, Maven, JetBrains, start menu, default app association configs
- Lenovo XiaoXin Air15 hardware report
- Windows PE ISO, Windows source ISO, initial WIM
- JDK, Maven, Node.js, Miniconda, VSCode packages
- Database and middleware archives
- Common daily, remote, network, cloud, media, IDE, runtime, and system tools

Explicitly skipped:

- Crack or license-bypass tools
- Adobe, Visual Studio, VMware payloads that should remain manual/post-install workflows
