# 步骤 3：执行自动化测试

## 前置条件

步骤 2 为 `PASS`。

## 操作

从仓库根目录执行完整门禁：

```bash
bash -n myas/myas.sh myas/lib/*.sh myas/tests/*.sh
bash -n yinstall/yinstall.sh yinstall/lib/*.sh \
  yinstall/steps/*.sh yinstall/tests/*.sh
bash myas/tests/test_cli.sh
bash yinstall/tests/test_cli.sh
bash yinstall/tests/test_ports.sh
bash yinstall/yinstall.sh --help >/dev/null
TEST_CONFIG_DIR=$(mktemp -d)
MYAS_CONFIG_DIR="${TEST_CONFIG_DIR}" myas/myas.sh list
rm -rf -- "${TEST_CONFIG_DIR}"
```

`myas list` 必须使用临时 `MYAS_CONFIG_DIR`，不得读写用户真实实例配置。

## 结果记录

逐条记录命令、退出码和测试汇总。所有命令必须返回 `0`。若修复了任何问题，
必须从第一条开始重新执行完整门禁。

## 失败处理

1. 保存失败命令和关键输出；
2. 判断是代码缺陷、测试缺陷还是环境依赖；
3. 只在用户要求修复或发布任务包含修复时修改代码；
4. 修复后重新运行全部命令，不得只运行失败测试。

## 完成条件

全部语法检查、CLI 测试、端口测试和非破坏性冒烟命令返回 `0`。
