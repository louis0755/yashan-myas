# 步骤 6：提交、Tag 和 GitHub Release

## 前置条件

- 步骤 5 为 `PASS`；
- 用户已明确授权提交和推送；
- 已确认远端仓库和发布分支。

没有推送授权时，可以准备命令和 Release notes，但状态应为 `BLOCKED`。

## 提交

```bash
MYAS_VERSION=$(<myas/VERSION)
git diff --check
git status --short
git add myas/VERSION myas/CHANGELOG.md myas/docs/RELEASE.md myas/docs/
git diff --cached --check
git diff --cached --stat
git commit -m "Release myas ${MYAS_VERSION}"
```

不得使用 `git add .`，避免把 `myas/.release/`、`myas/dist/`、日志或其他用户文件带入提交。

## Tag 和推送

```bash
git tag -a "v${MYAS_VERSION}" -m "myas ${MYAS_VERSION}"
git push origin HEAD
git push origin "v${MYAS_VERSION}"
```

若推送失败，保留本地提交和 tag，先查明原因；不得删除或强制覆盖远端 tag。

## 创建 Release

先准备 `/tmp/myas-release-notes.md`，包含：

- 主要新增、变更和修复；
- 兼容性与升级注意事项；
- 内置 yinstall 版本；
- 测试报告结论；
- 已知限制。

```bash
gh release create "v${MYAS_VERSION}" \
  "myas/dist/myas-${MYAS_VERSION}.tar.gz" \
  "myas/dist/myas-${MYAS_VERSION}.tar.gz.sha256" \
  --title "myas ${MYAS_VERSION}" \
  --notes-file /tmp/myas-release-notes.md
```

只上传保留密码占位符的公开包。

## 发布日志（HTML）

每次 release 除 GitHub Release 的 markdown notes 外，必须同时输出一份**自包含 HTML 版
发布日志**，保存为 `myas/dist/myas-${MYAS_VERSION}-release-notes.html`（`dist/` 已在
`.gitignore` 内）。要求：

- 单文件、内联样式，不引用外部资源，可直接用浏览器打开或打印；
- 内容包含：发布概要（版本、日期、发布状态、公开包与 SHA256、仓库、提交与部署状态）、
  新特性与修复、测试结果（自动化门禁、发布环境包矩阵、参数覆盖、实例级验证、清理与恢复）、
  已知问题与阻塞、升级与兼容性、结论与后续、本次改动文件清单；
- 测试结果必须与 `release-test-report.md` 的当次记录一致，结论不是 `PASS` 时在概要中
  显著标注为候选版本；
- 不得包含密码、密钥、主机清单以外的敏感信息。

示例见 `myas/dist/myas-0.3.20-release-notes.html`（2026-10-13 复测，结论 `PARTIAL`）。

## 完成条件

提交和 tag 已推送，GitHub Release 可访问，Release 资产的 SHA256 与本地一致。
