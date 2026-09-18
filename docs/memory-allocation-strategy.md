# 测试实例内存分配策略（单机 SE）

来源：YashanDB 官方文档与 Support 知识（经 `yai-mcp` 知识库检索），2026-09-18 定稿。

## 适用场景

- 单机（`SE`）测试库，表类型为默认 `HEAP`（`ys1903`、`ys1907` 均为此类型）。
- 输入是"请求内存" `M`，即集群 TOML 里 `[[group.node]]` 的 `memory_limit`（yinstall 0.4.9
  起按"覆盖请求值的最小 1% 边界值"写入，见 YINSTALL-012）。
- 目标：让数据库内存池合计接近 `M`，而不是停留在产品的保守推荐值。

## 官方依据

- 数据库配置调优（单机、HEAP）：`DATA_BUFFER_SIZE` 建议占 80% 左右，`VM_BUFFER_SIZE` 按业务分配，
  `COLUMNAR_BUFFER_SIZE` 与 `COLUMNAR_DATA_BUFFER_PERCENT` 使用默认值。
- 参数大小：资源相关参数不能设置太大，否则会因申请不到资源导致数据库启动失败。
- `SHARE_POOL_SIZE`：默认 320M，范围 `[256M,64T]`，并发业务多时建议调大；在线只能扩大。
- `VM_BUFFER_SIZE`：默认 128M，范围 `[8M,2T]`，排序/物化/JOIN 数据量大时建议调大；在线只能扩大。
- `DATA_BUFFER_SIZE`：默认 256M，范围 `[32M,64T]`，建议至少 1G。
- `MEX_POOL_SIZE`（默认 512M）、`LARGE_POOL_SIZE`、`PQ_POOL_SIZE`、`WORK_AREA_POOL_SIZE`、
  `WORK_AREA_HEAP_SIZE`（默认 512K）等：按产品推荐值保留即可。
- `DBMS_PARAM.OPTIMIZE(write, table_type, memory_percent, cpu_percent)` 是产品自带的推荐参数入口
  （示例：`EXEC DBMS_PARAM.OPTIMIZE(TRUE, 'TAC', 80);`），数据库最小可用内存 1.5G。

## 分配公式

记：

- `M`：节点 `memory_limit`（MB）
- `F`：固定池合计 = 当前内存合计 − `DATA_BUFFER_SIZE` − `VM_BUFFER_SIZE` − `SHARE_POOL_SIZE`
  （含 MEX/LARGE/PQ/WORK_AREA_POOL/COLUMNAR/REDO、会话相关 `WORK_AREA_HEAP_SIZE × MAX_SESSIONS`、
  `WORK_AREA_STACK_SIZE`、private log buffer、reserved 等）
- `V = 0.95 × (M − F)`：可分配给三大动态池的预算（留 5% 余量，避免申请不到资源启动失败）

目标值：

| 参数 | 取值 | 说明 |
| --- | --- | --- |
| `DATA_BUFFER_SIZE` | `0.80 × V` | 官方 HEAP 建议：占大头（约 80%） |
| `VM_BUFFER_SIZE` | `0.10 × V` | 计算用（排序/物化/JOIN），不低于 128M |
| `SHARE_POOL_SIZE` | `0.10 × V`，且 ≥ `320M` | 执行计划/数据字典等共享缓存 |
| 其余参数 | 保持推荐/默认值 | 不随内存请求变化 |

结果：内存池合计 ≈ `0.95 × (M − F) + F`，约为 `M` 的 95%–97%；若当前合计已达该区间，无需改动。

## 应用步骤

```bash
# 1) 读当前值，算 F / V / 目标值（见上表）
eval "$(myas env CLUSTER)" >/dev/null 2>&1
printf "select regexp_replace(dbms_param.show_memory_limit(),' +',' ') from dual;\nexit\n" | yasql / as sysdba

# 2) 写入 SPFILE（数值可按目标值取整）
yasql / as sysdba <<'SQL'
ALTER SYSTEM SET DATA_BUFFER_SIZE=6219M SCOPE=SPFILE;
ALTER SYSTEM SET VM_BUFFER_SIZE=777M SCOPE=SPFILE;
ALTER SYSTEM SET SHARE_POOL_SIZE=777M SCOPE=SPFILE;
SQL

# 3) 重启实例并校验
myas restart CLUSTER
yasql / as sysdba -c "select dbms_param.show_memory_limit() from dual"
```

实测（`192.168.23.13`，主机内存 514599M）：

| 实例 | 请求 | M（节点上限） | 调整前合计 | 调整后合计 |
| --- | --- | --- | --- | --- |
| `ys1907`（23.5.6.100） | 10G | 10292M | 8.19221G（推荐值） | **9.72695G** |
| `ys1903`（23.4.7.113） | 100G | 102400M | 95.4504G | 95.4504G（已符合，未改动） |

## 注意事项

- `SHARE_POOL_SIZE`、`VM_BUFFER_SIZE` 在线只能扩大；要缩小必须改配置文件并重启。
- `MEX_POOL_SIZE` 修改不是立即生效，需要重启。
- 参数合计不得超过节点 `memory_limit`，否则实例可能启动失败。
- 该策略通过 SPFILE 落地，重启有效；`myas delete` + 重新 `create` 后会按产品推荐重新生成参数，
  届时需要重新应用（后续可以把该策略固化进 yinstall 的部署后步骤）。
- 同机多实例时按内存比例划分，并考虑设置 `os_memory_limit` 防止相互挤占（官方建议）。

## 引用

- 数据库配置调优（23.5.4）：https://doc.yashandb.com/yashandb/23.5.4/zh/All-Manuals/Performance-Tuning/Database-Performance-Fundamentals/Database-Configuration-Tuning.html
- 配置参数 DATA_BUFFER_SIZE / VM_BUFFER_SIZE / SHARE_POOL_SIZE / MEX_POOL_SIZE（23.5.4）：https://doc.yashandb.com/yashandb/23.5.4/zh/All-Manuals/Reference-Manual/Configuration-Parameters.html
- DBMS_PARAM（OPTIMIZE / APPLY_RECOMMEND，23.5.4）：https://doc.yashandb.com/yashandb/23.5.4/zh/All-Manuals/Development-Guide/PL-Reference-Manual/Built-in-Advanced-PL-Packages/DBMS_PARAM.html
- Support 知识：YashanDB-SQL优化原则与实践指南（内存/缓存类参数表） https://support.yasdb.com/knowledge/YASDB-KB-YQRV-3EYA
