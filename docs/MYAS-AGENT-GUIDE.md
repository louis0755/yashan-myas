# myas 测试智能体操作说明

本说明规定智能体在测试主机上使用 `myas` 的执行方式。

## 执行原则

- 单机实例在哪台主机运行，就登录哪台主机，在该主机安装并运行 `myas`。
- 单机创建统一使用 `myas create ... --local`。
- 不使用 `myas create --target HOST`。
- 优先使用目标主机上已存在且可读的数据库安装包；仅当目标主机没有该包时，才复制到
  目标主机的 `/tmp`。`--package` 始终使用目标主机上的绝对路径。
- 真实创建前先使用同一组参数执行 `--precheck`；预检失败则停止，不执行创建。
- 密码不得写入报告、日志、提交信息或 Markdown 文件。

## 目标主机准备

在每台要执行单机测试的目标主机上完成以下检查：

```bash
myas --version
myas config show
sudo -n true
df -h /data
```

## 本地节点预检

在已经登录目标主机时，使用 `myas check --local` 执行本机基线检查；不要执行
`myas check 本机IP`，因为该形式仍会通过 SSH 回连本机。补充检查可使用：

```bash
uname -m
sudo -n true
df -h /data
id yashan
getent group yashan
for command_name in bash awk tar systemctl getconf; do
  command -v "${command_name}" >/dev/null || echo "missing: ${command_name}"
done
```

安装前可用实际创建参数执行 `--precheck`，由 `yinstall` 进行只读环境、包和端口检查，
不会要求新实例的安装目录或数据目录已经存在：

```bash
myas create NAME VERSION --local --host-ip 本机IP \
  --package /绝对路径/PACKAGE.tar.gz --db-port DB_PORT --precheck
```

`--precheck` 成功后，移除 `--precheck` 执行真实创建。

先查找目标主机上已有的测试数据库包：

```bash
find /data /home/yashan /tmp -type f -name 'yashandb*-linux-*.tar.gz' -readable 2>/dev/null
```

若找到满足本次架构和版本要求的包，直接使用其绝对路径并记录 SHA256：

```bash
sha256sum /已有包的绝对路径/PACKAGE.tar.gz
```

只有目标主机没有所需包时，才从控制端复制到目标主机 `/tmp`，再使用
`/tmp/PACKAGE.tar.gz`。

按主机架构设置 `ARCH`：

```bash
# 192.168.23.4、192.168.23.13
myas config set ARCH x86_64

# 192.168.23.5
myas config set ARCH aarch64
```

首次使用或密码变更后，由授权人员在目标主机本地设置：

```bash
myas config set SYS_PASSWORD '实际密码'
myas config set BASE_DIR /data/yashan
```

## 单机创建

以下命令必须在实例实际部署的目标主机上执行。将 `HOST`、`NAME`、`VERSION`、
`PACKAGE` 和 `DB_PORT` 替换为本次测试值。

```bash
myas create NAME VERSION --local --host-ip HOST \
  --package /绝对路径/PACKAGE.tar.gz --db-port DB_PORT --precheck

myas create NAME VERSION --local --host-ip HOST \
  --package /绝对路径/PACKAGE.tar.gz --db-port DB_PORT \
  --remarks release-test
```

端口必须以四个连续端口为一组：数据库端口为 `18003`、`18007`、`18011` 等；对应
Yasom、Yasagent 和 Replicat 端口分别为数据库端口减 2、减 1、加 1。创建前确认该组
端口未被占用。

```bash
ss -ltn | grep -E ':1800[0-9]|:1801[0-9]|:1802[0-9]' || true
```

AI 包文件名不符合默认匹配规则，必须始终显式传入完整的 `--package` 绝对路径。

## 创建后验证

在创建命令成功后，仍在同一目标主机执行：

```bash
myas info CLUSTER
myas status CLUSTER
myas list
yasboot cluster status -c CLUSTER -d
eval "$(myas env CLUSTER)"
```

记录实例名称、集群名、主机、包文件与 SHA256、四个端口、`myas`/`yinstall` 版本和
验证结果。报告中不得包含 SYS 密码。

`myas info CLUSTER` 同时显示展示状态 `Status` 和生命周期状态 `Lifecycle`。生命周期
状态用于判断创建进度：`REGISTERED`（已登记，尚未调用安装器）、`INSTALLING`（安装中）、
`REGISTERED_FAILED`（仅登记阶段失败，通常没有安装产物）、`INSTALL_FAILED`（安装阶段
失败）、`PLANNED`（预检或 dry-run）、`INSTALLED`、`RUNNING`、`STOPPED`。

## 主备测试

- 主备创建只在主节点本地执行。
- 先在主节点使用 `myas create ... --local` 创建并验证主库。
- 后续主备拓扑由主节点上的 `yasboot` 按当前产品版本的主备流程创建和配置。
- 不使用 `myas create --target` 为备节点创建实例。
- 备节点上的 `myas` 只用于该机独立单机测试、信息查看或经授权的本机维护操作。

## 预检说明

`myas check HOST` 用于通过 SSH 检查远端主机，`myas check --local` 用于检查当前主机。
单机本地创建可配合 `myas create ... --local ... --precheck`；不要为了检查本机而执行
回环 SSH。

`--precheck` 与 `--dry-run` 只在预检/演练期间使用：0.3.9 起它们结束后会清理本次写入的
`~/.myas/instances.tsv` 记录，因此“预检成功 → 去掉 `--precheck` 再执行同一命令”可以直接
连续执行，不需要先删除登记（0.3.8 及更早版本会留下 `Lifecycle=PLANNED` 记录，必须先用
`myas delete` 清掉，见 MYAS-023）。

## 实例清理边界

测试主机上同时运行着实际使用的数据库。以下实例（`192.168.23.4`，2026-09-17 核对）
属于正在使用的数据库，**默认不删除、不停止、不改配置**：

| 实例 | 端口组 | 备注 |
| --- | --- | --- |
| `ys1903` | `1901`/`1902`/`1903`/`1904` | psftdb |
| `ys1907` | `1905`/`1906`/`1907`/`1908` | gbkdb |
| `ys1950` | `1948`/`1949`/`1950`/`1951`，MySQL `3311` | mysql-2344100 |
| `ys1960` | `1958`/`1959`/`1960`/`1961`，MySQL `3312` | mysql-2344125 |

同一主机上的 `ys2688`、`/data2/yashan/ys1835`、`/data2/yashan/ys1843`、ymp、ycm、
vectordb、tpch 等不属于本测试流程的实例同样不得清理；`192.168.23.13` 上的 `tpcc`
继续沿用“禁止清理或修改”。

规则：

- “删除测试实例”“清理残留”这类概括性要求，只授权处理本次对话中明确点名、且能证明
  属于本次测试的实例；不构成对上述正在使用数据库的授权。
- 删除或停止实例前，先以只读方式列出候选清单（实例名、集群、端口组、状态、目录、
  进程），由用户明确点名后才执行。
- 无法判断某实例是测试实例还是正在使用的数据库时，按后者处理并先向用户确认。

## 测试端口段与配置恢复

- `18xxx`、`19xxx`（`18000` 段与 `19000` 段）是测试 `myas` 本身时使用的端口号范围，
  不是生产端口段。
- 使用这些端口段前先备份生产配置：`cp -a ~/.myas/settings.conf ~/.myas/settings.conf.bak.$(date +%Y%m%d%H%M%S)`，并记录原来的 `YASOM_PORT_START`。
- 测试完成后必须把 `YASOM_PORT_START` 改回原值，或直接用备份恢复 `~/.myas/settings.conf`，不要让测试端口段留在主机配置里。
- 自动分配端口 = 从 `YASOM_PORT_START + 2` 起、每次 +4 的第一个空闲端口组（跳过 `instances.tsv` 中已占用的组），集群名为 `CLUSTER_PREFIX` + 数据库端口。例如 `YASOM_PORT_START=1901` 且 `1903`、`1907` 已占用时，自动分配落到 `1911`。

## 失败处理

- 任一预检、安装或运行验证失败后立即停止后续步骤。
- 保留该实例范围内的日志、配置和安装现场；不要删除为本次测试复制到 `/tmp` 的包。
- 不清理未明确属于本次测试的实例、目录或端口占用。
- 报告失败步骤、脱敏后的命令、错误输出、日志路径和下一步所需信息。

若 `Lifecycle=REGISTERED_FAILED`，且实例的 install、data、log、stage 路径均不存在，
可使用 `myas delete CLUSTER`，确认交互提示后直接清理登记和限定的实例路径。若为
`INSTALL_FAILED` 或任一路径已经存在，必须先保留现场并确认清理范围，不得绕过
`myas` 的保护直接删除。

### 创建早期失败：已有登记但没有 install 目录

`myas` 会在调用安装器前写入实例登记。若创建在安装器的早期阶段失败，可能出现以下
状态：

- `myas list` 中已有实例记录，状态为 `FAIL`；
- `/data/yashan/CLUSTER/install/bin/yasboot` 不存在，甚至 `install` 目录尚未创建；
- 0.3.8 起 `myas delete CLUSTER` 可直接清理这种实例：检测不到可用的 `yasboot` 时跳过
  生命周期停止，改为停止该集群残留的 `yasdb`/`yasom`/`yasagent` 进程，然后清理登记、
  Yasboot 环境文件、软链接和实例目录，空的实例目录也一并删除；
- 0.3.8 之前（含 `FAILED` 状态的旧登记）`myas delete CLUSTER` 会因找不到该实例的
  `yasboot` 而停止，只能按下面的有限范围流程手工处理；
- 不得因该失败直接使用宽泛的 `rm -rf`，也不得清理其他实例。

发生该情况时，停止重新创建和后续数据库操作。先以只读方式确认登记和目录是否只属于
本次失败实例：

```bash
myas info CLUSTER
myas list
find /data/yashan/CLUSTER -maxdepth 3 -ls 2>/dev/null || true
grep -F $'\tCLUSTER\t' "$HOME/.myas/instances.tsv" 2>/dev/null || true
```

报告实例名、集群名、失败步骤、`myas delete` 输出、登记文件匹配行和该实例目录清单。
在获得明确的实例范围和清理授权前，不手工删除目录或修改 `instances.tsv`。确认可清理时，
仅处理该集群的登记、Yasboot 环境文件和实例目录；完成后重新执行同一创建命令的
`--precheck`，成功才可重新创建。

清理失败实例前先停止该集群残留进程，避免端口占用导致下一次创建在 C-001 端口检查阶段
失败。`myas delete` 会列出并停止这些进程（输出形如 `Stopping leftover processes for
CLUSTER: PID...`），需要时可手动核对：

```bash
ps -eo pid,args | grep -E 'yas(db|om|agent)' | grep -- "-c CLUSTER"
```
