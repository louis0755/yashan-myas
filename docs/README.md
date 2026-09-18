# 操作文档索引

`myas/docs/` 保存供维护人员和智能体执行的操作手册。文档中的命令默认从工作区根目录
`/home/ganlu/ai/myas` 执行。

## 版本发布

按顺序阅读和执行：

1. [执行规则](release/00-agent-rules.md)
2. [确定发布范围](release/01-prepare.md)
3. [更新版本和变更记录](release/02-version-changelog.md)
4. [执行自动化测试](release/03-automated-tests.md)
5. [执行发布环境测试](release/04-release-test.md)
6. [打包和校验](release/05-package.md)
7. [提交、Tag 和 GitHub Release](release/06-publish.md)
8. [目标机部署和验证](release/07-deploy-verify.md)
9. [回滚](release/08-rollback.md)
10. [发布记录模板](release/release-record-template.md)

## 实例运维

- [测试实例内存分配策略](memory-allocation-strategy.md)：按官方文档给单机 SE 测试库分配
  `DATA_BUFFER_SIZE` / `VM_BUFFER_SIZE` / `SHARE_POOL_SIZE`，并给出应用与校验步骤。

总览见 [`myas/docs/RELEASE.md`](RELEASE.md)。测试标准见
[`myas/docs/release-test.md`](release-test.md)，日常测试见
[`myas/docs/TESTING.md`](TESTING.md)，用户部署说明见
[`myas/docs/DEPLOYMENT.md`](DEPLOYMENT.md)。

## 使用约定

- 严格按步骤顺序执行，除非文档明确标注为可选。
- 每一步都要保存命令、退出码和脱敏后的关键输出。
- 上一步未满足“完成条件”时，不得进入下一步。
- 不把密码、SSH key、数据库包、日志和实例状态提交到 Git。
- 对真实主机执行变更前，先执行文档规定的只读检查或预检。
- 文档与脚本不一致时，以脚本当前行为为事实，先停止发布并修正文档。
