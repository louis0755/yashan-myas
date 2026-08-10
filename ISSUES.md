# Issue Tracker

本仓库问题使用递增编号 `MYAS-NNN`，并同步到 GitHub 仓库 `louis0755/yashan-myas` 的对应 Issue。提交和关闭说明引用同一编号。

## MYAS-002 — YINSTALL_BIN 发现顺序覆盖 PATH 版本

- 发现：2026-08-10
- 错误信息：调用了错误的 yinstall 版本，测试 fake yinstall 未被使用。
- 影响：版本选择不可预测，可能调用错误的 installer。
- 状态：`FIXED`

## MYAS-003 — C-001 修复未进入 0.1.8 发布包

- 发现：2026-08-10
- 错误信息：`bash: line 10: syntax error: unexpected end of file`。
- 影响：源码修复没有随 0.1.8 发布包交付。
- 状态：`FIXED`

## MYAS-004 — C-005 TOML section 不匹配导致部署失败

- 发现：2026-08-10
- 错误信息：`missing LISTEN_ADDR in [om.config]`。
- 现象：发布脚本在目标机执行 `myas create psftdb 23.4.14.105` 时，C-005 修改端口配置失败。
- 影响：0.1.9 自动部署和实例创建未完成，不能发布通过状态的 tag/release。
- 状态：`OPEN`
- 复现：在目标机使用 0.1.9 包运行 `myas create psftdb 23.4.14.105`。
- 修复：待根据实际 yasboot 生成的 TOML section 兼容性调整。
- 验证：待补充目标机部署测试。

## MYAS-006 — 实例环境指向错误版本和数据目录

- 发现：2026-08-10
- 错误信息：`YAS-00402 failed to connect socket, errno 2, error message "No such file or directory"`。
- 现象：执行 `ys1903` 后调用了系统中的 yasql 23.5.2.2，无法本地 SYSDBA 连接 23.4.14.105 实例。
- 原因：`YASDB_HOME` 缺少版本目录，`YASDB_DATA` 缺少 `db-1-1`，PATH 指向不存在的目录。
- 状态：`FIXED`
- 修复：优先加载 yasboot 生成的集群 bashrc，缺失时使用版本目录和节点数据目录。
- 验证：CLI 回归测试和目标机 `yasql / as sysdba`。

## MYAS-007 — 当前 Shell 缓存旧版本 myas 函数

- 发现：2026-08-10
- 错误信息：切换 `current` 到 0.1.14 后，同一 Shell 中 `myas --version` 仍显示 0.1.13。
- 原因：`shell-init` 函数固定使用版本目录绝对路径。
- 状态：`FIXED`
- 修复：函数和实例别名优先调用稳定入口 `~/.local/bin/myas`，发布脚本清除旧函数和命令缓存。

## MYAS-008 — 默认密码进入 GitHub 历史和发布包

- 发现：2026-08-10
- 错误信息：敏感信息扫描发现源码、历史提交和 Release 包包含默认密码明文。
- 影响：可读取仓库历史或旧发布包的用户可能获得部署凭据。
- 状态：`FIXED`
- 修复：源码改为 `__MYAS_SYS_PASSWORD__` 占位符，部署时由本机配置注入；重建 Git 历史并删除旧 Release/tag。

## MYAS-009 — myas 仓库跟踪 yinstall 目录

- 发现：2026-08-10
- 错误信息：`git ls-tree HEAD` 显示 `yinstall` gitlink。
- 影响：两个独立项目耦合，发布边界不清晰。
- 状态：`FIXED`
- 修复：从 myas Git 树删除 yinstall，由发布工具从独立仓库组装。

## MYAS-010 — 支持按绝对内存配置部署

- 发现：2026-08-10
- 状态：`FIXED`
- 修复：新增全局 `MEMORY_SIZE` 和单次 `create --memory-size`，每次部署动态计算百分比。

## MYAS-011 — 删除数据库前强制交互确认

- 发现：2026-08-10
- 状态：`FIXED`
- 修复：新增 `myas delete`，展示 cluster、`YASDB_HOME`、`YASDB_DATA`，仅输入 `y` 执行。

## MYAS-013 — 已安装实例重部署未使用最新 yinstall 和 force 参数

- 发现：2026-08-10
- 错误信息：`instance already exists`、`yasom port ... is already used`。
- 原因：目标机仍是旧组合包，且 force 未传递到 yasboot。
- 状态：`IN PROGRESS`
- 修复：重新组装发布包并在重部署前停止实例。

## MYAS-014 — 删除未清理 yasboot 集群登记

- 发现：2026-08-10
- 错误信息：`file ~/.yasboot/ys1903.env is already exist`。
- 影响：删除实例后同名 cluster 无法重新部署。
- 状态：`FIXED`
- 修复：double-check 展示并删除 cluster 专属 `.env` 和 yasdb_home 软链接。

## MYAS-012 — 小绝对内存无法由整数百分比精确表达

- 发现：2026-08-10
- 错误信息：请求 `1G`，目标机总内存 `515250M`，yasboot 最小 `1%` 实际为约 `5152M`。
- 影响：绝对值小于目标机总内存 1% 时，只能向上取整，实际分配大于请求值。
- 状态：`FIXED`
- 修复：直接写入 `hosts.toml` 与集群 TOML 的绝对内存值，不再受百分比粒度限制。

## MYAS-015 — 默认启用推荐内存覆盖部署意图

- 发现：2026-08-10
- 错误信息：`node 1-1 memory_limit 1024M is less than 5152MB`。
- 现象：未明确要求推荐内存时仍生成 `recommend_param = true`，1G 配置被推荐参数校验限制为至少 5152M。
- 需求：默认采用生成配置；仅 `--recommend-memory` 启用推荐内存；`--memory-size SIZE` 按指定 M/G 绝对值写入。
- 状态：`FIXED`
- 修复版本：`0.2.2`
