# 需求文档

## 简介

本规范定义了 PolarDB-for-PostgreSQL 的灵活 Docker 镜像构建流水线，通过配置文件实现自定义扩展选择。该流水线将集成 Pigsty 扩展生态系统（440+ 扩展），同时支持官方 PolarDB 扩展和社区扩展。用户可以在每次构建时自定义扩展列表，无需修改 Dockerfile，从而为不同用例快速迭代。

**核心特性：**
- 基于 GitHub Actions 的自动化 Docker 镜像构建并发布到用户的 Docker Hub
- 通过 YAML 配置文件声明式选择扩展
- 仅支持 Ubuntu (20.04, 22.04, 24.04) 和龙蜥 OS (8, 23)
- 集成 Pigsty 扩展仓库的 440+ 扩展
- 支持 external/ 目录中的 PolarDB 专用扩展
- 多架构支持（amd64, arm64）

## 产品愿景对齐

本功能通过提供包含自定义扩展组合的预构建 Docker 镜像，使 PolarDB 能够更好地服务多样化的用例。这与 PolarDB 成为可扩展的云原生 PostgreSQL 发行版的目标保持一致，同时降低了需要特定扩展集的用户的准入门槛。

## 需求

### 需求 1：可配置的扩展选择

**用户故事**：作为开发者，我希望通过配置文件指定要包含哪些 PostgreSQL 扩展，这样我就可以为不同的组合构建定制镜像，而无需为每种组合修改 Dockerfile。

#### 验收标准

1. 当触发构建时，系统应从 `docker/extensions.yml` 读取扩展列表
2. 当 `docker/extensions.yml` 指定扩展时，系统应支持：
   - 来自 `external/` 目录的 PolarDB 专用扩展
   - PostGIS、pgRouting 及相关空间扩展
   - Pigsty 仓库扩展（440+ 可用）
   - 自定义扩展源（git 仓库、包 URL）
3. 如果扩展有依赖，系统应自动包含这些依赖
4. 当扩展列表为空时，系统应构建最小化的 PolarDB 镜像
5. 当扩展不可用时，系统应使构建失败并给出清晰的错误消息

### 需求 2：GitHub Actions 构建流水线

**用户故事**：作为维护者，我希望通过 GitHub Actions 自动化 Docker 镜像构建并推送到我的 Docker Hub 账户，这样我就不需要手动构建和发布镜像。

#### 验收标准

1. 当代码推送到 POLARDB_15_STABLE 分支时，系统应触发 Docker 镜像构建
2. 当构建完成时，系统应将镜像推送到用户的 Docker Hub 账户
3. 当推送镜像时，系统应使用以下标签：
   - 分支名称或 git 标签
   - OS 版本（例如 ubuntu24.04, anolis8）
   - 架构（amd64, arm64）
4. 如果未配置 Docker Hub 凭据，系统应在构建前失败
5. 当构建多个 OS/架构组合时，系统应创建多架构清单

### 需求 3：操作系统版本过滤

**用户故事**：作为维护者，我希望只为 Ubuntu 和龙蜥 OS 版本构建，以减少 CI/CD 成本和维护负担。

#### 验收标准

1. 当流水线运行时，系统应仅为以下版本构建：
   - Ubuntu: 20.04, 22.04, 24.04
   - 龙蜥 OS: 8, 23
2. 当指定其他 OS 版本时，系统应忽略它们
3. 当选择龙蜥 OS 时，系统应使用基于 RPM 的包
4. 当选择 Ubuntu 时，系统应使用基于 DEB 的包

### 需求 4：Pigsty 扩展集成

**用户故事**：作为开发者，我希望从 Pigsty 仓库访问 440+ PostgreSQL 扩展，以便使用 PolarDB external/ 目录之外的扩展。

#### 验收标准

1. 当请求 Pigsty 扩展时，系统应配置 Pigsty 包仓库
2. 当安装 Pigsty 扩展时，系统应使用 Pigsty 的扩展包管理器（`pig`）
3. 如果 Pigsty 仓库不可用，系统应回退到从源码构建
4. 当 Pigsty 扩展与 PolarDB 扩展冲突时，系统应警告并要求显式解决

### 需求 5：多架构支持

**用户故事**：作为用户，我希望能获得 amd64 和 arm64 两种架构的 Docker 镜像，这样我就可以在多样化的硬件平台上部署，包括 Apple Silicon 和 ARM 云实例。

#### 验收标准

1. 当构建镜像时，系统应同时构建 amd64 和 arm64
2. 当发布镜像时，系统应创建并推送多架构清单
3. 当某个架构构建失败时，系统应继续构建其他架构
4. 如果某个 OS/架构组合不受支持，系统应跳过并给出警告

## 非功能性需求

### 代码架构和模块化

- **单一职责原则**：将扩展安装、OS 特定配置和构建编排的关注点分离
- **模块化设计**：每个 OS 版本都有自己的 Dockerfile/构建脚本，包含通用的扩展安装逻辑
- **依赖管理**：扩展安装脚本必须自动处理依赖解析
- **清晰接口**：扩展配置 YAML 应有明确定义的架构并提供文档

### 性能

- 单个镜像的构建时间不应超过 GitHub Actions runner 上的 45 分钟
- 扩展安装应尽可能使用包缓存
- 多架构构建应尽可能并行运行
- 典型扩展集的最终镜像大小不应超过 2GB

### 安全性

- Docker Hub 凭据必须存储为 GitHub Secrets（绝不存储在代码中）
- 扩展源必须经过验证（校验和、GPG 签名等）
- 基础镜像必须来自官方或已验证的来源
- 构建脚本应尽可能以非 root 用户运行
- 应集成安全扫描（例如 Trivy、Docker Scout）

### 可靠性

- 构建失败应提供清晰的错误消息和修复步骤
- 流水线应重试瞬态网络故障
- 每个镜像应包含健康检查
- 扩展兼容性应在发布前验证

### 易用性

- 扩展配置 YAML 应提供示例文档
- 构建状态应在 GitHub Actions UI 中可见
- 发布的镜像应包含元数据（扩展列表、构建日期、git 提交）
- 应提供快速入门文档用于拉取和使用镜像
- 扩展名称应使用 PostgreSQL 标准命名约定

## 扩展配置架构（草案）

```yaml
# docker/extensions.yml
extension_sets:
  # 来自 external/ 的 PolarDB 内置扩展
  polar_core:
    - polar_audit
    - polar_monitor
    - polar_resource_manager

  # 空间扩展
  spatial:
    - postgis
    - pgrouting
    - postgis_tiger_geocoder

  # Pigsty 仓库扩展
  pigsty:
    - pgvector
    - timescaledb
    - zomboDB

# 默认构建的扩展集
default_sets: [polar_core, spatial]

# OS 特定覆盖
os_overrides:
  ubuntu24.04:
    additional_extensions:
      - custom_extension_from_source
  anolis8:
    exclude_extensions:
      - extension_unavailable_on_rhel
```
