# PolarDB Docker Pipeline - 开发者指南

本文档面向开发者，说明如何扩展和维护 Docker 构建系统。

## 目录结构

```
docker/
├── extensions.yml              # 主配置文件
├── scripts/
│   ├── parse-extensions.py    # Python 配置解析器
│   ├── generate-dockerfile.sh # Shell Dockerfile 生成器
│   ├── extension-metadata.json # 扩展元数据
│   ├── entrypoint.sh          # 容器入口点
│   ├── init-extensions.sql    # 初始化 SQL
│   ├── scan-image.sh          # 安全扫描脚本
│   └── test-image.sh          # 镜像测试脚本
├── installers/
│   ├── install-ubuntu-extensions.sh  # Ubuntu 扩展安装器
│   ├── install-anolis-extensions.sh  # Anolis 扩展安装器
│   └── install-pigsty.sh              # Pigsty 安装器
├── templates/
│   ├── Dockerfile.ubuntu.tmpl         # Ubuntu Dockerfile 模板
│   └── Dockerfile.anolis.tmpl         # Anolis Dockerfile 模板
└── examples/                           # 配置示例
```

## 添加新扩展

### 1. 添加扩展元数据

编辑 `docker/scripts/extension-metadata.json`:

```json
{
  "your_extension": {
    "category": "polar|pigsty|spatial|custom",
    "description": "扩展描述",
    "dependencies": ["dep1", "dep2"],
    "os_support": {
      "ubuntu": ["20.04", "22.04", "24.04"],
      "anolis": ["8", "23"]
    },
    "package_name": {
      "ubuntu": "postgresql-15-your-ext",
      "anolis": "postgresql15_your_ext"
    },
    "build_from_source": true,
    "min_pg_version": "15",
    "max_pg_version": "17"
  }
}
```

### 2. 在配置中定义扩展集合

编辑 `docker/extensions.yml`:

```yaml
extension_sets:
  my_custom_set:
    - your_extension
    - existing_extension

default_sets: [my_custom_set]
```

### 3. 更新安装器（如需要）

**Ubuntu 安装器** (`installers/install-ubuntu-extensions.sh`):

在 `install_other_extensions()` 函数中添加特殊处理逻辑。

**Anolis 安装器** (`installers/install-anolis-extensions.sh`):

在 `pkg_map` 中添加 RPM 包名映射。

## 添加新 OS 版本支持

### 1. 创建 Dockerfile 模板

复制现有模板并修改:
```bash
cp docker/templates/Dockerfile.ubuntu.tmpl \
   docker/templates/Dockerfile.newos.tmpl
```

### 2. 创建扩展安装器

```bash
cp docker/installers/install-ubuntu-extensions.sh \
   docker/installers/install-newos-extensions.sh
```

### 3. 更新 GitHub Actions

编辑 `.github/workflows/docker-build.yml`，在矩阵中添加新 OS。

### 4. 更新生成脚本

编辑 `docker/scripts/generate-dockerfile.sh`，添加新 OS 的检测逻辑。

## 修改构建流程

### 解析器修改

文件: `docker/scripts/parse-extensions.py`

关键类: `ExtensionParser`

主要方法:
- `resolve_extensions()` - 解析扩展集合
- `apply_os_overrides()` - 应用 OS 覆盖
- `categorize_extensions()` - 扩展分类
- `generate_install_script()` - 生成安装脚本

### Dockerfile 模板修改

模板变量:
- `${UBUNTU_VERSION}` / `${ANOLIS_VERSION}` - OS 版本
- `${EXTENSIONS_LIST}` - 扩展列表
- `${BUILD_DATE}` - 构建日期
- `${VCS_REF}` - Git 引用

## 调试技巧

### 本地测试解析器

```bash
# 测试单个 OS
python3 docker/scripts/parse-extensions.py \
  --config docker/extensions.yml \
  --os ubuntu24.04 \
  --output /tmp/test-output

# 检查生成的脚本
cat /tmp/test-output/install-extensions-ubuntu24.04.sh
cat /tmp/test-output/extensions-metadata-ubuntu24.04.json
```

### 本地测试 Dockerfile 生成

```bash
bash docker/scripts/generate-dockerfile.sh \
  --os ubuntu24.04 \
  --output /tmp/test-docker

# 查看生成的 Dockerfile
cat /tmp/test-docker/Dockerfile.ubuntu24.04
```

### 本地构建镜像

```bash
# 生成脚本
python3 docker/scripts/parse-extensions.py --os ubuntu24.04

# 生成 Dockerfile
bash docker/scripts/generate-dockerfile.sh --os ubuntu24.04

# 构建
docker build -f docker/generated/Dockerfile.ubuntu24.04 \
  --build-arg UBUNTU_VERSION=24.04 \
  --build-arg EXTENSIONS_LIST="polar_monitor" \
  -t polardb:test .
```

### 测试镜像

```bash
# 安全扫描
bash docker/scripts/scan-image.sh polardb:test

# 功能测试
bash docker/scripts/test-image.sh polardb:test

# 手动运行
docker run -d --name polardb-test \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=test \
  polardb:test

docker exec -it polardb-test psql -U polardb -d polardb
```

## 故障排除

### 解析器错误

**错误**: `ModuleNotFoundError: No module named 'yaml'`

**解决**:
```bash
pip3 install pyyaml
```

**错误**: `ExtensionConfigError: 配置文件不存在`

**解决**:
- 检查 `docker/extensions.yml` 是否存在
- 使用 `--config` 参数指定配置文件路径

### 构建错误

**错误**: `Dockerfile 语法错误`

**解决**:
- 检查 Dockerfile 模板语法
- 查看构建日志中的具体错误
- 使用 `docker build --no-cache` 清除缓存

**错误**: `扩展安装失败`

**解决**:
- 检查扩展名称是否正确
- 查看构建日志中的扩展安装部分
- 验证 OS 支持该扩展
- 检查依赖关系

### GitHub Actions 错误

**错误**: `DOCKERHUB_TOKEN not set`

**解决**:
- 在 GitHub 仓库设置中添加 Secret
- Secret 名称: `DOCKERHUB_TOKEN`
- Token 类型: Access Token

**错误**: `构建失败`

**解决**:
- 查看 Actions 日志
- 检查构建矩阵配置
- 验证基础镜像可用性

## 扩展开发

### 创建自定义扩展安装器

```bash
#!/bin/bash
# 自定义扩展安装器模板

# 1. 检查扩展源
# 2. 下载/克隆扩展源码
# 3. 编译安装
# 4. 验证安装
```

### 集成到构建流程

在 `docker/installers/` 中添加脚本后，需要在解析器中调用。

修改 `parse-extensions.py` 的 `generate_install_script()` 方法。

## 性能优化

### 减小镜像大小

1. 使用多阶段构建
2. 清理包缓存
3. 删除不必要的文件
4. 使用 `.dockerignore`

### 加快构建速度

1. 启用 GitHub Actions 缓存
2. 使用 `--no-deps` 优化依赖
3. 并行构建架构
4. 复用构建缓存层

## 安全最佳实践

1. **定期更新基础镜像**
2. **扫描漏洞** - 使用 Trivy
3. **签名镜像** - Docker Content Trust
4. **最小化权限** - 非 root 用户运行
5. **验证来源** - 扩展源校验

## 代码风格

### Python 代码

- 遵循 PEP 8
- 使用类型提示
- 编写文档字符串
- 错误处理完善

### Shell 脚本

- 使用 `set -e` 错误退出
- 添加详细注释
- 使用引号保护变量
- 日志信息清晰

### YAML 配置

- 使用注释说明复杂配置
- 保持一致的缩进
- 使用有意义的关键字
- 提供示例

## 测试清单

在提交代码前，确保：

- [ ] Python 代码语法正确 (`python3 -m py_compile`)
- [ ] Shell 脚本语法正确 (`bash -n`)
- [ ] YAML 格式正确
- [ ] Dockerfile 模板有效
- [ ] 本地构建成功
- [ ] 镜像测试通过
- [ ] 文档更新完整

## 发布流程

1. 更新代码
2. 本地测试
3. 提交 Pull Request
4. 代码审查
5. 合并到主分支
6. GitHub Actions 自动构建
7. 镜像推送到 Docker Hub

## 联系方式

- **Issues**: https://github.com/isFire/PolarDB-for-PostgreSQL/issues
- **Pull Requests**: https://github.com/isFire/PolarDB-for-PostgreSQL/pulls

---

**最后更新**: 2025-01-12
**维护者**: PolarDB Team
