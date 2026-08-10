# 需求清单

## 已确认

- `myas` 与 `yinstall` 分别维护为独立 Git 仓库。
- 由可配置的 `CLUSTER_PREFIX` 和数据库端口推导集群名。
- 根据版本、`PACKAGE_DIR` 和 `ARCH` 生成默认软件包路径。
- 由可配置的 `YASOM_PORT_START` 分配本地四端口组。
- 由全局 `SYS_PASSWORD` 向 `yinstall` 提供部署所需的 sys 密码。
- 将安装和 TOML 处理委托给 `yinstall`。

## 后续

- 使用真实 YashanDB 软件包增加虚拟机集成测试。
- 为控制机和数据库主机分离的场景定义远程生命周期操作。
