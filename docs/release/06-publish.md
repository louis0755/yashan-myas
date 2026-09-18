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

## 完成条件

提交和 tag 已推送，GitHub Release 可访问，Release 资产的 SHA256 与本地一致。
