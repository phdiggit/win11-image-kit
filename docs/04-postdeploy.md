# 部署后恢复

目标：新机还原后，除账号登录和授权激活外，其余配置尽量自动完成。

## 执行时机

OOBE 完成、进入桌面、网络可用、Windows 初始驱动安装稳定后执行。

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\scripts\postdeploy\Invoke-PostDeploy.ps1
```

## 自动恢复内容

- D 盘数据重定向
- 默认应用关联
- Windows Terminal 配置
- VSCode 便携配置检查
- 开始菜单固定项
- 数据库/中间件服务注册
- 常用工具 PATH 验证
- 部署日志写入 NAS

## 人工清单

- 登录 Chrome
- 登录 VSCode Settings Sync
- 登录 JetBrains 账号或重新激活
- 登录微信、QQ、Telegram、网盘
- Tailscale 重新认证
- 需要时安装 Visual Studio、VMware Workstation、Adobe 系列
