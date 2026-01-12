# 任务文档

## 阶段 1: 基础框架

- [x] 1.1 创建扩展配置 YAML 架构和示例
  - File: docker/extensions.yml
  - 定义扩展配置的 YAML schema
  - 创建包含 PolarDB、Pigsty、自定义扩展的示例配置
  - 目的: 建立声明式扩展配置的基础架构
  - _Leverage: external/Makefile 中的扩展列表, docker/postgis-pgrouting/Dockerfile.old_
  - _Requirements: 1.1, 1.2, 4.1_
  - _Prompt: 角色: DevOps 工程师，擅长配置管理和 YAML 架构设计 | 任务: 创建 docker/extensions.yml 配置文件，定义清晰的 YAML schema，包含 extension_sets、default_sets、os_overrides 和 extension_sources 部分，参考 external/Makefile 中的扩展列表和现有的 Dockerfile | 限制: 必须遵循 YAML 最佳实践，确保配置可读性和可维护性，包含详细的注释和示例 | 成功: YAML 文件语法正确，包含完整的示例配置，涵盖所有配置选项，注释清晰易懂_

- [x] 1.2 实现扩展配置解析器
  - File: docker/scripts/parse-extensions.py
  - 创建 Python 脚本解析 extensions.yml
  - 实现扩展依赖解析和冲突检测
  - 生成 OS 特定的安装脚本
  - 目的: 自动化扩展配置处理和安装脚本生成
  - _Leverage: external/Makefile, package/rpm/PolarDB.spec_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - _Prompt: 角色: Python 开发者，擅长配置解析和脚本编写 | 任务: 实现 parse-extensions.py 脚本，使用 PyYAML 解析配置文件，实现扩展依赖解析逻辑，检测扩展冲突，生成 bash 安装脚本，参考 external/Makefile 了解 PolarDB 扩展结构 | 限制: 必须处理 YAML 格式错误，提供清晰的错误消息，支持 OS 特定的扩展覆盖，验证扩展可用性 | 成功: 脚本正确解析所有配置选项，生成的安装脚本语法正确，错误处理完善，支持依赖解析和冲突检测_

- [x] 1.3 创建扩展元数据库
  - File: docker/scripts/extension-metadata.json
  - 定义扩展的元数据结构（依赖、OS 支持、包名）
  - 填充已知 PolarDB 扩展的元数据
  - 添加 Pigsty 扩展的示例元数据
  - 目的: 提供扩展知识库用于验证和解析
  - _Leverage: external/Makefile, package/debian/control, package/rpm/PolarDB.spec_
  - _Requirements: 1.1, 1.2, 1.3_
  - _Prompt: 角色: 数据架构师，擅长元数据管理和 JSON schema 设计 | 任务: 创建 extension-metadata.json 文件，定义扩展元数据的 JSON schema，填充 external/ 目录中所有 PolarDB 扩展的元数据，参考 package/debian/control 和 package/rpm/PolarDB.spec 中的包信息 | 限制: 必须包含所有必要的元数据字段（category, dependencies, os_support, package_name, build_from_source），保持 JSON 格式有效，使用一致的命名约定 | 成功: JSON 文件格式正确，包含所有 PolarDB 扩展的完整元数据，schema 定义清晰，易于扩展新扩展_

- [x] 1.4 创建 Dockerfile 生成器模板
  - File: docker/templates/Dockerfile.ubuntu.tmpl, docker/templates/Dockerfile.anolis.tmpl
  - 创建 Ubuntu 和 Anolis 的 Dockerfile 模板
  - 实现多阶段构建优化
  - 添加构建参数和元数据标签
  - 目的: 生成优化的、OS 特定的 Dockerfile
  - _Leverage: docker/postgis-pgrouting/Dockerfile.old_
  - _Requirements: 2.1, 2.2, 2.3, 5.1_
  - _Prompt: 角色: Docker 专家，擅长多阶段构建和镜像优化 | 任务: 为 Ubuntu 和 Anolis 创建 Dockerfile 模板，实现多阶段构建（builder + runtime），优化层缓存，添加构建参数支持，注入镜像元数据标签，参考 docker/postgis-pgrouting/Dockerfile.old 的结构 | 限制: 必须遵循 Docker 最佳实践，最小化镜像层数，确保非 root 用户运行，添加健康检查，支持构建时参数注入 | 成功: 模板生成语法正确的 Dockerfile，多阶段构建优化良好，支持所有必要的构建参数，包含完整的元数据标签_

- [x] 1.5 实现 Dockerfile 生成脚本
  - File: docker/scripts/generate-dockerfile.sh
  - 创建 shell 脚本调用模板引擎
  - 根据解析的扩展生成 Dockerfile
  - 注入 OS 特定的配置和扩展列表
  - 目的: 自动化 Dockerfile 生成流程
  - _Leverage: docker/templates/, docker/scripts/parse-extensions.py_
  - _Requirements: 2.1, 2.2_
  - _Prompt: 角色: Bash 脚本专家，擅长模板引擎和构建自动化 | 任务: 实现 generate-dockerfile.sh 脚本，调用 parse-extensions.py 获取扩展列表，选择正确的 OS 模板，使用模板引擎（如 envsubst）生成最终 Dockerfile，注入所有必要的构建参数 | 限制: 必须处理模板生成错误，验证生成的 Dockerfile 语法，支持所有 OS 版本，提供清晰的日志输出 | 成功: 脚本生成语法正确的 Dockerfile，所有参数正确注入，错误处理完善，日志信息清晰_

- [x] 1.6 创建基础 GitHub Actions workflow
  - File: .github/workflows/docker-build.yml
  - 定义基本的构建流程（checkout → 生成 → 构建 → 推送）
  - 配置 Docker Hub 认证
  - 实现单 OS/架构构建
  - 目的: 建立端到端的 CI/CD 流水线基础
  - _Leverage: .github/workflows/package.yml, .github/workflows/precheck.yml_
  - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - _Prompt: 角色: DevOps 工程师，擅长 GitHub Actions 和 CI/CD 流水线 | 任务: 创建 docker-build.yml workflow，定义基本的构建步骤（fetch code, parse config, generate dockerfile, build image, push to Docker Hub），配置 DOCKERHUB_USERNAME 和 DOCKERHUB_TOKEN secrets，参考现有 package.yml 的结构 | 限制: 必须遵循 GitHub Actions 最佳实践，安全处理凭证，支持手动触发（workflow_dispatch），提供清晰的构建日志 | 成功: workflow 语法正确，成功构建和推送 Docker 镜像，凭证管理安全，支持手动和自动触发_

## 阶段 2: 多 OS 支持

- [x] 2.1 实现 Ubuntu 扩展安装脚本模板
  - File: docker/installers/install-ubuntu-extensions.sh
  - 创建 Ubuntu 特定的扩展安装逻辑
  - 处理 DEB 包依赖和安装
  - 支持 PolarDB 扩展编译
  - 目的: 提供 Ubuntu 系统的扩展安装能力
  - _Leverage: package/debian/build-deb.sh_
  - _Requirements: 1.1, 1.2, 1.3, 3.1, 3.2_
  - _Prompt: 角色: Debian/Ubuntu 包管理专家 | 任务: 创建 Ubuntu 扩展安装脚本，实现 apt-get 包安装逻辑，处理 PolarDB 扩展从源码编译，支持 PostGIS、pgRouting 等空间扩展的安装，参考 package/debian/build-deb.sh 的依赖处理 | 限制: 必须处理包安装失败，提供清晰的错误消息，使用 DEBIAN_FRONTEND=noninteractive，正确处理依赖关系 | 成功: 脚本正确安装所有配置的扩展，错误处理完善，支持从包和源码安装，日志信息清晰_

- [x] 2.2 实现 Anolis 扩展安装脚本模板
  - File: docker/installers/install-anolis-extensions.sh
  - 创建 Anolis/RHEL 特定的扩展安装逻辑
  - 处理 RPM 包依赖和安装
  - 支持 PolarDB 扩展编译
  - 目的: 提供 Anolis 系统的扩展安装能力
  - _Leverage: package/rpm/build-rpm.sh_
  - _Requirements: 1.1, 1.2, 1.3, 3.1, 3.2_
  - _Prompt: 角色: RHEL/CentOS 包管理专家 | 任务: 创建 Anolis 扩展安装脚本，实现 yum/dnf 包安装逻辑，处理 PolarDB 扩展从源码编译，支持与 RHEL 系统的兼容性，参考 package/rpm/build-rpm.sh 的依赖处理 | 限制: 必须处理包安装失败，提供清晰的错误消息，正确处理 RPM 依赖关系，考虑 EPEL 仓库的使用 | 成功: 脚本正确安装所有配置的扩展，错误处理完善，支持从包和源码安装，兼容 Anolis 8 和 23_

- [ ] 2.3 配置构建 Matrix 策略
  - File: .github/workflows/docker-build.yml (修改)
  - 添加多 OS 矩阵配置
  - 实现 OS 特定的构建步骤
  - 处理不支持的组合
  - 目的: 并行构建多个 OS 版本
  - _Leverage: .github/workflows/package.yml 中的 matrix 配置_
  - _Requirements: 2.1, 2.3, 2.4_
  - _Prompt: 角色: CI/CD 架构师，擅长并行构建和矩阵策略 | 任务: 在 docker-build.yml 中添加 matrix 策略，配置 Ubuntu (20.04, 22.04, 24.04) 和 Anolis (8, 23) 的构建，使用 exclude 移除不支持的组合，参考 package.yml 的矩阵配置 | 限制: 必须设置 fail-fast: false 避免一个失败影响其他，每个 OS 使用正确的 Docker 镜像，处理 OS 特定的差异 | 成功: workflow 并行构建所有 OS 版本，不支持的组合被正确跳过，构建日志清晰标识每个 OS，fail-fast 设置正确_

- [ ] 2.4 实现 OS 特定覆盖逻辑
  - File: docker/scripts/parse-extensions.py (修改)
  - 扩展解析器支持 os_overrides 配置
  - 处理 additional_extensions 和 exclude_extensions
  - 验证 OS 特定配置的有效性
  - 目的: 允许不同 OS 使用不同的扩展集合
  - _Leverage: docker/extensions.yml 中的 os_overrides schema_
  - _Requirements: 1.1, 1.2_
  - _Prompt: 角色: Python 开发者，擅长配置管理和条件逻辑 | 任务: 修改 parse-extensions.py，实现 os_overrides 处理逻辑，支持 additional_extensions 添加 OS 特定扩展，支持 exclude_extensions 排除不兼容扩展，验证 OS 版本格式的正确性 | 限制: 必须处理无效的 OS 版本名称，验证扩展名称存在性，确保 OS 覆盖不产生冲突，提供清晰的错误消息 | 成功: OS 覆盖逻辑正确工作，生成的安装脚本包含正确的扩展列表，错误处理完善，支持所有配置的 OS 版本_

## 阶段 3: Pigsty 集成

- [x] 3.1 实现 Pigsty 仓库配置脚本
  - File: docker/installers/install-pigsty.sh
  - 创建配置 Pigsty APT/YUM 仓库的逻辑
  - 安装 `pig` 包管理器
  - 实现仓库可用性检测
  - 目的: 集成 Pigsty 扩展生态
  - _Leverage: Pigsty 官方文档, package/debian/build-deb.sh 中的仓库配置模式_
  - _Requirements: 4.1, 4.2, 4.3_
  - _Prompt: 角色: 包管理仓库专家，擅长第三方仓库集成 | 任务: 创建 install-pigsty.sh 脚本，实现 Ubuntu 和 Anolis 的 Pigsty 仓库配置，使用 curl 下载仓库配置，安装 `pig` 包管理器，添加仓库健康检查和超时处理，参考 Pigsty 官方文档的仓库配置方法 | 限制: 必须处理网络失败，提供清晰的错误消息，支持 Ubuntu DEB 和 Anolis RPM 两种包格式，验证 GPG 密钥（如果可用） | 成功: 脚本正确配置 Pigsty 仓库，`pig` 包管理器成功安装，仓库可用性检测工作正常，错误处理完善_

- [x] 3.2 实现 Pigsty 扩展安装逻辑
  - File: docker/installers/install-pigsty-extensions.sh
  - 使用 `pig` 命令安装扩展
  - 实现扩展回退到源码构建
  - 处理 Pigsty 特定的依赖
  - 目的: 从 Pigsty 仓库安装扩展
  - _Leverage: docker/scripts/install-pigsty.sh_
  - _Requirements: 4.1, 4.2, 4.3_
  - _Prompt: 角色: PostgreSQL 扩展专家，熟悉 Pigsty 生态 | 任务: 创建 install-pigsty-extensions.sh 脚本，使用 `pig install` 命令安装配置的扩展列表，实现失败时回退到源码构建的逻辑，处理 Pigsty 扩展的依赖关系，记录安装日志 | 限制: 必须处理 `pig` 命令失败，回退到源码构建时需要依赖信息，提供详细的安装日志，避免重复安装 | 成功: 脚本从 Pigsty 成功安装扩展，失败时正确回退到源码构建，依赖关系正确处理，日志信息详细_

- [x] 3.3 扩展元数据库集成 Pigsty 扩展
  - File: docker/scripts/extension-metadata.json (修改)
  - 添加常用 Pigsty 扩展的元数据
  - 定义 Pigsty 扩展的依赖关系
  - 标记 Pigsty 扩展的 OS 支持情况
  - 目的: 支持 Pigsty 扩展的配置解析
  - _Leverage: Pigsty 官方扩展列表, 现有 extension-metadata.json 结构_
  - _Requirements: 4.1, 4.2_
  - _Prompt: 角色: 数据维护专家，擅长元数据管理 | 任务: 扩展 extension-metadata.json，添加常用 Pigsty 扩展（pgvector, timescaledb, postgis, pg_repack 等）的元数据，定义正确的依赖关系，标记每个扩展在不同 OS 的支持情况 | 限制: 必须验证扩展名称的正确性，依赖关系必须准确，OS 支持信息要与实际情况一致，保持与现有 schema 一致 | 成功: JSON 包含完整的 Pigsty 扩展元数据，依赖关系正确，OS 支持信息准确，schema 一致性良好_

- [x] 3.4 扩展解析器集成 Pigsty 支持
  - File: docker/scripts/parse-extensions.py (修改)
  - 解析 pigsty 扩展集合
  - 调用 Pigsty 安装脚本
  - 处理 Pigsty 与 PolarDB 扩展的冲突
  - 目的: 在配置解析中支持 Pigsty 扩展
  - _Leverage: docker/scripts/install-pigsty-extensions.sh_
  - _Requirements: 4.1, 4.2, 4.4_
  - _Prompt: 角色: Python 开发者，擅长系统集成 | 任务: 修改 parse-extensions.py，添加 Pigsty 扩展集合的解析逻辑，生成调用 install-pigsty-extensions.sh 的命令，检测 Pigsty 与 PolarDB 扩展的命名冲突 | 限制: 必须正确识别 Pigsty 扩展集合，生成正确的安装命令，冲突检测要考虑版本兼容性，提供清晰的警告消息 | 成功: Pigsty 扩展正确解析和安装，冲突检测工作正常，生成的安装脚本包含正确的 Pigsty 扩展安装命令_

## 阶段 4: 多架构支持

- [ ] 4.1 配置 QEMU 和 Docker Buildx
  - File: .github/workflows/docker-build.yml (修改)
  - 添加 setup-qemu-action 步骤
  - 配置 docker/setup-buildx-action
  - 启用多架构平台支持
  - 目的: 支持跨架构 Docker 构建
  - _Leverage: Docker 官方 buildx 文档, GitHub Actions marketplace_
  - _Requirements: 5.1, 5.2_
  - _Prompt: 角色: Docker 多架构构建专家 | 任务: 在 docker-build.yml 中添加 QEMU 和 buildx 配置，使用 docker/setup-qemu-action@v3 和 docker/setup-buildx-action@v3，配置 platforms 参数支持 linux/amd64,linux/arm64 | 限制: 必须使用官方 action 的最新稳定版本，正确配置平台列表，确保 buildx 构建器正确初始化 | 成功: workflow 正确设置 QEMU 模拟器，buildx 构建器配置正确，支持所有目标架构_

- [ ] 4.2 实现多架构并行构建
  - File: .github/workflows/docker-build.yml (修改)
  - 修改 matrix 策略包含架构维度
  - 配置 docker/build-push-action 的 platforms 参数
  - 实现架构特定的构建优化
  - 目的: 并行构建多个架构
  - _Leverage: 现有 matrix 配置, docker/build-push-action 文档_
  - _Requirements: 5.1, 5.2, 5.3_
  - _Prompt: 角色: CI/CD 优化专家，擅长并行构建 | 任务: 扩展构建 matrix 添加 arch 维度 (amd64, arm64)，配置 docker/build-push-action@v5 支持多平台构建，使用 fail-fast: false 确保一个架构失败不影响其他 | 限制: 必须排除不支持的 OS/架构组合，确保每个构建使用正确的 runner 类型，优化并行构建的缓存策略 | 成功: workflow 并行构建所有架构组合，不支持的组合被正确排除，构建效率优化良好_

- [ ] 4.3 创建多架构 Manifest
  - File: .github/workflows/docker-build.yml (修改)
  - 实现多架构镜像的 manifest 创建
  - 推送 manifest 到 Docker Hub
  - 配置标签策略（latest, version, os, arch）
  - 目的: 提供统一的多架构镜像
  - _Leverage: Docker manifest 命令文档_
  - _Requirements: 5.2, 5.4_
  - _Prompt: 角色: Docker registry 专家，熟悉镜像分发 | 任务: 在 workflow 中添加 manifest 创建步骤，使用 docker manifest create 合并多架构镜像，使用 docker manifest push 推送到 Docker Hub，配置智能标签（latest, version, os-version）| 限制: 必须等待所有架构构建完成，确保 manifest 引用的镜像都存在，处理 manifest 创建失败的情况 | 成功: manifest 正确创建和推送，docker pull 默认拉取正确架构的镜像，标签策略清晰合理_

## 阶段 5: 安全和优化

- [ ] 5.1 集成 Trivy 安全扫描
  - File: .github/workflows/docker-build.yml (修改)
  - 添加 Trivy 扫描步骤
  - 配置漏洞严重级别阈值
  - 实现扫描结果报告
  - 目的: 确保镜像安全性
  - _Leverage: Trivy 官方 GitHub Action_
  - _Requirements: 安全需求 - 安全扫描_
  - _Prompt: 角色: 安全工程师，擅长容器安全 | 任务: 在 docker-build.yml 中集成 Trivy 扫描，使用 aquasecurity/trivy-action@master，配置扫描级别（HIGH, CRITICAL），设置扫描失败策略，生成 SARIF 报告上传到 GitHub Security | 限制: 必须配置合理的漏洞阈值，不阻止构建但提供警告，扫描所有层和依赖，支持配置白名单（如需要）| 成功: Trivy 正确扫描镜像，漏洞报告清晰可见，严重漏洞被标记，SARIF 报告正确上传_

- [ ] 5.2 实现镜像签名（可选）
  - File: .github/workflows/docker-build.yml (修改)
  - 配置 Docker Content Trust
  - 签名推送的镜像
  - 验证签名完整性
  - 目的: 提供镜像完整性保证
  - _Leverage: Docker Content Trust 文档_
  - _Requirements: 安全需求 - 供应链安全_
  - _Prompt: 角色: 安全架构师，擅长供应链安全 | 任务: 在 workflow 中配置 Docker Content Trust，设置 DOCKER_CONTENT_TRUST=1，配置签名私钥作为 GitHub Secret，实现镜像签名验证步骤 | 限制: 必须安全存储签名密钥，处理签名失败的情况，提供清晰的签名状态，确保验证步骤正确 | 成功: 镜像正确签名，签名密钥安全存储，验证步骤工作正常，签名状态清晰可见_

- [ ] 5.3 优化构建缓存策略
  - File: .github/workflows/docker-build.yml (修改)
  - 配置 Docker 层缓存
  - 实现 APT/YUM 包缓存
  - 优化构建矩阵的缓存共享
  - 目的: 减少构建时间和成本
  - _Leverage: GitHub Actions cache, Docker cache documentation_
  - _Requirements: 性能需求 - 构建优化_
  - _Prompt: 角色: 性能优化专家，擅长 CI/CD 优化 | 任务: 在 workflow 中配置 actions/cache@v3 缓存 Docker 层和包管理器缓存，配置 cache 的 key 基于 extensions.yml 的 hash，设置合理的缓存过期时间 | 限制: 必须避免缓存污染，正确处理缓存失效，缓存大小要在限制内，共享策略要合理 | 成功: 缓存正确命中和失效，构建时间显著减少，缓存使用效率高，缓存管理清晰_

- [ ] 5.4 实现 SBOM 生成
  - File: .github/workflows/docker-build.yml (修改)
  - 使用 Syft 或类似工具生成 SBOM
  - 附加 SBOM 到镜像元数据
  - 上传 SBOM 到工件
  - 目的: 提供软件物料清单
  - _Leverage: Syft 官方文档, SBOM 最佳实践_
  - _Requirements: 安全需求 - 供应链安全_
  - _Prompt: 角色: 供应链安全专家，熟悉 SBOM 标准 | 任务: 在 workflow 中集成 Syft 生成 SBOM，使用 SPDX 或 CycloneDX 格式，将 SBOM 附加到镜像作为 label，上传 SBOM 文件作为 GitHub Artifact | 限制: 必须使用标准 SBOM 格式，包含所有依赖和扩展，SBOM 文件大小合理，支持人工和机器读取 | 成功: SBOM 正确生成，格式符合标准，包含完整信息，SBOM 文件正确上传和附加_

## 阶段 6: 文档和测试

- [ ] 6.1 编写用户文档
  - File: docker/README.md
  - 创建快速入门指南
  - 编写扩展配置说明
  - 提供故障排除指南
  - 目的: 帮助用户使用 Docker 构建系统
  - _Leverage: requirements.md, design.md_
  - _Requirements: 易用性需求 - 文档_
  - _Prompt: 角色: 技术文档工程师，擅长用户指南 | 任务: 创建 docker/README.md，包含快速开始、配置说明、示例工作流、常见问题解答、故障排除步骤，使用清晰的章节结构和代码示例 | 限制: 必须使用中文（与需求文档一致），包含完整的示例，涵盖所有配置选项，提供实际可用的命令 | 成功: 文档清晰易懂，示例完整可运行，涵盖所有主要功能，故障排除有效_

- [ ] 6.2 创建扩展配置示例
  - File: docker/examples/
  - 创建 minimal 扩展集示例
  - 创建 full-extensions 示例
  - 创建 specific-use-cases 示例（GIS, AI, etc.）
  - 目的: 提供实际可用的配置模板
  - _Leverage: docker/extensions.yml 架构_
  - _Requirements: 易用性需求 - 文档和示例_
  - _Prompt: 角色: 解决方案架构师，擅长场景设计 | 任务: 在 docker/examples/ 目录创建多个配置示例，包括 minimal.yml（最小扩展集）、full.yml（所有扩展）、gis.yml（空间扩展）、ai.yml（AI/ML 扩展），每个示例包含注释说明 | 限制: 必须验证每个示例的语法正确性，确保示例是实际可用的，注释要清晰说明使用场景，避免过度复杂 | 成功: 每个示例文件语法正确，可以直接使用，注释清晰，涵盖不同使用场景_

- [x] 6.3 实现集成测试
  - File: docker/scripts/test-image.sh
  - 创建端到端构建测试
  - 验证生成的镜像可以启动
  - 测试扩展正确安装
  - 目的: 确保 Docker 构建系统的可靠性
  - _Leverage: .github/workflows/precheck.yml 中的测试模式_
  - _Requirements: 测试需求 - 集成测试_
  - _Prompt: 角色: QA 工程师，擅长容器测试 | 任务: 创建 test-image.sh 测试脚本，测试镜像启动和运行，使用 psql 测试扩展可用性（CREATE EXTENSION），检查镜像大小和健康状态 | 限制: 必须测试成功和失败场景，使用真实的扩展配置，提供清晰的测试报告，测试可在本地和 CI 运行 | 成功: 测试脚本覆盖主要功能，正确验证镜像功能，测试报告清晰，可以在 CI 中自动运行_

- [ ] 6.4 实现镜像验证测试
  - File: tests/docker-image-validation.sh
  - 验证镜像元数据标签
  - 检查非 root 用户运行
  - 验证健康检查正常
  - 目的: 确保镜像质量和合规性
  - _Leverage: docker/README.md 中的规范要求_
  - _Requirements: 安全需求 - 镜像验证, 测试需求 - 镜像验证_
  - _Prompt: 角色: QA 自动化工程师，擅长容器验证 | 任务: 创建 docker-image-validation.sh 验证脚本，检查镜像标签（org.opencontainers.image.*），验证以 postgres 用户运行，测试健康检查（pg_isready），检查敏感文件不存在 | 限制: 必须验证所有元数据标签，检查所有安全要求，提供清晰的验证报告，支持多个镜像批量验证 | 成功: 验证脚本检查所有必需项目，报告清晰准确，可以集成到 CI 流程，帮助快速发现质量问题_

- [ ] 6.5 编写开发者文档
  - File: docs/docker-build-development.md
  - 编写架构设计说明
  - 创建故障排除指南
  - 提供扩展开发指南
  - 目的: 帮助开发者维护和扩展系统
  - _Leverage: design.md, requirements.md_
  - _Requirements: 易用性需求 - 文档_
  - _Prompt: 角色: 技术文档工程师，擅长开发者指南 | 任务: 创建 docs/docker-build-development.md，包含系统架构图、组件职责说明、开发环境设置、调试技巧、添加新扩展的流程、常见问题解决方案 | 限制: 必须包含足够的架构细节，提供实际可用的调试命令，包含代码示例，使用与设计文档一致的术语 | 成功: 文档帮助开发者快速上手，架构解释清晰，调试技巧有效，扩展指南详细_

## 使用说明

### 任务状态标记
- `[ ]` - 待处理
- `[-]` - 进行中
- `[x]` - 已完成

### 实现任务流程

1. **开始任务前**：
   - 阅读任务描述和 _Prompt 字段
   - 查看 _Leverage 中引用的现有代码
   - 理解 _Requirements 中关联的需求

2. **执行任务**：
   - 在 tasks.md 中将 `[ ]` 改为 `[-]`
   - 按照 _Prompt 中的角色和任务描述实施
   - 遵循 _Prompt 中的限制条件
   - 达到 _Prompt 中的成功标准

3. **任务完成后**：
   - 使用 `log-implementation` 工具记录实现详情
   - 包含详细的 artifacts（API 端点、组件、函数等）
   - 在 tasks.md 中将 `[-]` 改为 `[x]`

### 关键文件路径

**配置文件**：
- `docker/extensions.yml` - 扩展配置主文件
- `docker/scripts/extension-metadata.json` - 扩展元数据库

**脚本文件**：
- `docker/scripts/parse-extensions.py` - 配置解析器
- `docker/scripts/generate-dockerfile.sh` - Dockerfile 生成器
- `docker/scripts/install-pigsty.sh` - Pigsty 仓库配置

**模板文件**：
- `docker/templates/Dockerfile.ubuntu.tmpl` - Ubuntu Dockerfile 模板
- `docker/templates/Dockerfile.anolis.tmpl` - Anolis Dockerfile 模板

**安装器**：
- `docker/installers/install-ubuntu-extensions.sh` - Ubuntu 扩展安装
- `docker/installers/install-anolis-extensions.sh` - Anolis 扩展安装
- `docker/installers/install-pigsty-extensions.sh` - Pigsty 扩展安装

**CI/CD**：
- `.github/workflows/docker-build.yml` - 主构建 workflow

### 实现里程碑

按照以下顺序实现任务：

1. **阶段 1** (任务 1.1-1.6): 建立基础框架，实现基本的配置解析和 Dockerfile 生成
2. **阶段 2** (任务 2.1-2.4): 添加多 OS 支持，实现 Ubuntu 和 Anolis 的特定逻辑
3. **阶段 3** (任务 3.1-3.4): 集成 Pigsty 扩展生态
4. **阶段 4** (任务 4.1-4.3): 实现多架构构建支持
5. **阶段 5** (任务 5.1-5.4): 添加安全扫描和性能优化
6. **阶段 6** (任务 6.1-6.5): 编写文档和测试

每个阶段完成后，应验证该阶段的功能正常工作，再进入下一阶段。
