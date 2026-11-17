# 发布到 GitHub

本地项目已经包含 `.gitignore`、MIT 许可证和 GitHub Actions 检查，不需要在 GitHub 创建仓库时再次初始化这些文件。

1. 在自己的 GitHub 账户下创建空仓库，建议名称 `wsl-ubuntu-xfce-guide`。
2. 想方便其他用户与 AI 使用，可以选 Public。项目内容应先经过脱敏检查。
3. 不勾选 Add a README、Add .gitignore、Choose a license。
4. 通过正常登录的 Git 客户端推送：

```powershell
git remote add origin https://github.com/YOUR_ACCOUNT/wsl-ubuntu-xfce-guide.git
git push -u origin main
```

不要把访问令牌写进远程 URL、脚本、README 或聊天中。让 Git 凭据管理器执行正常登录即可。

如果由 AI 通过 GitHub 连接器上传，应先确认目标仓库为空、当前默认分支和已连接账户，再创建完整文件树并提交。已有文件的仓库需要另行评估，不能用本项目直接覆盖根目录。GitHub Actions 的远程结果与本地检查结果分别报告。
