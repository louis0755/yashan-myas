# 测试验证手册

本文覆盖 `myas`、`yinstall` 以及目标主机 `192.168.23.4` 的本地单机验证。

## 1. 静态检查和自动化测试

在仓库根目录执行：

```bash
bash -n myas/myas.sh myas/lib/*.sh myas/tests/*.sh
bash -n yinstall/yinstall.sh yinstall/lib/*.sh yinstall/steps/*.sh yinstall/tests/*.sh
myas/tests/test_cli.sh
yinstall/tests/test_cli.sh
yinstall/tests/test_ports.sh
```

所有命令应返回 `0` 并输出 `passed`。测试使用临时目录和假的外部程序，不安装
数据库。覆盖内容包括本地模式不调用 SSH/SCP、生成时使用 `-N`、部署时传递 sys 密码、端口组推导、
可配置起始 Yasom 端口、自动连续分配、失败状态及环境切换。

## 2. 目标主机预检

登录 `192.168.23.4` 后执行：

```bash
sudo -n true
test -f /data/software/yashandb-23.4.14.100-linux-x86_64.tar.gz
cd /home/ganlu/ai/myas/myas
./yinstall/yinstall.sh db install --local \
  --package /data/software/yashandb-23.4.14.100-linux-x86_64.tar.gz \
  --db-admin-password '替换为实际 sys 密码' \
  --cluster ys1703 --db-port 1703 \
  --install-path /data/yashan/ys1703/yasdb-home \
  --data-path /data/yashan/ys1703/yasdb-data \
  --log-path /data/yashan/ys1703/yasdb-log \
  --stage-dir /data/yashan/ys1703/install --precheck
```

预检成功后，在 `myas/` 目录执行 `./myas.sh create appdb 23.4.14.100`。

## 3. 部署后验证

```bash
./myas.sh
./myas.sh info ys1703
./myas.sh status ys1703
ss -lntp | grep -E ':1701|:1702|:1703|:1704'
test -d /data/yashan/ys1703/yasdb-home
test -d /data/yashan/ys1703/yasdb-data
test -d /data/yashan/ys1703/yasdb-log
grep -E 'LISTEN_ADDR.*:1701|LISTEN_ADDR.*:1702' /data/yashan/ys1703/install/hosts.toml
```

最后执行 `eval "$(./myas.sh shell-init)"`、`ys1703` 和 `ystatus`，确认当前 Shell
中的 `YASHANDB_CLUSTER=ys1703`、`YASHANDB_PORT=1703`、`YASDB_HOME` 路径正确。
