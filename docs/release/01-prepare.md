# 步骤 1：确定发布范围

## 目标

确认工作区、组件版本、待发布变更和敏感文件风险。

## 操作

```bash
cd /home/ganlu/ai/myas
git status --short
git branch --show-current
git remote -v
cat myas/VERSION
cat yinstall/VERSION
sed -n '1,120p' myas/CHANGELOG.md
```

检查可能误入版本控制的内容：

```bash
git status --short -- .release dist logs
git ls-files | rg '(^|/)(\.release|dist|logs)/|\.(key|pem)$'
```

`git ls-files` 没有匹配时，`rg` 可能返回 `1`，这表示未发现匹配，不是故障。

## 必须确认

- 发布的是 myas、yinstall，还是两者组合版本；
- 目标 myas 版本和内置 yinstall 版本；
- 哪些提交、问题编号和用户可见变化属于本次发布；
- 当前修改是否来自用户，不能擅自覆盖或丢弃；
- `origin` 是否为计划发布的远端仓库。

## 停止条件

- 存在来源不明或相互冲突的代码修改；
- 发现已跟踪的凭据、私钥、数据库包或生产日志；
- 无法确定目标版本或发布范围；
- 远端仓库与预期不一致。

## 完成条件

发布范围、目标版本、组件版本和现有工作区修改均已记录。
