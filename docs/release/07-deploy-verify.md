# 步骤 7：目标机部署和验证

## 前置条件

- 用户明确授权目标机部署；
- 目标主机、用户、目录和变更窗口已确认；
- 已准备并验证回滚版本；
- 明确选择公开包部署或现场注密部署。

## 推荐方式：部署公开包

将 GitHub Release 的公开包传到目标机并核对 SHA256。当前根目录
`myas/tools/upgrade.sh` 创建的命令入口与组合包目录结构不一致，在修复并通过测试前
不要使用。按以下命令部署：

```bash
MYAS_VERSION=0.3.8
ARCHIVE="/tmp/myas-${MYAS_VERSION}.tar.gz"
INSTALL_ROOT="$HOME/.local/opt/myas"
test -f "${ARCHIVE}"
tar -xOzf "${ARCHIVE}" "myas-${MYAS_VERSION}/VERSION" \
  | grep -Fx "${MYAS_VERSION}"
mkdir -p -- "${INSTALL_ROOT}" "$HOME/.local/bin"
tar -xzf "${ARCHIVE}" -C "${INSTALL_ROOT}"
ln -sfn -- "${INSTALL_ROOT}/myas-${MYAS_VERSION}" \
  "${INSTALL_ROOT}/current"
ln -sfn -- "${INSTALL_ROOT}/current/myas.sh" "$HOME/.local/bin/myas"
chmod +x -- "${INSTALL_ROOT}/current/myas.sh" \
  "${INSTALL_ROOT}/current/yinstall/yinstall.sh"
hash -r
myas --version
myas config set SYS_PASSWORD '现场密码'
myas config set YINSTALL_BIN \
  "$HOME/.local/opt/myas/current/yinstall/yinstall.sh"
# 实例命令（ysXXXX / ystatus / ystart / yshutdown / yrestart）依赖 .bashrc 加载
# shell-init；缺少这一步时 myas 本身可用，但 ysXXXX 会报“未找到命令”。
if ! grep -q 'myas shell-init' "$HOME/.bashrc"; then
	printf '\n# myas: instance helpers (ysXXXX / ystatus ...)\n[ -x "$HOME/.local/bin/myas" ] && eval "$("$HOME/.local/bin/myas" shell-init)"\n' >>"$HOME/.bashrc"
fi
grep -n 'myas shell-init' "$HOME/.bashrc"
```

命令行中的密码可能进入 shell history。现场应按安全规范使用受控终端或其他安全注入
方式，文档和日志中不得保留真实值。

### shell 环境（实例命令）

`~/.bashrc` 必须让 `PATH` 包含 `$HOME/.local/bin`，并加载
`eval "$(myas shell-init)"`（等价写法
`eval "$("$HOME/.local/opt/myas/current/myas.sh" shell-init)"`）。`shell-init` 定义
`myas` 包装函数，并通过 `myas alias` 加载每个实例的别名：

```text
alias ys1903='source <(myas env ys1903)'
alias ystatus='.../myas.sh status ys1903'   # 同时生成 ystart / yshutdown / yrestart
```

- 这些是 shell 别名，只在**交互式** shell 中展开。非交互调用（`ssh HOST 'ys1903'`、
  脚本、cron）不会生效，应改用 `myas env CLUSTER`、`myas status CLUSTER`。
- `ystatus`、`ystart`、`yshutdown`、`yrestart` 作用于**最近一次激活**的实例，先执行
  `ys1903` 再调用它们。
- 新增实例后由 `myas` 包装函数自动刷新别名；不需要重写 `.bashrc`。
- 改完 `.bashrc` 需要 `source ~/.bashrc` 或重新登录才生效，已经打开的会话不受影响。

## 特殊方式：自动注密并部署

`myas/tools/release.sh` 会注入密码、上传、切换版本，并重建 `psftdb`，只适用于确认
允许该行为的测试或交付主机。

先检查凭据文件，不输出内容：

```bash
test -f myas/.release/myas.env
test "$(stat -c '%a' myas/.release/myas.env)" = 600
```

用户再次确认目标后执行：

```bash
PUBLISH_HOST=192.168.23.4 \
PUBLISH_USER=yashan \
PUBLISH_DIR=/tmp \
myas/tools/release.sh "${MYAS_VERSION}"
```

`release.sh` 只上传、切换版本并设置 `YINSTALL_BIN`，不会写 `~/.bashrc`；shell 环境按
上一节的步骤在目标机单独配置一次。

## 发布后验证

```bash
myas --version
myas config show
myas list
"$HOME/.local/opt/myas/current/yinstall/yinstall.sh" --version
```

部署了实例时继续执行：

```bash
myas info CLUSTER
myas status CLUSTER
yasboot cluster status -c CLUSTER -d
```

并确认实例命令已随 shell 生效（新开一个交互式 shell 后执行）：

```bash
grep -Fq 'myas shell-init' "$HOME/.bashrc" && echo "shell-init 已配置"
myas alias                       # 列出每个实例的 ysXXXX / ystatus 等别名
```

确认版本、软链接、实例登记和数据库状态正确。含现场密码的临时包不得上传 GitHub 或
保留在公共目录。

## 完成条件

目标版本生效，myas 与 yinstall 版本正确，已有实例登记可读，要求验证的数据库实例
状态正常，部署结果已脱敏记录；目标用户的 `~/.bashrc` 已加载 `myas shell-init`
（或已记录该主机不需要实例命令）。
