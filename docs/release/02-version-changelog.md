# 步骤 2：更新版本和变更记录

## 前置条件

步骤 1 为 `PASS`，目标版本已经确定。

## 操作

版本使用三段数字格式：

```bash
MYAS_VERSION=0.3.8
[[ ${MYAS_VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
printf '%s\n' "${MYAS_VERSION}" > myas/VERSION
```

在 `myas/CHANGELOG.md` 顶部增加：

```markdown
## 0.3.8 - YYYY-MM-DD

### 新增

- 用户可见的新功能。

### 修复

- 修复的问题及问题编号。
```

只保留实际存在的分类，分类可使用“新增”“变更”“修复”“安全”。
若 yinstall 有独立变更，同时更新其 `VERSION` 和变更记录。

## 校验

```bash
cat myas/VERSION
head -40 myas/CHANGELOG.md
git diff --check
git diff -- myas/VERSION myas/CHANGELOG.md
```

确认版本与 CHANGELOG 首个条目一致，日期为实际发布日期。

## 停止条件

- 版本格式不正确；
- CHANGELOG 包含未验证或未纳入发布的功能；
- 组件发生变化但无法确定其版本。

## 完成条件

版本文件和变更记录一致，`git diff --check` 通过。
