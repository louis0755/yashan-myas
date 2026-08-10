# myas

`myas` 是本地 YashanDB 多实例管理工具。它保存实例信息、切换环境和执行
生命周期操作；安装、TOML 修改和 yasboot 调用由独立的 `yinstall` 完成。

## 默认配置

首次运行会创建 `~/.myas/settings.conf`：

```text
BASE_DIR=/data/yashan
CLUSTER_PREFIX=ys
PACKAGE_DIR=/data/software
ARCH=x86_64
YASOM_PORT_START=1701
SYS_PASSWORD=__MYAS_SYS_PASSWORD__
```

未传 `--db-port` 时，`myas` 从 `YASOM_PORT_START` 开始每次递增 4，选择首个
不与已登记实例重叠的端口组。默认首组为 `1701/1702/1703/1704`，其中数据库
端口为 `1703`、集群名为 `ys1703`。可用
`./myas.sh config set YASOM_PORT_START 1801` 修改起始 Yasom 端口。

`SYS_PASSWORD` 是部署时的 sys 密码。公开源码和发布包只保留占位符，部署流程在
目标机注入实际值。也可用 `./myas.sh config set SYS_PASSWORD '新密码'` 修改。
`myas` 会将它传给 `yinstall`，配置显示时会掩码该值，且设置文件仅当前用户可读写。

`yinstall` 使用独立仓库维护。组合发布包可将它放在 `myas/yinstall/`，但 myas
源码仓库不跟踪该目录：

```text
myas/
  myas.sh
  lib/
  yinstall/
    yinstall.sh
    lib/
    steps/
```

`YINSTALL_BIN` 未显式配置时，`myas` 依次查找配置目录中的
`yinstall/yinstall.sh`、上述内置目录、同级 `yinstall.sh`/`yinstall`，以及 PATH 中的
`yinstall`/`yinstall.sh`。已有配置中的 `YINSTALL_BIN` 仍优先使用。

实例目录固定为：

```text
/data/yashan/ys1703/yasdb-home
/data/yashan/ys1703/yasdb-data
/data/yashan/ys1703/yasdb-log
```

## 使用

本地单机是默认模式，不需要 SSH 参数或数据库管理员密码：

```bash
./myas.sh create appdb 23.4.14.100
./myas.sh create appdb2 23.4.14.100 --db-port 1803
./myas.sh
eval "$(./myas.sh shell-init)"
ys1703
```

远程部署必须显式提供目标主机；sys 密码同样读取全局配置：

```bash
./myas.sh create remote-db 23.4.14.100 --target 192.168.23.4 \
  --db-port 1803
```

切换环境后可使用 `ystatus`、`ystart`、`yshutdown` 和 `yrestart`。运行
`tests/test_cli.sh` 执行快速 CLI 测试。

问题登记在 `ISSUES.md`，使用 `MYAS-NNN` 编号，并同步到 GitHub
`louis0755/yashan-myas`。每次发布需递增 `VERSION`、更新变更记录、打包、计算
SHA256，并创建同名 Git tag 和 Release。
