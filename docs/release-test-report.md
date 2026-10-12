# Release Test Report

测试日期：2026-08-26，更新：2026-09-17  
测试对象：`myas 0.3.8`、`yinstall 0.4.6`（2026-09-17 候选包；历史记录为 0.3.6/0.4.5）  
主机：`192.168.23.4`（主）、`192.168.23.13`（备）  
最终结论：`PARTIAL`

2026-09-17 结论说明：0.3.8 候选包在 `192.168.23.4`、`192.168.23.13`、`192.168.23.5` 完成部署、
单机创建、连通性、停机、启动与删除验证（含早失败实例删除），全部 `PASS`，主备此前阻塞的
`cluster join` 流程也已改为一次性 `yasboot package se gen` 生成。但同日的剩余矩阵复测显示：
主备一次性部署因 `hosts.toml` 备机 yasagent 地址生成错误而 `FAIL`（YINSTALL-010），
23.5.4.100 与 AI 包因主机 OpenSSL 版本限制 `FAIL（环境限制）`。按 `myas/docs/RELEASE.md`，报告结论
定为 `PARTIAL`，主备修复并复测通过后方可回到 `PASS`。历史小节保留原始失败记录。

本次继续测试前先执行了实例检测。`.13` 上 `ys18007` 的 cluster status 返回资源不存在，没有可用数据库实例；但发现上次失败留下的初始化进程、yasboot 环境文件和安装目录，已按实例范围清理。`.13` 原有 `tpcc` 实例未被清理。

## 测试包

三个 x86_64 包已复制到两台主机 `/tmp`，测试结束未删除，控制端和目标机 SHA256 一致。

| 包 | SHA256 |
| --- | --- |
| `yashandb-23.4.14.105-linux-x86_64.tar.gz` | `e5bc0fe0a3f1c8a9ce1f66099ba644ff646c750867df637ea3f0af96f46e39b3` |
| `yashandb-23.5.4.100-linux-x86_64.tar.gz` | `8c08ade64dc426c8a495b93fbb6e4d19c389469de595ad954b9e058a886d1f88` |
| `yashandb-ai-23.5.4.100-linux-x86_64.tar.gz` | `433cc775d3f64aacbea5dfbb93a01544e3ca8d1e2776335235c64c1904368603` |

## 主机检查

| 主机 | 架构 | 操作系统 | CPU | 内存 | `/data` 可用 | SSH/sudo | 结果 |
| --- | --- | --- | ---: | ---: | ---: | --- | --- |
| `192.168.23.4` | `x86_64` | CentOS 7 | 128 | 515250 MiB | 767565 MiB | PASS | PASS |
| `192.168.23.13` | `x86_64` | Kylin V10 | 128 | 514599 MiB | 2331786 MiB | PASS | PASS |

`.4` 使用 OpenSSH 7.4，`.13` 使用 OpenSSH 8.2；旧客户端兼容降级逻辑已实际验证。

## 自动化测试

以下命令全部通过：

```text
bash -n yinstall/yinstall.sh yinstall/lib/*.sh yinstall/steps/*.sh
bash yinstall/tests/test_cli.sh
bash yinstall/tests/test_ports.sh
bash myas/tests/test_cli.sh
```

修复提交：`0dc97f1 Fix standby upload failure handling`、`3b5324d Support legacy OpenSSH host key checks`。

## 主库部署

实例：`ys18007`，主机 `192.168.23.4`，包 `23.4.14.105 x86_64`，数据库端口 `18007`，管理端口 `18005/18006`，复制端口 `18008`。

```text
instance_status: open
database_status: normal
database_role: primary
listen_address: 192.168.23.4:18007
result: PASS
```

## 主备测试结果

首次执行发现远程上传错误：

```text
scp: stat local "22": No such file or directory
```

原因是远程 `scp` 错误使用小写 `-p`。同时流程在上传失败后继续执行，使用了不完整 stage。已修复为 `scp -P` 并增加备库步骤失败短路，自动化测试全部通过。

清理残留后重试，备库已成功完成 SSH/OS 预检、包上传、解压、配置生成和软件安装，配置使用 `192.168.23.13`。第一次重试因接口将 `--begin-port` 同时用于备库端口和主库连通性检查而检查了错误端口；改用主库数据库端口 `18007` 后，`E-015` 连通性检查通过。

随后产品 `yasboot cluster join` 返回主机未注册：

```text
the host 192.168.23.4 not exists, please add host to yasom firstly
```

尝试通过主库 `yasboot package upload` 注册备机时，Yasom 返回：

```text
UNIQUE constraint failed: host.manage_ip
```

说明该管理 IP 已存在于 Yasom 管理平面，但当前 hosts 配置/备库 join 环境未能复用该记录。为避免破坏主库，未继续强制修改 Yasom。

此前同名环境冲突的错误为：

```text
file /home/yashan/.yasboot/ys18007.env is already exist
confirm whether a cluster with the same name: 'ys18007' has been deployed
config check failed
```

失败步骤为 `E-014 install standby software`，流程已停止，未继续执行 join 和复制验证。

| 项目 | 结果 |
| --- | --- |
| 主库健康检查 | PASS |
| 备库 SSH/OS 预检 | PASS |
| 备库包上传 | PASS（修复后） |
| 备库配置生成 | PASS，IP 为 `192.168.23.13` |
| 备库软件安装 | PASS（清理残留后） |
| 主库连通性检查 | PASS（使用 `192.168.23.4:18007`） |
| `cluster join` | FAIL，主机未注册到 Yasom |
| standby 角色验证 | NOT RUN |
| 复制状态验证 | NOT RUN |

## 现场保留

- 两台主机 `/tmp` 下的三个 x86_64 测试包均保留；
- `.4` 上保留并运行成功的 `ys18007` 主库；
- `.4` 上保留失败登记 `ys18003`、`ys18011`；
- `.13` 上本次失败生成的 `ys18015` 目录、初始化进程和 `ys18007.env` 已按实例范围清理；
- 主备日志保存在 `.4:/tmp/release-standby-18015/`。

## 需要补充的信息

要完成主备复制闭环测试，需要：

1. 由产品/DBA 确认 Yasom 中 `192.168.23.13` 的现有 host 记录及其归属，解决 `host.manage_ip` 唯一约束冲突；
2. 提供该版本正式的主备 host 注册、`join.toml` 生成和 `yasboot cluster join` 操作规范；
3. 确认主备两端的安装 home、数据目录、节点 ID 和端口规划；
4. 管理平面修复后重新执行 `E-016` 至 `E-017`，验证 standby 角色、normal 状态及重启恢复。

在信息补齐前，不能把本次主备测试标记为 PASS。普通单机主库部署、包复制、架构检查、旧 SSH 兼容和失败短路已验证通过。

## 2026-09-17 myas 0.3.8 候选包部署验证（192.168.23.4）

对象：GitHub 候选包 `myas-0.3.8.tar.gz`（Release tag `v0.3.8`，内置 yinstall `0.4.6`），
SHA256 `d2290c71ce41adac6553a51dc0c8e1271b86de9877f47997dafcdb0438d2a36d`。

| 项目 | 结果 |
| --- | --- |
| 公开包传输与 SHA256 核对（`/tmp/myas-0.3.8.tar.gz`） | PASS |
| 解包部署到 `~/.local/opt/myas/myas-0.3.8` 并切换 `current` | PASS |
| `myas --version` / 内置 `yinstall.sh --version` | PASS（`myas 0.3.8`、`yinstall 0.4.6`） |
| `myas --help` 新增 `delete NAME_OR_CLUSTER` 与 `Delete:` 说明 | PASS |
| `myas list`、`myas info` 读取既有登记（含新 `Lifecycle` 行） | PASS |
| 既有实例状态（`ys1903`/`ys1907`/`ys1950`/`ys1960`/`ys1911`） | PASS，均 RUNNING，未做任何变更 |
| 主机配置保留（`BASE_DIR`、`ARCH`、`YASOM_PORT_START=1901`、`YINSTALL_BIN`） | PASS |

部署方式为公开包方式（`myas/docs/release/07` 推荐路径），未使用会重建 `psftdb` 的
`myas/tools/release.sh`，未上传注入密码的现场包。上一版本 `myas-0.3.6` 目录保留，可作为回滚点。

### 实例级验证（`--db-port 1915`，19xxx 测试端口段）

| 步骤 | 命令 | 结果 |
| --- | --- | --- |
| 预检 | `myas create reltest1915 23.4.4.106 --local --host-ip 192.168.23.4 --package /data/software/yashandb-23.4.4.106-linux-x86_64.tar.gz --db-port 1915 --precheck` | PASS，退出码 `0`，B-004 不再要求实例目录已存在（yinstall 0.4.6 修复） |
| 创建 | 同上去掉 `--precheck` | PASS，`rc=0`，`instance_status=open`、`database_status=normal`、`database_role=primary`、`listen_address=192.168.23.4:1915` |
| 连通性 | `yasql / as sysdba` 执行 `select 1 from dual` | PASS，返回 1 行 |
| 停机 | `myas shutdown ys1915` | PASS，`StopYasdbCluster` SUCCESS，端口 1913–1916 释放，列表显示 `INSTALLED` |
| 启动 | `myas start ys1915` | PASS，任务 SUCCESS，列表显示 `RUNNING`，四端口恢复监听 |
| 删除（正常实例） | `myas delete ys1915` | PASS，退出码 `0`，输出 `Removed empty directory: /data/yashan/ys1915`；登记、目录、`.env`、软链接与端口全部清理 |
| 早失败实例删除（MYAS-022） | 用 `/etc/hosts` 充当包制造 `Lifecycle=INSTALL_FAILED`（目录已建、无 `install/bin/yasboot`），随后 `myas delete ys1919` | PASS，退出码 `0`，输出 `No usable yasboot for ys1919; cleaning instance files without a lifecycle stop.`，目录与登记清理干净 |
| 残留复核 | `myas list`、`ls /data/yashan`、`ss -ltn`、进程扫描 | PASS，仅保留原有 5 个实例，1913–1920 端口空闲，无残留进程或 `.env` |

测试期间未改动 `YASOM_PORT_START`（显式指定端口，仍为原值 `1901`），`settings.conf` 与其备份
`settings.conf.bak.20260917111444` 均在位。当时的待办：`--precheck` 成功后会留下
`Lifecycle=PLANNED` 登记，导致紧接着的同名真实创建报 `instance already exists`，本次通过
先 `myas delete` 该 PLANNED 登记再创建绕过；该问题（MYAS-023）已于 `myas 0.3.9` 修复，
预检/演练不再留下登记。

### `192.168.23.13` / `192.168.23.5` 部署与实例级验证（同日追加）

两台主机均从 `myas 0.3.7` 升级到 0.3.8（公开包，SHA256 与 Release 资产一致），测试前
各自备份了 `~/.myas/settings.conf`（`settings.conf.bak.20260917160954`、`settings.conf.bak.20260917161000`），
测试后 `diff` 确认配置未变化，`YASOM_PORT_START` 仍为原值 `1701`。

| 主机 | 架构 | 测试实例与端口 | 结果 |
| --- | --- | --- | --- |
| `192.168.23.13` | x86_64（Kylin V10） | `reltest19007` / `ys19007`，包 `yashandb-23.4.14.105-linux-x86_64.tar.gz` | 预检 PASS、创建 `open/normal/primary`、`yasql select 1` PASS、停机 PASS、启动 PASS、删除 PASS（含空目录清理），无残留 |
| `192.168.23.5` | aarch64（Kylin V10） | `reltest19011` / `ys19011`，包 `yashandb-23.4.14.105-linux-aarch64.tar.gz` | 同上全部 PASS，无残留 |

两台主机共同验证点：

- `myas --version` = `0.3.8`，内置 `yinstall 0.4.6`，`myas --help` 含 `delete NAME_OR_CLUSTER`；
- `--precheck` 在 0.4.6 下通过（旧版 0.4.5 在本机也会失败），随后按 MYAS-023 的临时做法
  `myas delete` 清掉 `Lifecycle=PLANNED` 登记再创建；
- 既有实例未被改动（`.13` 的 `ys19003` 与 `tpcc`；`.5` 的 `ys19003`、`ys19007`、`ys19103`、`ys19107`）；
- 释放后 19005–19012（`.13`）、19009–19012（`.5`）端口空闲，无残留目录、`.env` 或进程。

### 剩余矩阵与主备复测（同日追加，逐项结论）

| 项目 | 命令要点 | 结果 |
| --- | --- | --- |
| `.4` 23.5.4.100 | `myas create reltest19203 23.5.4.100 --local --db-port 19203 --package /data/yashan/soft/yashandb-23.5.4.100-linux-x86_64.tar.gz` | `FAIL`（环境）：`YAS-00509 failed to load dynamic library ... libssl.so.1.1: cannot open shared object file`，实例 `open` 失败、`Lifecycle=INSTALL_FAILED`；已按实例范围清理 |
| `.5` 23.5.4.100 | 同上（aarch64，`--db-port 19015`） | `FAIL`（环境）：`version 'OPENSSL_1_1_1f' not found (required by /usr/lib64/libssl.so.1.1)`；已清理 |
| `.4` AI 包 `yashandb-ai-23.5.4.100` | `--db-port 19207` | `FAIL`（环境）：与 23.5.4.100 相同的 OpenSSL 冲突；已清理 |
| `.5` AI 包 `yashandb-ai-23.5.4.100` | `--db-port 19019` | `FAIL`（环境）：同上；已清理 |
| 主备端到端（`.4` → `.13`，23.4.14.105，`--db-port 19209`） | `myas create reltest-ha 23.4.14.105 --target 192.168.23.4 --host-ip 192.168.23.4 --standbys 192.168.23.13 ...` | `FAIL`（缺陷）：`B-000`、`C-000`、`C-004`~`C-006` PASS，`C-007` 失败，`DeployYasdbCluster` CANCELED |

主备失败根因（已开缺陷单 `louis0755/yashan-yinstall-bash#10`，YINSTALL-010）：`yasboot package se gen`
生成的 `hosts.toml` 中，第二个 host 的 `[host.yasagent.config] LISTEN_ADDR` 写成主库 IP
`192.168.23.4:19208`（应为 `192.168.23.13:19208`），备机绑定该地址失败：
`listen tcp 192.168.23.4:19208: bind: cannot assign requested address`、`YAS-00415 failed to create
listener, host: 192.168.23.13:19210`。同目录 `ys19209.toml` 的两个节点地址是正确的。
另外确认两点现状：`myas create --standbys` 需要远程主库目标（`--local` 会被 yinstall 拒绝，
与 `myas/docs/MYAS-AGENT-GUIDE.md`/`myas/docs/release-test.md` §8.2 的旧描述不一致，文档待更新）；远程目标登记
无法用 `myas delete` 清理（yashan-myas#22）。

失败现场已清理干净：主备两侧执行 `yasboot process yasom/yasagent stop`、`package uninstall`，
再按实例范围删除目录、yasboot 环境与登记行（备份 `instances.tsv.before-ys19209-cleanup.*`）；
`192.168.23.4` 保留原有 5 个实例，`192.168.23.13` 的 `ys19003` 与 `tpcc` 未受影响，19209/19210
端口已释放。23.5.4.100 与 AI 包的失败与 yinstall 行为无关，属主机 OpenSSL 版本限制
（与 aarch64 案例同因，参见 yashan-myas#23）。

结论（2026-09-17 最终）：单机矩阵 `PASS`（`.4`：23.4.4.106、23.4.14.105；`.13`/`.5`：23.4.14.105），
23.5.4.100 与 AI 包 `FAIL（环境限制）`，主备端到端 `FAIL（YINSTALL-010）`。按 `myas/docs/RELEASE.md`
的规则，报告整体结论由 `PASS` 调整为 **`PARTIAL`**；`v0.3.8` 的代码、单机部署与删除能力
不受影响，但主备门禁需在 YINSTALL-010 修复并复测后再回到 `PASS`。

据此结论，`myas 0.3.8` 已在 2026-09-18 从正式 Release（Latest）**退回候选版本（pre-release）**，
GitHub 的 Latest 回到 `v0.3.2`；Release notes 已注明退回原因与待修复项。相关缺陷单：
YINSTALL-010（主备 `hosts.toml` 备机地址，排期 yinstall 0.4.7）、MYAS-024（23.5.4.100/AI 包的
OpenSSL 环境限制，状态 `ENVIRONMENT LIMITATION`）、MYAS-023（`--precheck` 残留 PLANNED 登记，
排期 0.3.9）。修复并复测通过后按 `myas/docs/RELEASE.md` 重新评估提升为正式 Release。

2026-09-18 修复进展：YINSTALL-010 已修复（`steps/host-addrs.awk`，yinstall 0.4.7，CLI 夹具覆盖），
MYAS-023 已修复（预检/演练不再留下登记，myas 0.3.9，CLI 覆盖）；两项的真实主机复测
（`.4 → .13` 主备端到端、预检后直接创建）待组合包部署后再执行并更新本节。

## 2026-09-18 myas 0.3.9 组合包部署（192.168.23.4 / .13 / .5）

对象：`myas-0.3.9.tar.gz`（myas 0.3.9 + 内置 yinstall 0.4.7），由工作区
`myas/tools/package.sh` 生成（git `609201b`、`c1a05ac`），
SHA256 `f612c0073ca5642bbe35942d3ea9597a086f37c0c30a4d4e054b396d1b4f8ce5`。
部署方式为 `myas/docs/release/07` 的公开包路径，未使用会重建 `psftdb` 的 `tools/release.sh`。

| 主机 | 架构 | 部署前 | 部署后 | SHA256 | 既有实例 |
| --- | --- | --- | --- | --- | --- |
| `192.168.23.4` | x86_64 | myas 0.3.8 | myas 0.3.9 / yinstall 0.4.7 | PASS | 5 个实例（`ys1903`/psftdb、`ys1907`/gbkdb、`ys1950`、`ys1960`、`ys1911`/szsw）未改动，全部 RUNNING |
| `192.168.23.13` | x86_64 | myas 0.3.8 | 同上 | PASS | `ys19003` 未改动并 RUNNING；`tpcc` 未触碰 |
| `192.168.23.5` | aarch64 | myas 0.3.8 | 同上 | PASS | `ys19003`、`ys19007`、`ys19103`、`ys19107` 未改动 |

- 每台机部署前备份 `~/.myas/settings.conf`（`settings.conf.bak.2026091812xxxx`），部署后核对
  `BASE_DIR`、`ARCH`、`YASOM_PORT_START`（`.4`=`1901`，`.13`/`.5`=`1701`）与 `YINSTALL_BIN`
  （指向 `~/.local/opt/myas/current/yinstall/yinstall.sh`）均符合预期。
- 三台机 `myas --help` 均包含 `delete NAME_OR_CLUSTER`，`myas list` 读取既有登记正常。
- 回滚点保留 `~/.local/opt/myas/myas-0.3.8`（`.4` 另有 `0.3.6`，`.13`/`.5` 另有 `0.3.7`），回滚只需把
  `current` 软链接指回并重建 `~/.local/bin/myas`。
- 仍未执行：YINSTALL-010 的主备端到端复测、MYAS-023 的“预检 → 直接创建”复测，状态 `NOT RUN`。

## 2026-10-12 myas 0.3.14 组合包发布测试（.4 / .13 / .5）

对象：`myas-0.3.14.tar.gz`（myas `0.3.14` + 内置 yinstall `0.4.11`），提交 `a6313e2`
（yinstall `7e7b33b`），tag `v0.3.14`，SHA256
`689f1be524a35c3037bfaefdcf11d4d9a9ff612f11e4909d028b68011d3545df`。
GitHub Release 已创建，但按 `myas/docs/RELEASE.md` 第 1 节（结论为 `PARTIAL` 时不得创建正式
Release，候选包必须标记为非正式版本）标记为 **pre-release 候选**，未提升为正式版。
部署方式为 `myas/docs/release/07` 的公开包路径，未使用会重建 `psftdb` 的 `tools/release.sh`。

### 自动化测试

`bash -n`（myas + yinstall）、`myas/tests/test_cli.sh`、`yinstall/tests/test_cli.sh`、
`yinstall/tests/test_ports.sh`（新增端口锚定与 `--db-version` 回归用例）、`yinstall.sh --help`、
隔离配置 `myas list` 全部返回 `0`。

### 工具部署

| 主机 | 架构 | 部署前 | 部署后 | 既有实例 |
| --- | --- | --- | --- | --- |
| `192.168.23.4` | x86_64 | `0.3.9` | `0.3.14` / yinstall `0.4.11` | 5 个实例（`ys1903`/psftdb、`ys1907`/gbkdb、`ys1950`、`ys1960`、`ys1911`/szsw）未改动 |
| `192.168.23.13` | x86_64 | `0.3.11` | 同上 | `ys19003`、`ys19007`、`ys1911`、`ys1915` 未改动；`tpcc` 未触碰 |
| `192.168.23.5` | aarch64 | `0.3.14`（当日早先部署） | 同上（`v0.3.14` 资产同一 SHA256） | 6 个实例未改动（含本次 `ys1919`） |

`.4` 的 `~/.bashrc` 原本没有 `myas shell-init`，本次按 `release/07` 补上；`.13`/`.5` 原本已配置。
三台机部署前均备份 `~/.myas/settings.conf`。

### 测试包（`/tmp`，测试后保留）

| 包 | SHA256 |
| --- | --- |
| `yashandb-23.4.14.105-linux-x86_64.tar.gz` | `e5bc0fe0a3f1c8a9ce1f66099ba644ff646c750867df637ea3f0af96f46e39b3` |
| `yashandb-23.5.4.100-linux-x86_64.tar.gz` | `8c08ade64dc426c8a495b93fbb6e4d19c389469de595ad954b9e058a886d1f88` |
| `yashandb-ai-23.5.4.100-linux-x86_64.tar.gz` | `433cc775d3f64aacbea5dfbb93a01544e3ca8d1e2776335235c64c1904368603` |
| `yashandb-23.4.14.105-linux-aarch64.tar.gz` | `5c9f02cedc98a2c8a51288246f7477ef4e3003efadb87bcbfba06687c92f5b7b` |
| `yashandb-23.5.4.100-linux-aarch64.tar.gz` | `c0ab7e3baed92904d721cf85bd7a56041cda146dfc8ef8af04f9e30cb525f71a` |
| `yashandb-ai-23.5.4.100-linux-aarch64.tar.gz` | `a245b093f7ae3b3a5c2d0d4cca8125aa5eb9539a32e9ac62e8d82025142802d8` |

### 包矩阵结果

每个实例均先 `--precheck` 再真实创建（同参数）；`18xxx` 段端口在创建前用 `ss` 确认空闲，
未改动 `YASOM_PORT_START`（`.4`=`1901`、`.13`=`1701`、`.5`=`1901`，测试全部显式指定端口）。

| 主机 | 架构 | 包 | 版本 | DB 端口 | 预检 | 部署 | 运行状态 | 结果 |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- |
| `192.168.23.4` | x86_64 | `yashandb-23.4.14.105-linux-x86_64` | `23.4.14.105` | 18003 | PASS | PASS | `open`/`normal`/`primary` | PASS |
| `192.168.23.4` | x86_64 | `yashandb-23.5.4.100-linux-x86_64` | `23.5.4.100` | 18007 | PASS | FAIL | 启动失败 | FAIL（环境） |
| `192.168.23.4` | x86_64 | `yashandb-ai-23.5.4.100-linux-x86_64` | `23.5.4.100` | 18011 | PASS | FAIL | 启动失败 | FAIL（环境） |
| `192.168.23.13` | x86_64 | `yashandb-23.4.14.105-linux-x86_64` | `23.4.14.105` | 18003 | PASS | PASS | `open`/`normal`/`primary` | PASS |
| `192.168.23.13` | x86_64 | `yashandb-23.5.4.100-linux-x86_64` | `23.5.4.100` | 18007 | PASS | FAIL | 启动失败 | FAIL（环境） |
| `192.168.23.13` | x86_64 | `yashandb-ai-23.5.4.100-linux-x86_64` | `23.5.4.100` | 18011 | PASS | FAIL | 启动失败 | FAIL（环境） |
| `192.168.23.5` | aarch64 | `yashandb-23.4.14.105-linux-aarch64` | `23.4.14.105` | 18003 | PASS | PASS | `open`/`normal`/`primary` | PASS |
| `192.168.23.5` | aarch64 | `yashandb-23.5.4.100-linux-aarch64` | `23.5.4.100` | 18007 | PASS | FAIL | 启动失败 | FAIL（环境） |
| `192.168.23.5` | aarch64 | `yashandb-ai-23.5.4.100-linux-aarch64` | `23.5.4.100` | 18011 | PASS | FAIL | 启动失败 | FAIL（环境） |

| 覆盖项 | 主机 | 命令要点 | 结果 |
| --- | --- | --- | --- |
| GBK 字符集（普通包） | `.5` | `myas create rel234armgbk 23.4.14.105 --db-port 18015 --character-set GBK` | PASS，`ys18015.toml` 的 `CHARACTER_SET = "GBK"` |
| `--use-native-type` + MySQL（普通包） | `.5` | `--db-port 18019 --mysql --mysql-port 3316 --use-native-type` | PASS，`USE_NATIVE_TYPE = true`、`mysql_addr = "192.168.23.5:3316"`，`myas info` 显示 MySQL 端口 `3316` |
| MySQL（普通包） | `.13` | `--db-port 18015 --mysql --mysql-port 3307` | PASS，`mysql_addr = "192.168.23.13:3307"` |
| GBK（普通包） | `.13` | 挂在 `23.5.4.100` 实例上 | NOT RUN（该包在主机上无法启动，环境限制） |
| `--use-native-type` / MySQL（AI 包） | `.4`/`.13`/`.5` | 挂在 AI 包实例上 | NOT RUN（AI 包在主机上无法启动，环境限制） |

### 配置与路径验证

- 每个通过项的 `myas info` 版本与包版本一致，`listen_address` 使用指定目标 IP 与 `18xxx` 端口；
- `hosts.toml` 的 `path` 与 `<install-path>/<版本>` 一致（本次回归确认 `--db-version` 重写对
  `23.4.14.105` 这类版本是幂等的，目录名仍是 `23.4.14.105`）；
- `eval "$(myas env CLUSTER)"` 的 `YASDB_HOME` 软链接指向实际安装目录；
- `.4` 上 `--precheck` 后直接创建 12 次（三台机合计）均无 `instance already exists`，MYAS-023
  的“预检 → 直接创建”复测转为 **PASS**。

### `23.5.4.100` / AI 包失败根因（环境限制，非 myas/yinstall 缺陷）

| 主机 | 平台 | 关键报错 |
| --- | --- | --- |
| `192.168.23.4` | CentOS 7，系统 OpenSSL `1.0.2k-fips`，无 `libssl.so.1.1` | `YAS-00509 failed to load dynamic library .../libyspi_curl.so, libssl.so.1.1: cannot open shared object file` |
| `192.168.23.13`、`192.168.23.5` | Kylin V10，`openssl-libs-1.1.1f` | `YAS-00509 ... lib/libcrypto_yas.so: version 'OPENSSL_1_1_1f' not found (required by /usr/lib64/libssl.so.1.1)` |

在 `.13`/`.5` 上核对了版本节点：系统 `libcrypto.so.1.1.1f` 与 `libssl.so.1.1.1f` 都导出
`OPENSSL_1_1_1f`，而 `23.5.4.100` 包内 `third/openssl/libcrypto.so.1.1` 的版本节点最高到
`OPENSSL_1_1_1e`/`OPENSSL_1_1_1h`、**没有** `OPENSSL_1_1_1f`；`libyspi_curl.so` 通过
`libcrypto_yas.so` 解析到包内 libcrypto 后，与主机 `libssl.so.1.1` 要求的 `OPENSSL_1_1_1f`
对不上。同一批主机上行情的 `23.5.6.100`（`.5:ys1911`、`.13:ys19007`）均 RUNNING，说明这是
`23.5.4.100`/AI `23.5.4.100` 这两个构建包与环境组合的限制，与本次代码改动无关（MYAS-024）。

### 现场保留与清理

- 三台机 `/tmp` 的六个测试包全部保留；每实例日志在 `/tmp/release-test-0.3.14/<端口>.log`；
- 通过项实例保留并 RUNNING：`.4:ys18003`、`.13:ys18003/ys18015(mysql)`、`.5:ys18003/ys18015(gbk)/ys18019(mysql+native)`；
- 失败项实例登记为 `FAIL`、现场未删除：`.4:ys18007/ys18011`、`.13:ys18007/ys18011`、`.5:ys18007/ys18011`，待确认后按实例逐一清理；
- `.5` 的 `ys1919`（`27.1.1.2-356-gd953d3665a9`）为本次任务要求的正式安装实例，保留不动。

### 结论（2026-10-12）

单机代码路径 `PASS`：三台机 `myas 0.3.14` 部署、预检、普通包 `23.4.14.105` 创建、
GBK / `--use-native-type` / MySQL 参数下发、环境变量与目录命名全部通过；MYAS-023 复测转为 PASS。
但 `23.5.4.100` 与 AI `23.5.4.100` 六个矩阵项在主机上均因 OpenSSL 版本节点不匹配无法启动，
主备端到端（YINSTALL-010）与 AI 包参数覆盖 `NOT RUN`。按 `myas/docs/RELEASE.md` 与
`release-test.md`，最终结论为 **`PARTIAL`**：`v0.3.14` 保持非正式候选（pre-release），
待主机 OpenSSL 或 `23.5.4.100` 构建包修复后重新复测，方可提升为正式 Release。

### 追加：`23.5.6.100` 复测（2026-10-12，用户要求）

目的：确认前述 OpenSSL 限制是否只影响 `23.5.4.100` 这两个构建包。包来自
`/mnt/d/share/0_package`（`23.5.6.100` 不在 `release-test.md` 的固定六包矩阵内），
分发到各机 `/tmp` 后核对 SHA256 一致：
`10978870012a53cf109df930c03afde7cac7c79d40f7d20643501e32eb93d4e2`（x86_64）、
`79a05fac1e4e7a9ad10024e58556368f77524fabd87623fa976a70e3ecb86d12`（aarch64）。

| 主机 | 架构 | 包 | 版本 | DB 端口 | 预检 | 部署 | 运行状态 | 结果 |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- |
| `192.168.23.4` | x86_64 | `yashandb-23.5.6.100-linux-x86_64` | `23.5.6.100` | 18003 | PASS | PASS | `open`/`normal`/`primary` | PASS |
| `192.168.23.13` | x86_64 | `yashandb-23.5.6.100-linux-x86_64` | `23.5.6.100` | 18003 | PASS | PASS | `open`/`normal`/`primary` | PASS |
| `192.168.23.5` | aarch64 | `yashandb-23.5.6.100-linux-aarch64` | `23.5.6.100` | 18003 | PASS | PASS | `open`/`normal`/`primary` | PASS |

三台机 `yasdb-home` 目录名均为 `23.5.6.100`，`myas info` 版本与包版本一致。

根因对照（`.4` 完全没有系统 `libssl.so.1.1`，仍启动成功，是最强的对照组）：

- `23.5.4.100` 包内 `third/openssl/` 是 **OpenSSL 1.1.1**（`libcrypto.so.1.1`），其版本节点缺
  `OPENSSL_1_1_1f`，与主机 `libssl.so.1.1` 要求的节点对不上（Kylin 1.1.1f 主机报
  `version 'OPENSSL_1_1_1f' not found`），CentOS 7 主机则根本没有 `libssl.so.1.1`；
- `23.5.6.100` 包内 `third/openssl/` 已换成 **OpenSSL 3**（`libcrypto.so.3`、`libssl.so.3`），
  且 `lib/libcrypto_yas.so -> ../third/openssl/libcrypto.so.3`、`libssl_yas.so ->
  ../third/openssl/libssl.so.3`，不再依赖主机 `libssl.so.1.1`。

结论：MYAS-024 记录的限制在 **`23.5.6.100` 构建上已修复**（自带 OpenSSL 3），与主机系统
OpenSSL 无关；`23.5.4.100` / AI `23.5.4.100` 仍失败。由于 `release-test.md` 的固定矩阵
仍包含 `23.5.4.100` 与 AI `23.5.4.100`，本次发布门禁结论保持 `PARTIAL`；若后续把矩阵包
更新为自带 OpenSSL 3 的构建（如 `23.5.6.100`），可按 `release-test.md` §10 重新评估提升为
正式 Release。AI 形态目前没有对应的 `23.5.6.100` 包，AI 覆盖仍为 `NOT RUN`。

复测实例（`.4:ys18003`、`.13:ys18003`、`.5:ys18003`，均为 `23.5.6.100`）现场保留待确认后清理；
日志在各机 `/tmp/release-test-0.3.14/2356100.log`。

## 2026-10-12 myas 0.3.16 组合包发布测试（.4 / .5 / .13 / 192.168.33.10）

对象：`myas-0.3.16.tar.gz`（myas `0.3.16` + 内置 yinstall `0.4.11`），提交 `23b54b2`，
tag `v0.3.16`，SHA256 `1d9a86b1cccd58d1e661171ec0d41cb0c7c997f4598d2ab14b32a4b7c5c3639c`。
本次变更是 `myas list` / `myas info` 的显示与实例登记字段（`CHARSET` 列、`CUR` 列、版本列
截断、`character_set` 字段），未改动安装、端口分配和 yinstall 流程。
部署方式为 `myas/docs/release/07` 的公开包路径，未使用会重建 `psftdb` 的 `tools/release.sh`。
GitHub Release 按结论标记为 **pre-release 候选**。

### 自动化测试

`bash -n`（myas + yinstall）、`myas/tests/test_cli.sh`、`yinstall/tests/test_cli.sh`、
`yinstall/tests/test_ports.sh` 全部返回 `0`。`test_cli.sh` 新增用例覆盖：`CHARSET` 列位置与
表头顺序、`CUR` 列的 `[*]` 标记、字符集的两处取值来源（登记值 / `<stage-dir>/<cluster>.toml`）、
内部构建版本列截断与 `REMARKS` 补齐、`--character-set` 大写规范化与非法值拒绝、
`instances.tsv` 第 17 字段持久化、16 字段旧记录兼容。

### 工具部署

| 主机 | 架构 | 部署前 | 部署后 | 既有实例 |
| --- | --- | --- | --- | --- |
| `192.168.23.4` | x86_64 | `0.3.15` | `0.3.16` / yinstall `0.4.11` | 5 个未改动（`ys1903`/psftdb、`ys1907`/gbkdb、`ys1950`、`ys1960`、`ys1911`/szsw） |
| `192.168.23.5` | aarch64 | `0.3.16`（当日早先部署） | 同上 | 7 个未改动（含 `ys1919`、`ys1927` 的 `27.1.1.2-356-gd953d3665a9`） |
| `192.168.23.13` | x86_64 | `0.3.14` | 同上 | 4 个未改动；`tpcc` 未触碰 |
| `192.168.33.10`（`yac2`） | aarch64 | `0.3.12` | 同上 | 2 个未改动（`ys1903`、`ys1907`） |

四台机 `/tmp/myas-0.3.16.tar.gz` 的 SHA256 与 Release 资产一致
（`1d9a86b1cccd58d1e661171ec0d41cb0c7c997f4598d2ab14b32a4b7c5c3639c`，已下载资产比对）。
部署前均备份 `~/.myas/settings.conf`；`YINSTALL_BIN` 仍指向
`~/.local/opt/myas/current/yinstall/yinstall.sh`；四台机的 `~/.bashrc` 原本都已加载
`myas shell-init`，本次未改动任何 shell 配置。

### 显示路径验证（只读）

| 主机 | 验证项 | 结果 |
| --- | --- | --- |
| `.5` | 7 个实例的 `CHARSET` 列 | 全部 `UTF8`（取自 `<stage-dir>/<cluster>.toml` 的 yasboot 默认值）；`ys1919`/`ys1927` 的 `VERSION` 为 `27.1.1.2-356`，完整构建号由 `REMARKS` 补齐 | PASS |
| `.4` | `ys1907`/gbkdb 与其余实例 | `GBK` 与 `UTF8` 正确区分 | PASS |
| 四台机 | `myas info CLUSTER` | 新增 `Character set` 行，`Version` 仍为完整版本号 | PASS |
| 四台机 | `myas env CLUSTER`、`myas alias` | 环境变量正确，别名数量与登记一致（5/7/4/2） | PASS |
| 四台机 | `myas config show` | `SYS_PASSWORD` 掩码，`ARCH`/`YINSTALL_BIN` 正确 | PASS |

### 创建路径预检（只读，未创建实例）

`.4`（x86_64，`23.4.14.105` x86_64 包）与 `.5`（aarch64，`23.4.14.105` aarch64 包）各执行一次
`myas create rel-charset-* 23.4.14.105 --local --host-ip HOST --db-port 18003
--character-set gbk --precheck`：

- 两次均返回 `0`，输出 `Plan checked by yinstall; no instance registration was kept.`；
- `~/.myas/instances.tsv` 未残留 `rel-charset-*` 登记；
- `--character-set latin1` 在 `.5` 上以退出码 `1` 拒绝，提示
  `--character-set must be ASCII, ISO88591, GBK, UTF8, or GB18030`；
- 小写 `gbk` 被规范化为 `GBK`（`yinstall` 取值校验通过）。

### 未执行项

- 包矩阵的真实创建（`release-test.md` §5/§6）`NOT RUN`：本次未获实例创建授权，只做只读预检；
- “`--character-set` 写入登记 → `myas list` 显示 `GBK`”的端到端路径目前仅由 `test_cli.sh` 覆盖，
  真实主机未创建带字符集的实例；
- `tools/release.sh` 未执行（会删除并重建 `.4` 的 `psftdb`，需单独确认）；
- 主备测试（§8）`NOT RUN`，本次变更与主备无关。

### 结论（2026-10-12）

自动化测试与四台主机的部署、显示路径、环境变量验证均为 `PASS`，未发现回归；创建路径的
参数解析、字符集校验和登记写入/清理由只读预检与自动化测试覆盖。真实创建矩阵 `NOT RUN`，
按 `myas/docs/RELEASE.md` 第 1 节，本次结论为 **`PARTIAL`**，`v0.3.16` 以 pre-release 候选
形式发布。在 `.4` 或 `.5` 完成一次带 `--character-set GBK` 的真实创建并确认 `myas list`
显示 `GBK` 后，可提升为正式 Release。
