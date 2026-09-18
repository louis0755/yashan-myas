# 步骤 8：回滚

## 触发条件

- 新版本无法启动或读取配置；
- 发布后关键实例管理功能异常；
- 验证结果与发布门禁不一致；
- 用户明确要求回滚。

回滚工具版本不等于回滚数据库。不得因工具回滚删除数据库目录或实例数据。

## 回滚前检查

```bash
PREVIOUS_VERSION=0.3.7
test -x "$HOME/.local/opt/myas/myas-${PREVIOUS_VERSION}/myas.sh"
readlink "$HOME/.local/opt/myas/current"
cp "$HOME/.myas/settings.conf" "$HOME/.myas/settings.conf.rollback.bak"
cp "$HOME/.myas/instances.tsv" "$HOME/.myas/instances.tsv.rollback.bak"
```

文件不存在时应先确认原因，不要用空文件覆盖。若新版本修改了配置格式，先确认旧版本
能够读取备份内容。

## 切换版本

```bash
ln -sfn "$HOME/.local/opt/myas/myas-${PREVIOUS_VERSION}" \
  "$HOME/.local/opt/myas/current"
hash -r
myas --version
myas list
```

## 验证

```bash
"$HOME/.local/opt/myas/current/yinstall/yinstall.sh" --version
myas info CLUSTER
myas status CLUSTER
```

如果回滚只涉及工具，不要修改运行中的数据库。记录回滚原因、新旧版本、执行时间、
配置备份路径和验证结果。

## 完成条件

`current` 指向旧版本，命令和实例登记可用，要求检查的实例状态正常。
