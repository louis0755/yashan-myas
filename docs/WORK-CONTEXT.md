# 继续工作记录

更新时间：2026-08-27

## 当前目标

维护 `myas`/`yinstall` 的 YashanDB 部署功能。主备部署必须在一次
`yasboot package se gen` 中生成，不使用后置 `cluster join`。未提供主机密码时，
执行主机必须能以 BatchMode SSH 免密连接所有备机。

## 已完成

- `myas create` 支持 `--standbys HOST[,HOST...]` 并透传给 yinstall。
- `yinstall db install` 支持 `--standbys`。
- 主备模式要求远程目标、显式 `--host-ip`，并校验备机列表。
- 部署开始前执行 `B-000`：在目标主机上检查到每台备机的免密 SSH。
- Yasboot 生成使用 `-N/--no-password`，不再错误地把数据库 sys 密码作为 SSH 密码。
- 主备生成参数为：
  `--ip PRIMARY,STANDBY... --node N --standby-node N-1`。
- 单机未指定 `--host-ip` 时继续使用目标机运行时探测地址。
- README、CHANGELOG、release 测试规范和自动化测试已更新。

## 已推送提交

- `yashan-myas`：`2fefbdc Add one-shot standby create`
- `yashan-yinstall-bash`：`8e7d2c8 Add one-shot standby generation`

两个嵌套仓库均已推送到各自 `origin/master`。

## 已验证

以下命令均通过：

```bash
bash -n myas/myas.sh myas/lib/*.sh yinstall/yinstall.sh \
  yinstall/lib/*.sh yinstall/steps/*.sh
bash myas/tests/test_cli.sh
bash yinstall/tests/test_cli.sh
bash yinstall/tests/test_ports.sh
```

已验证控制端到主机、以及 `192.168.23.4` 上 `yashan` 到
`192.168.23.13` 上 `yashan` 的免密 SSH。测试输出确认生成命令包含双 IP、
`--node 2 --standby-node 1` 和 `BatchMode=yes`。

## 测试主机状态

- `192.168.23.4`：x86_64、CentOS 7，已有 `ys1903`、`ys1907`、`ys18007` 等实例。
- `192.168.23.13`：x86_64、Kylin V10，已有独立 `tpcc` 实例，禁止清理或修改。
- `192.168.23.5`：aarch64 测试主机，状态需重新检查。
- 三个 x86_64 测试包已复制到 `.4` 和 `.13` 的 `/tmp`，测试后不要删除。
- `.4` 上曾使用 `ys18031` 做预检；预检因目录尚未创建而按预期终止，未执行部署。

## 尚未完成

1. 用已发布的新版本在 `.4`/`.13` 真实执行一次全流程一主一备部署，建议使用新的端口组和集群名，避免现有实例。
2. 检查生成的 `hosts.toml` 与集群 TOML 是否包含两台主机、角色、指定公网 IP 和复制端口。
3. 执行 `yasboot cluster status -c CLUSTER -d`，验证 primary/standby、normal 状态及复制。
4. 做一次主备停止、启动恢复测试，并更新 `myas/docs/release-test-report.md`；该报告目前仍包含旧的 join 方式失败记录。
5. 如需重新发布组合包，使用：

```bash
YINSTALL_SOURCE=/home/ganlu/ai/myas/yinstall \
  myas/tools/release.sh 0.3.7
```

发布脚本需要 `myas/.release/myas.env` 权限为 `600`，不要提交该文件或任何密码。

## 工作区注意事项

根仓库存在用户已有的未提交/未跟踪文件（例如 `myas/docs/DEPLOYMENT.md`、`myas/docs/release-test.md`、
`myas/.release/`、`myas/dist/`、`myas/logs/` 等），不要回滚、删除或覆盖。提交时优先在对应嵌套
仓库中操作；根目录文档变更需单独确认是否提交。

## 推荐恢复顺序

1. 阅读本文件、`myas/docs/release-test.md` 和 `myas/docs/release-test-report.md`。
2. 检查两个嵌套仓库 `git status` 与远端同步状态。
3. 先执行主备 SSH、端口和实例冲突预检，再进行真实部署。
4. 保留失败现场和日志，禁止清理 `.13` 的 `tpcc` 或现有非测试实例。
