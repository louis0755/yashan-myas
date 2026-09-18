# YashanDB Release Test Standard

本文是 `myas` 正式 release 前的标准测试流程。测试目标主机为：

| 主机 | 架构 | 用途 |
| --- | --- | --- |
| `yashan@192.168.23.4` | `x86_64` | x86_64 包矩阵测试 |
| `yashan@192.168.23.5` | `aarch64` | aarch64 包矩阵测试 |
| `yashan@192.168.23.13` | `x86_64` | x86_64 二次回归、异常/边界测试 |

测试包来自 `/home/ganlu/software`，每个目标主机的测试包复制到 `/tmp` 后保留，测试结束不删除。

## 1. 测试前提

在控制端仓库根目录执行：

```bash
cd /home/ganlu/ai/myas
git status --short
bash -n myas/myas.sh myas/lib/*.sh
bash -n yinstall/yinstall.sh yinstall/lib/*.sh yinstall/steps/*.sh
bash myas/tests/test_cli.sh
bash yinstall/tests/test_cli.sh
bash yinstall/tests/test_ports.sh
```

所有命令必须返回 `0`。测试环境需要确认：

- 控制端可使用 `ssh`、`scp`，用于登录和分发测试包；
- 目标主机账户为 `yashan`，可执行 `sudo -n`；
- 每台单机测试目标都已在本机安装发布包中的 `myas`，且 `myas --version` 可用；
- 已获得可用于测试的 YashanDB `sys` 密码；
- 目标主机的 `/data/yashan` 有至少 5 GiB 可用空间，建议至少 20 GiB；
- 测试期间不应有其他任务占用 `18000-18099` 端口。

## 2. 主机预检

本方案不使用 `myas create --target` 进行单机部署。单机测试必须先登录对应目标
主机，在该主机本地执行 `myas create ... --local`。控制端只负责代码检查、包分发和
登录验证。

使用当前配置检查 SSH、操作系统、架构、CPU、内存、磁盘、用户组、sudo、目录和命令：

```bash
MYAS_CONFIG_DIR=/tmp/myas-release-check \
  myas/myas.sh check 192.168.23.4 192.168.23.5 192.168.23.13
```

预期架构结果：

- `192.168.23.4` 和 `192.168.23.13` 为 `x86_64`；
- `192.168.23.5` 为 `aarch64`；
- 不得用 `x86_64` 包部署到 `aarch64`，反之亦然。

若出现 `FAIL`，必须先按 `NEED` 行补充信息或修复主机；不得以 `WARN` 代替 `FAIL`。

## 3. 分发安装包

六个包必须完整复制到对应测试主机的 `/tmp`：

```bash
X86_PACKAGES=(
  yashandb-23.4.14.105-linux-x86_64.tar.gz
  yashandb-23.5.4.100-linux-x86_64.tar.gz
  yashandb-ai-23.5.4.100-linux-x86_64.tar.gz
)
ARM_PACKAGES=(
  yashandb-23.4.14.105-linux-aarch64.tar.gz
  yashandb-23.5.4.100-linux-aarch64.tar.gz
  yashandb-ai-23.5.4.100-linux-aarch64.tar.gz
)
scp /home/ganlu/software/"${X86_PACKAGES[@]}" yashan@192.168.23.4:/tmp/
scp /home/ganlu/software/"${X86_PACKAGES[@]}" yashan@192.168.23.13:/tmp/
scp /home/ganlu/software/"${ARM_PACKAGES[@]}" yashan@192.168.23.5:/tmp/
```

若当前 `scp` 不支持一次传递数组，逐个执行：

```bash
scp /home/ganlu/software/yashandb-23.4.14.105-linux-x86_64.tar.gz \
  yashan@192.168.23.4:/tmp/
```

复制后记录并核对校验值：

```bash
sha256sum /home/ganlu/software/*.tar.gz
for host in 192.168.23.4 192.168.23.5 192.168.23.13; do
  ssh "yashan@${host}" 'sha256sum /tmp/yashandb*.tar.gz'
done
```

安装包在 `/tmp` 中保留，不在测试流程中删除。

## 4. 端口分配

YashanDB 使用连续四端口：Yasom、Yasagent、数据库、Replicat。测试从 `18000` 段开始，数据库端口必须使用 `18003`、`18007` 这类能向下保留两个端口、向上保留一个端口的值：

| 测试序号 | 数据库端口 | Yasom | Yasagent | Replicat |
| ---: | ---: | ---: | ---: | ---: |
| 1 | `18003` | `18001` | `18002` | `18004` |
| 2 | `18007` | `18005` | `18006` | `18008` |
| 3 | `18011` | `18009` | `18010` | `18012` |
| 4 | `18015` | `18013` | `18014` | `18016` |
| 5 | `18019` | `18017` | `18018` | `18020` |
| 6 | `18023` | `18021` | `18022` | `18024` |

使用下一个端口组前，检查四端口均未被占用：

```bash
ssh yashan@HOST 'ss -ltn | grep -E ":1800[1-8]|:1801[0-2]" || true'
```

`18xxx`、`19xxx`（`18000` 段与 `19000` 段）是测试 `myas` 本身专用的端口号范围，不是生产
端口段。使用这些端口段测试前，先备份生产配置并记录原值：

```bash
cp -a ~/.myas/settings.conf ~/.myas/settings.conf.bak.$(date +%Y%m%d%H%M%S)
grep '^YASOM_PORT_START=' ~/.myas/settings.conf
```

测试结束后必须把 `YASOM_PORT_START` 改回原值，或直接用备份恢复整个 `~/.myas/settings.conf`，
不允许把测试端口段遗留成主机生产配置：

```bash
myas config set YASOM_PORT_START 原值
diff -u ~/.myas/settings.conf.bak.YYYYmmddHHMMSS ~/.myas/settings.conf
```

## 5. 包测试矩阵

每个架构测试三个包。普通包可以使用默认文件名匹配；AI 包文件名包含 `-ai`，必须显式传递 `--package`。

| 主机 | 包 | 版本 | 参数 |
| --- | --- | --- | --- |
| `.4` / `.13` | `yashandb-23.4.14.105-linux-x86_64.tar.gz` | `23.4.14.105` | `--package /tmp/...` |
| `.4` / `.13` | `yashandb-23.5.4.100-linux-x86_64.tar.gz` | `23.5.4.100` | `--package /tmp/...` |
| `.4` / `.13` | `yashandb-ai-23.5.4.100-linux-x86_64.tar.gz` | `23.5.4.100` | 必须显式 `--package` |
| `.5` | `yashandb-23.4.14.105-linux-aarch64.tar.gz` | `23.4.14.105` | `--package /tmp/...` |
| `.5` | `yashandb-23.5.4.100-linux-aarch64.tar.gz` | `23.5.4.100` | `--package /tmp/...` |
| `.5` | `yashandb-ai-23.5.4.100-linux-aarch64.tar.gz` | `23.5.4.100` | 必须显式 `--package` |

登录目标主机 `192.168.23.4` 后，在该机本地执行（不带 `--target`）：

```bash
myas config set SYS_PASSWORD '实际测试密码'
myas config set BASE_DIR /data/yashan
myas config set ARCH x86_64
myas create rel-234-x86 23.4.14.105 \
	--local --host-ip 192.168.23.4 \
  --package /tmp/yashandb-23.4.14.105-linux-x86_64.tar.gz \
  --db-port 18003 --remarks release-test
```

登录 ARM 主机 `192.168.23.5` 后，切换架构配置并传入 ARM 包：

```bash
myas config set ARCH aarch64
myas create rel-234-arm 23.4.14.105 \
	--local --host-ip 192.168.23.5 \
  --package /tmp/yashandb-23.4.14.105-linux-aarch64.tar.gz \
  --db-port 18003 --remarks release-test
```

`.13` 回归测试同样先在 `.13` 本机安装并验证 `myas`，再以 `--local` 创建实例。
本测试不支持从控制端或其他主机调用 `myas create --target`。

## 6. 单包验证清单

每个实例创建前，登录对应目标主机并在本地执行：

```bash
myas check HOST
myas create NAME VERSION --local --host-ip HOST \
  --package /tmp/PACKAGE.tar.gz --db-port DB_PORT \
  --precheck
```

预检无 `FAIL` 后再去掉 `--precheck` 执行部署。部署后必须检查：

```bash
myas info CLUSTER
myas status CLUSTER
myas list
yasboot cluster status -c CLUSTER -d
ss -ltn | grep -E ':1800[0-9]|:1801[0-9]|:1802[0-9]'
```

并验证：

- `database_status=normal`、实例状态为 `RUNNING`；
- `listen_address` 使用指定的目标 IP；
- `hosts.toml` 和集群 TOML 中端口、字符集及其他指定参数正确；
- AI 包不能因为文件名自动匹配失败；显式 `--package` 能正常完成部署；
- `myas info` 显示的版本与包版本一致；
- 生成环境后 `eval "$(myas env CLUSTER)"` 能设置正确的 `YASHANDB_*` 变量。

需要测试 MySQL 形态时，使用独立端口并增加：

```bash
myas create NAME VERSION --local --host-ip HOST \
  --package /tmp/PACKAGE.tar.gz --db-port DB_PORT \
  --mysql --mysql-port MYSQL_PORT
myas info CLUSTER
```

确认 `MySQL mode` 和 MySQL 端口均正确。GBK、`--use-native-type` 等参数应至少在一个普通包和一个 AI 包上各验证一次。

## 7. 失败处理和清理

失败实例保留现场，记录以下信息后再处理：

- 主机、架构、包完整文件名和 SHA256；
- `myas create` 完整命令（隐藏密码）；
- 使用的四端口和 MySQL 端口；
- `myas info`、`yasboot cluster status -c CLUSTER -d` 输出；
- `/tmp` 包路径、yinstall 版本和日志路径；
- 失败步骤编号（如 `B-002`、`C-004`）及 `NEED` 补充项。

测试包不得删除。测试数据库实例可在报告确认后按实例逐一停止并清理；清理前保存配置和日志，禁止使用不带实例路径校验的递归删除命令。

## 8. 可选：一主一备测试

主备测试使用 `192.168.23.4` 作为主机、`192.168.23.13` 作为备机。该测试是可选门禁；启用后必须使用与普通包矩阵相同的包校验、架构和端口规则。

建议使用新的集群名 `ys18003`，主库使用数据库端口 `18003`（Yasom `18001`、Yasagent `18002`、Replicat `18004`），备库不得复用其他实例端口。主备两端的管理 IP 必须在生成 TOML 时明确指定为 `192.168.23.4` 和 `192.168.23.13`。

### 8.1 主库

```bash
myas create release-primary 23.4.14.105 --local \
  --host-ip 192.168.23.4 \
  --package /tmp/yashandb-23.4.14.105-linux-x86_64.tar.gz \
  --db-port 18003 --remarks release-standby-primary
myas status ys18003
```

主库必须为 `RUNNING`，并且 `yasboot cluster status -c ys18003 -d` 报告 `primary`、`normal`。

### 8.2 备库

主备部署在主节点 `.4` 本地使用产品 `yasboot` 创建，不通过 `myas --target` 部署备节点。
主节点和备节点都应分别安装对应架构的 `myas`，但主备创建命令只在主节点执行；由主节点
上的 `yasboot` 按产品主备流程注册和配置备节点。

执行前必须确认主库和备库的 yasboot 环境文件、stage 目录和集群名不冲突。若目标机已有同名环境，先记录并按产品命令清理，或使用该版本明确支持的强制参数。

例如主机 `.4`、备机 `.13`：先在 `.4` 本地完成主库创建和健康检查，再仅在 `.4` 上按
当前 YashanDB 产品文档执行 `yasboot` 的主备创建命令。不得从控制端、`.4` 或 `.13` 使用
`myas create --target 192.168.23.13`。

```bash
# 在主节点 .4 上执行；参数以当前产品文档为准。
yasboot cluster create ...
```

主备流程失败时后续步骤必须停止；失败现场应保留并在报告中标明失败步骤。远程 SSH 客户端
低于 OpenSSH 7.6 时，不支持 `StrictHostKeyChecking=accept-new`，测试流程应确认产品流程
包含兼容处理。

```bash
yasboot cluster status -c ys18003 -d
```

预期主库为 `primary`、备库为 `standby`，两端 `database_status` 为 `normal`，并且主备复制地址使用指定 IP。至少执行一次主库和备库的停止/启动恢复验证，再次确认角色和复制状态。

### 8.3 主备报告项

主备测试报告除普通矩阵字段外增加：主/备节点 ID、主备管理 IP、复制端口、免密 SSH 检查、角色验证、复制状态验证、重启恢复结果。免密 SSH 或主备配置缺失时，结果为 `PARTIAL`，并在备注中写明需要补充的 SSH 或配置字段。

## 9. 测试报告

报告至少包含以下表格：

| 主机 | 架构 | 包文件 | 版本 | DB 端口 | 预检 | 部署 | 运行状态 | 配置验证 | 结果 | 备注 |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- |
| 192.168.23.4 | x86_64 | ... | ... | 18003 | PASS/FAIL | PASS/FAIL | RUNNING/... | PASS/FAIL | PASS/FAIL | ... |

最终结论只能是：

- `PASS`：所有矩阵项预检、部署和运行验证均通过；
- `PARTIAL`：有明确记录的环境阻塞项，但代码路径已完成可执行验证；
- `FAIL`：存在未解释的安装、配置、运行或架构兼容性失败。

## 10. 正式 release 门禁

正式 release 前必须重复本流程，不得只依赖历史测试结果：

1. 更新 `myas/VERSION`、`myas/CHANGELOG.md`，必要时同步 `yinstall` 版本。
2. 运行第 1 节的静态检查和自动化测试。
3. 重新执行第 2 节三台主机预检。
4. 重新复制并校验本 release 对应的六个包，保留 `/tmp` 文件。
5. 完成第 5、6 节的架构矩阵和部署验证。
6. 生成并保存 SHA256、测试报告和日志。
7. 提交 Git、推送 GitHub、创建 tag/release；发布包必须与测试包 SHA256 一致。
8. release 后至少在 `.4`（x86_64）和 `.5`（aarch64）各做一次安装冒烟测试。
