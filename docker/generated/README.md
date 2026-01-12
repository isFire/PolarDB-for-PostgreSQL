# Docker 构建目录

此目录包含自动生成的 Docker 构建文件。

## 生成的文件

- `Dockerfile.<os-version>` - 为特定 OS 版本生成的 Dockerfile
- `install-extensions-<os-version>.sh` - 为特定 OS 版本生成的扩展安装脚本
- `extensions-metadata-<os-version>.json` - 为特定 OS 版本生成的扩展元数据
- `build-args-<os-version>.sh` - 为特定 OS 版本生成的构建参数

## 生成方式

这些文件由以下脚本自动生成：

```bash
# 1. 解析扩展配置
python3 docker/scripts/parse-extensions.py --os ubuntu24.04

# 2. 生成 Dockerfile
bash docker/scripts/generate-dockerfile.sh --os ubuntu24.04
```

**注意**: 不要手动修改这些文件，因为它们会在下次构建时被覆盖。

## 清理

要清理生成的文件：

```bash
rm -rf docker/generated/*
```
