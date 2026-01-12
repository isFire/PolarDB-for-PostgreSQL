# Docker 镜像构建系统

此目录包含 PolarDB Docker 镜像的完整构建系统。

## 📁 目录结构

```
docker/
├── extensions.yml              # 主配置文件
├── IMPLEMENTATION_SUMMARY.md   # 实现总结文档
├── examples/                   # 配置示例
│   ├── minimal.yml            # 最小配置
│   ├── gis.yml                # GIS 空间数据库
│   └── ai-extensions.yml      # AI/向量扩展
├── scripts/                    # 构建和安装脚本
│   ├── parse-extensions.py    # 配置解析器
│   ├── generate-dockerfile.sh # Dockerfile 生成器
│   ├── extension-metadata.json # 扩展元数据
│   ├── entrypoint.sh          # 容器入口点
│   └── init-extensions.sql    # 初始化 SQL
├── installers/                 # 扩展安装器
│   ├── install-ubuntu-extensions.sh
│   └── install-anolis-extensions.sh
├── templates/                  # Dockerfile 模板
│   ├── Dockerfile.ubuntu.tmpl
│   └── Dockerfile.anolis.tmpl
└── generated/                  # 自动生成文件
    ├── Dockerfile.{os}        # 生成的 Dockerfile
    ├── install-extensions-{os}.sh  # 生成的安装脚本
    └── extensions-metadata-{os}.json  # 元数据
```

## 🚀 快速开始

### 1. 安装依赖

```bash
pip3 install pyyaml
```

### 2. 配置扩展

编辑 `docker/extensions.yml` 或使用示例配置：

```bash
# 使用示例配置
cp docker/examples/minimal.yml docker/extensions.yml

# 或使用 GIS 配置
cp docker/examples/gis.yml docker/extensions.yml
```

### 3. 生成安装脚本

```bash
# 为特定 OS 生成
python3 docker/scripts/parse-extensions.py --os ubuntu24.04

# 为所有 OS 生成
python3 docker/scripts/parse-extensions.py --os all
```

### 4. 生成 Dockerfile

```bash
bash docker/scripts/generate-dockerfile.sh --os ubuntu24.04
```

### 5. 构建镜像

```bash
docker build -f docker/generated/Dockerfile.ubuntu24.04 \
  --build-arg UBUNTU_VERSION=24.04 \
  --build-arg EXTENSIONS_LIST="polar_monitor polar_audit" \
  -t your-dockerhub-username/polardb:ubuntu24.04 .
```

### 6. 运行容器

```bash
docker run -d \
  --name polardb \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=mysecretpassword \
  your-dockerhub-username/polardb:ubuntu24.04
```

## 📖 配置说明

### 扩展集合 (extension_sets)

在 `extensions.yml` 中定义可重用的扩展集合：

```yaml
extension_sets:
  monitoring:
    - polar_monitor
    - polar_audit

  spatial:
    - postgis
    - pgrouting

default_sets: [monitoring, spatial]
```

### OS 特定覆盖 (os_overrides)

为特定 OS 版本添加或排除扩展：

```yaml
os_overrides:
  ubuntu24.04:
    additional_extensions: [new_extension]
    exclude_extensions: []

  anolis8:
    additional_extensions: []
    exclude_extensions: [extension_unavailable_on_rhel]
```

### 扩展源配置 (extension_sources)

配置扩展的安装源：

```yaml
extension_sources:
  pigsty:
    enabled: false  # 是否启用 Pigsty 仓库
    repo_url:
      ubuntu: "https://repo.pigsty.io/apt"
      anolis: "https://repo.pigsty.io/yum"

  custom: []  # 自定义扩展源
```

## 🎯 支持的 OS 版本

- **Ubuntu**: 20.04, 22.04, 24.04
- **Anolis**: 8, 23

## 🏗️ 支持的架构

- **amd64**: x86_64 架构
- **arm64**: ARM64 架构（Apple Silicon, ARM 云服务器）

## 📦 支持的扩展

### PolarDB 内置扩展
- polar_audit, polar_monitor, polar_resource_manager
- polar_io_stat, polar_login_history, polar_masking
- polar_password_policy, polar_proxy_utils
- polar_worker, polar_stat_env, polar_smgrperf
- polar_feature_utils, polar_parameter_manager
- polar_monitor_preload

### 数据分析扩展
- hll, hypopg, log_fdw, pase
- pg_repack, roaringbitmap, tdigest

### 全文搜索扩展
- pg_bigm, pg_jieba, pg_trgm, zhparser

### AI/向量扩展
- pgvector, timescaledb, pg_analytics

### 空间数据库扩展
- postgis, postgis_raster, pgrouting
- postgis_tiger_geocoder, address_standardizer
- ogr_fdw, pggeoip

### Pigsty 扩展
- pg_stat_statements, pg_cron, pg_auto_failover
- plv8, pg_stat_kcache

## 🔄 GitHub Actions 集成

配置以下 Secrets：

1. `DOCKERHUB_USERNAME` - Docker Hub 用户名
2. `DOCKERHUB_TOKEN` - Docker Hub 访问令牌

触发构建：
- 推送到 `POLARDB_15_STABLE` 分支
- 创建 tag
- 手动触发 (workflow_dispatch)

## 📝 注意事项

1. **PyYAML 依赖**: 需要 `pip3 install pyyaml`
2. **镜像大小**: 典型配置约 1.5-2GB
3. **构建时间**: 首次构建约 30-45 分钟
4. **扩展兼容性**: 某些扩展可能不兼容特定 OS 版本

## 🐛 故障排除

### 扩展安装失败

检查扩展名称是否正确，查看构建日志了解详细错误。

### 镜像构建失败

1. 检查 Dockerfile 语法
2. 验证基础镜像是否可用
3. 查看构建日志了解错误详情

### 扩展无法加载

1. 进入容器检查扩展文件
2. 查看 PostgreSQL 日志
3. 使用 `\dx` 命令列出可用扩展

## 📚 更多文档

- **实现总结**: `docker/IMPLEMENTATION_SUMMARY.md`
- **需求文档**: `.spec-workflow/specs/docker-image-pipeline/requirements.md`
- **设计文档**: `.spec-workflow/specs/docker-image-pipeline/design.md`
- **任务列表**: `.spec-workflow/specs/docker-image-pipeline/tasks.md`

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

与 PolarDB-for-PostgreSQL 主项目保持一致。
