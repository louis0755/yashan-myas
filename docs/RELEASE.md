# 版本发布流程

分步骤操作手册位于 [`myas/docs/release/`](myas/docs/README.md)。后续维护人员和智能体应按
该目录中的编号顺序执行；本文保留发布流程总览。

本文规定 `myas` 组合版本的发布门禁、打包、验证、部署和回滚流程。组合包包含
`myas` 和内置 `yinstall`，但两者独立维护版本：

- `myas/VERSION`：myas 版本，例如 `0.3.7`；
- `yinstall/VERSION`：内置 yinstall 版本，例如 `0.4.6`；
- 发布包使用 myas 版本命名：`myas-<version>.tar.gz`。

版本号使用 `MAJOR.MINOR.PATCH` 三段数字格式。不兼容变更递增 `MAJOR`，
向后兼容功能递增 `MINOR`，问题修复递增 `PATCH`。

## 1. 文档分工

| 文档 | 用途 |
| --- | --- |
| `myas/CHANGELOG.md` | 记录各版本用户可见变更 |
| `myas/docs/release-test.md` | 正式发布前的测试标准 |
| `myas/docs/release-test-report.md` | 当次发布测试结果和未通过项 |
| `myas/docs/TESTING.md` | 日常静态检查、CLI 测试和单机验证 |
| `myas/docs/DEPLOYMENT.md` | 用户安装、配置和升级 |
| `ISSUES.md`、`myas/ISSUES.md` | 已知问题和问题编号 |

正式发布以测试报告为准。报告为 `FAIL` 或 `PARTIAL` 时，不得创建正式
GitHub Release；候选包必须明确标记为非正式版本。

## 2. 发布前准备

在仓库根目录检查工作区和当前版本：

```bash
cd /home/ganlu/ai/myas
git status --short
cat myas/VERSION
cat yinstall/VERSION
```

发布负责人需要确认：

1. 计划发布的代码均已提交，没有来源不明的修改；
2. `myas/CHANGELOG.md` 已增加新版本、日期和变更分类；
3. yinstall 有变更时，其版本和变更记录已同步更新；
4. README、部署文档和命令帮助与新版本行为一致；
5. 仓库中没有密码、SSH key、数据库包、日志或实例状态。

后续命令统一使用版本变量：

```bash
MYAS_VERSION=0.3.8
YINSTALL_VERSION=$(<yinstall/VERSION)
```

## 3. 发布门禁

### 3.1 静态检查和自动化测试

```bash
bash -n myas/myas.sh myas/lib/*.sh myas/tests/*.sh
bash -n yinstall/yinstall.sh yinstall/lib/*.sh \
  yinstall/steps/*.sh yinstall/tests/*.sh
bash myas/tests/test_cli.sh
bash yinstall/tests/test_cli.sh
bash yinstall/tests/test_ports.sh
```

所有命令必须返回 `0`。出现失败时，修复后重新执行完整门禁。

### 3.2 发布环境测试

按照 `myas/docs/release-test.md` 执行适用于本次变更的测试矩阵，并更新
`myas/docs/release-test-report.md`。至少记录：

- myas 和 yinstall 版本、提交 ID；
- 测试主机、操作系统和架构；
- YashanDB 包完整名称及 SHA256；
- 实例、端口、测试结果和失败现场；
- 自动化测试命令及结果；
- 最终结论 `PASS`、`PARTIAL` 或 `FAIL`。

正式发布要求结论为 `PASS`。涉及安装、端口、主备、架构识别或生命周期的变更，
必须执行相应的真实主机验证。

## 4. 更新版本并生成公开包

更新版本文件：

```bash
printf '%s\n' "${MYAS_VERSION}" > myas/VERSION
```

使用不含现场密码的打包脚本生成公开发布包：

```bash
rm -f -- "myas/dist/myas-${MYAS_VERSION}.tar.gz"
myas/tools/package.sh dist
sha256sum "myas/dist/myas-${MYAS_VERSION}.tar.gz" \
  | tee "myas/dist/myas-${MYAS_VERSION}.tar.gz.sha256"
```

`myas/tools/package.sh` 会组合 myas 与内置 yinstall，排除测试目录和 Git 元数据，并
检查包内仍保留密码占位符 `__MYAS_SYS_PASSWORD__`。

检查包内容和两个组件的版本：

```bash
tar -tzf "myas/dist/myas-${MYAS_VERSION}.tar.gz"
tar -xOzf "myas/dist/myas-${MYAS_VERSION}.tar.gz" \
  "myas-${MYAS_VERSION}/VERSION"
tar -xOzf "myas/dist/myas-${MYAS_VERSION}.tar.gz" \
  "myas-${MYAS_VERSION}/yinstall/VERSION"
```

GitHub Release 只能上传这个保留密码占位符的公开包，不得上传经过密码替换的现场包。

## 5. 本地冒烟验证

在临时目录解包，并隔离 `MYAS_CONFIG_DIR`：

```bash
RELEASE_TMP=$(mktemp -d)
tar -xzf "myas/dist/myas-${MYAS_VERSION}.tar.gz" -C "${RELEASE_TMP}"
MYAS_CONFIG_DIR="${RELEASE_TMP}/config" \
  "${RELEASE_TMP}/myas-${MYAS_VERSION}/myas.sh" --version
MYAS_CONFIG_DIR="${RELEASE_TMP}/config" \
  "${RELEASE_TMP}/myas-${MYAS_VERSION}/myas.sh" list
"${RELEASE_TMP}/myas-${MYAS_VERSION}/yinstall/yinstall.sh" --help
rm -rf -- "${RELEASE_TMP}"
```

预期 myas 版本正确，`list` 和 `yinstall --help` 均正常返回。

## 6. 提交、标签和 GitHub Release

提交中不得包含 `myas/dist/`、日志、数据库包或 `myas/.release/` 中的凭据：

```bash
git diff --check
git status --short
git add myas/VERSION myas/CHANGELOG.md myas/docs/RELEASE.md
git commit -m "Release myas ${MYAS_VERSION}"
git tag -a "v${MYAS_VERSION}" -m "myas ${MYAS_VERSION}"
git push origin HEAD
git push origin "v${MYAS_VERSION}"
```

推送前确认 `origin` 指向预期仓库。随后上传公开包和校验文件：

```bash
gh release create "v${MYAS_VERSION}" \
  "myas/dist/myas-${MYAS_VERSION}.tar.gz" \
  "myas/dist/myas-${MYAS_VERSION}.tar.gz.sha256" \
  --title "myas ${MYAS_VERSION}" \
  --notes-file /tmp/myas-release-notes.md
```

Release notes 应包含主要变更、升级注意事项、内置 yinstall 版本、测试结论及已知
限制。独立发布 yinstall 时，在其仓库单独更新版本、测试、打 tag 和创建 Release。

## 7. 现场部署

公开发布与现场部署是两个步骤。现场需要预置默认密码时，使用权限为 `600` 的
本地文件：

```bash
install -m 600 /dev/null myas/.release/myas.env
```

文件内容如下，禁止提交到 Git：

```bash
MYAS_DEFAULT_PASSWORD='替换为现场密码'
```

确认目标主机后执行：

```bash
PUBLISH_HOST=192.168.23.4 \
PUBLISH_USER=yashan \
PUBLISH_DIR=/tmp \
myas/tools/release.sh "${MYAS_VERSION}"
```

`myas/tools/release.sh` 不是单纯的打包命令。它会更新 `myas/VERSION`、生成公开包、
在临时副本中注入现场密码、上传并切换目标机版本，随后执行版本检查，并删除同名
`psftdb` 登记后运行 `myas create psftdb 23.4.14.105 --force`。

因此该脚本只允许在确认可创建或重建 `psftdb` 的测试或交付主机执行。含现场密码
的部署包不得上传 GitHub、发送到无关主机或长期留在公共目录。生产环境建议部署公开
包，再通过 `myas config set SYS_PASSWORD` 在目标机注入密码。

## 8. 发布后验证

在目标主机执行：

```bash
myas --version
myas config show
myas list
"$HOME/.local/opt/myas/current/yinstall/yinstall.sh" --version
```

进行了真实实例部署时还应执行：

```bash
myas info CLUSTER
myas status CLUSTER
yasboot cluster status -c CLUSTER -d
```

发布记录应保存 commit、tag、Release 地址、两个组件版本、公开包 SHA256、测试报告
和部署验证结果。输出中的密码、密钥和现场路径必须脱敏。

## 9. 回滚

myas 使用版本目录和 `current` 软链接。回滚只切换到已验证的旧目录，
`~/.myas/` 中的配置和实例登记默认保留：

```bash
PREVIOUS_VERSION=0.3.7
test -x "$HOME/.local/opt/myas/myas-${PREVIOUS_VERSION}/myas.sh"
ln -sfn "$HOME/.local/opt/myas/myas-${PREVIOUS_VERSION}" \
  "$HOME/.local/opt/myas/current"
hash -r
myas --version
myas list
```

回滚前备份 `~/.myas/settings.conf` 和 `~/.myas/instances.tsv`。若新版本修改了
配置格式，先确认旧版本可以读取；不得为回滚工具版本而直接删除数据库目录。

## 10. 发布检查清单

- [ ] myas、yinstall 版本和变更记录已确认
- [ ] 仓库不包含凭据、数据库包、日志和机器状态
- [ ] Bash 静态检查和全部 CLI 测试通过
- [ ] 发布测试报告结论为 `PASS`
- [ ] 公开包保留密码占位符且内容检查通过
- [ ] SHA256 文件已生成并复核
- [ ] 本地解包冒烟验证通过
- [ ] 发布提交和 `v<version>` tag 已推送
- [ ] GitHub Release 已上传公开包和 SHA256
- [ ] 目标环境验证完成，结果已脱敏归档
- [ ] 回滚版本和回滚命令已确认
