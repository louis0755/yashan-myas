# 步骤 4：执行发布环境测试

## 前置条件

- 步骤 3 为 `PASS`；
- 用户已授权访问测试主机并执行真实部署；
- 测试账户、sudo、磁盘和数据库包满足要求。

没有真实主机授权时，本步骤状态为 `BLOCKED`，不能把自动化测试替代为正式发布
环境测试。

## 操作

严格按照根目录 `myas/docs/release-test.md` 执行：

1. 主机和架构预检；
2. 数据库包分发与 SHA256 核对；
3. 端口占用检查；
4. 在每台目标主机本地安装并运行 `myas`，使用 `myas create --local` 完成对应架构和数据库包矩阵测试（不支持 `myas create --target`）；
5. 实例状态、监听地址、配置和环境变量验证；
6. 涉及主备的版本在主节点本地使用产品 `yasboot` 创建主备并执行恢复验证，不通过 `myas` 远程创建备节点；
7. 保留失败现场并按实例范围清理。

所有真实安装命令先执行 `--precheck`。预检出现 `FAIL` 时不得继续安装。

## 端口段与配置恢复

`18xxx`、`19xxx` 是测试 `myas` 本身专用的端口号范围。测试前备份 `~/.myas/settings.conf`
并记录 `YASOM_PORT_START` 原值，测试结束后把 `YASOM_PORT_START` 改回原值或恢复备份，
禁止把测试端口段遗留成主机生产配置。详见根目录 `myas/docs/release-test.md` 第 4 节。

## 更新报告

在 `myas/docs/release-test-report.md` 中记录：

- 日期、commit、myas 版本和 yinstall 版本；
- 主机、操作系统、架构和资源；
- 数据库包名称及 SHA256；
- 执行命令，密码必须脱敏；
- 每个测试项的 `PASS`、`FAIL` 或 `NOT RUN`；
- 缺陷、修复提交、遗留现场和最终结论。

## 停止条件

- 架构与数据库包不匹配；
- 包校验值不一致；
- 预检或部署失败；
- 关键测试未运行；
- 报告结论为 `PARTIAL` 或 `FAIL`。

## 完成条件

`myas/docs/release-test-report.md` 信息完整且最终结论为 `PASS`。
