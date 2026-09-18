# 部署手册

本文以目标主机 `192.168.23.4` 为例。`myas` 默认在运行它的本机完成单机部署；
因此请在 `192.168.23.4` 上放置本仓库和 YashanDB 软件包。

## 1. 前置条件

需要 Bash 4.3+、`tar`、`awk` 和 `systemd`。实际执行 `os prepare`、`db install`、
`standby add` 或清理操作时，执行账户还必须具备免密 sudo；本地模式检查当前账户，
远程模式检查目标主机上的 SSH 用户。`--precheck`、`--dry-run`、`--help` 和
`--version` 不执行 sudo 变更。部署账户通常为 `yashan`，本地模式不需要 SSH 用户
或 SSH 密码。sys 密码由 `myas` 的 `SYS_PASSWORD` 配置提供，默认值为 `Cod-2022`。

```bash
sudo -n bash -c 'true'
```

上面的命令只验证当前账户能否免密启动 sudo shell；远程部署还需登录目标主机后执行
同样检查。没有 sudo 时仍可运行帮助、版本和只读预检，但不能完成安装或清理。

YashanDB 安装包路径由客户现场指定，不作为工具部署本身的前置条件；执行安装或
创建实例时，通过 `--package` 或 `PACKAGE_DIR` 提供实际路径。

## 2. 当前用户部署

部署包建议安装到当前用户的 `~/.local`，不需要 root 权限：

```bash
MYAS_VERSION=0.1.6
mkdir -p "$HOME/.local/opt/myas"
tar -xzf "/tmp/myas-${MYAS_VERSION}.tar.gz" -C "$HOME/.local/opt/myas"
ln -sfn "$HOME/.local/opt/myas/myas-${MYAS_VERSION}" \
  "$HOME/.local/opt/myas/current"
mkdir -p "$HOME/.local/bin"
ln -sfn "$HOME/.local/opt/myas/current/myas.sh" "$HOME/.local/bin/myas"
chmod +x "$HOME/.local/opt/myas/current/myas.sh" \
  "$HOME/.local/opt/myas/current/yinstall/yinstall.sh"
```

目录结构如下，`yinstall` 的 `lib/` 和 `steps/` 保持内置：

```text
~/.local/opt/myas/myas-0.1.6/
  myas.sh
  lib/
  yinstall/
    yinstall.sh
    lib/
    steps/
~/.local/opt/myas/current -> myas-0.1.6
~/.local/bin/myas -> ~/.local/opt/myas/current/myas.sh
```

`myas` 会自动调用 `current/yinstall/yinstall.sh`。也可以通过 `YINSTALL_BIN` 显式
配置，或从 PATH 查找独立的 yinstall。

将以下内容加入当前用户的 `~/.bashrc`：

```bash
export PATH="$HOME/.local/bin:$PATH"
eval "$(\"$HOME/.local/opt/myas/current/myas.sh\" shell-init)"
```

重新打开终端，或执行 `source ~/.bashrc`，使命令生效。

### 可选：独立 yinstall 预检

正常使用 `myas create` 时不需要单独执行此步骤，myas 会自动调用内置 yinstall。
只有在需要单独验证目标主机、端口和安装包，或准备手工执行 yinstall 时，才运行下面的
预检。`--precheck` 只检查环境，不执行安装变更。端口 `1803` 对应 Yasom `1801`、
Yasagent `1802` 和 Replicat `1804`：

```bash
cd "$HOME/.local/opt/myas/current"
./yinstall/yinstall.sh db install --local \
  --package /data/software/yashandb-23.4.14.100-linux-x86_64.tar.gz \
  --db-admin-password '替换为实际 sys 密码' \
  --cluster ys1803 --db-port 1803 \
  --install-path /data/yashan/ys1803/yasdb-home \
  --data-path /data/yashan/ys1803/yasdb-data \
  --log-path /data/yashan/ys1803/yasdb-log \
  --stage-dir /data/yashan/ys1803/install --precheck
```

## 3. 配置 myas

```bash
myas config set BASE_DIR /data/yashan
myas config set PACKAGE_DIR /data/software
myas config set YASOM_PORT_START 1701
myas config set SYS_PASSWORD '替换为实际 sys 密码'
myas config show
```

配置保存在 `~/.myas/settings.conf`，实例状态保存在 `~/.myas/instances.tsv`。

## 4. 创建实例

省略 `--db-port` 时自动分配首个可用连续端口组：

```bash
myas create appdb 23.4.14.100
myas
myas info ys1703
```

## 5. 切换环境与管理

```bash
eval "$(\"$HOME/.local/opt/myas/current/myas.sh\" shell-init)"
ys1703
ystatus
yshutdown
ystart
yrestart
```

每次发布必须先更新 `myas/VERSION` 和变更记录，再运行测试、打包并记录 SHA256；详见 `myas/docs/RELEASE.md`。升级时解压新的版本目录，并重新指向 `current`：

```bash
MYAS_VERSION=0.1.6
tar -xzf "/tmp/myas-${MYAS_VERSION}.tar.gz" -C "$HOME/.local/opt/myas"
ln -sfn "$HOME/.local/opt/myas/myas-${MYAS_VERSION}" \
  "$HOME/.local/opt/myas/current"
```

已有 `~/.myas/` 配置和实例登记会继续使用。
