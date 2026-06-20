# Packages

这里不提交大型安装包、压缩包、商业软件包、授权文件或个人凭据。

实际安装介质统一放在 NAS：

```text
\\192.168.1.37\backups\win11-image-kit\packages
```

仓库里只记录包名、版本、来源路径和 SHA256 校验信息。这样 Git 保持轻量，真正的大文件由 NAS 承担。
