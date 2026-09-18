# 步骤 5：打包和校验

## 前置条件

步骤 3 和步骤 4 均为 `PASS`。

## 生成公开包

```bash
MYAS_VERSION=$(<myas/VERSION)
rm -f -- "myas/dist/myas-${MYAS_VERSION}.tar.gz"
myas/tools/package.sh
sha256sum "myas/dist/myas-${MYAS_VERSION}.tar.gz" \
  | tee "myas/dist/myas-${MYAS_VERSION}.tar.gz.sha256"
```

## 检查内容

```bash
tar -tzf "myas/dist/myas-${MYAS_VERSION}.tar.gz"
tar -xOzf "myas/dist/myas-${MYAS_VERSION}.tar.gz" \
  "myas-${MYAS_VERSION}/VERSION"
tar -xOzf "myas/dist/myas-${MYAS_VERSION}.tar.gz" \
  "myas-${MYAS_VERSION}/yinstall/VERSION"
tar -xOzf "myas/dist/myas-${MYAS_VERSION}.tar.gz" \
  "myas-${MYAS_VERSION}/lib/myas-common.sh" \
  | rg -F '__MYAS_SYS_PASSWORD__'
```

包内不得包含 `.git`、测试目录、日志、`dist`、凭据或机器实例状态。

## 解包冒烟

```bash
RELEASE_TMP=$(mktemp -d)
tar -xzf "myas/dist/myas-${MYAS_VERSION}.tar.gz" -C "${RELEASE_TMP}"
MYAS_CONFIG_DIR="${RELEASE_TMP}/config" \
  "${RELEASE_TMP}/myas-${MYAS_VERSION}/myas.sh" --version
MYAS_CONFIG_DIR="${RELEASE_TMP}/config" \
  "${RELEASE_TMP}/myas-${MYAS_VERSION}/myas.sh" list
"${RELEASE_TMP}/myas-${MYAS_VERSION}/yinstall/yinstall.sh" --version
rm -rf -- "${RELEASE_TMP}"
```

## 完成条件

- 文件名、目录名和 `myas/VERSION` 一致；
- 内置 yinstall 版本与发布记录一致；
- 密码占位符存在；
- SHA256 文件已生成；
- 解包冒烟全部通过。

此处生成的是公开包。不得在该包中注入现场密码。
