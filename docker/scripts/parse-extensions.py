#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PolarDB Docker 扩展配置解析器

此脚本解析 docker/extensions.yml 配置文件，生成 OS 特定的扩展安装脚本。
支持扩展依赖解析、冲突检测和 OS 特定覆盖。

用法:
    python3 parse-extensions.py [--os OS_VERSION] [--output OUTPUT_DIR]

参数:
    --os: 目标操作系统版本 (ubuntu20.04, ubuntu22.04, ubuntu24.04, anolis8, anolis23)
    --output: 输出目录 (默认: docker/scripts/generated)
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional


class ExtensionConfigError(Exception):
    """扩展配置错误"""
    pass


class ExtensionParser:
    """扩展配置解析器"""

    def __init__(self, config_file: str, metadata_file: Optional[str] = None):
        """
        初始化解析器

        Args:
            config_file: 扩展配置文件路径
            metadata_file: 扩展元数据文件路径（可选）
        """
        self.config_file = Path(config_file)
        self.metadata_file = Path(metadata_file) if metadata_file else None
        self.config = {}
        self.metadata = {}
        self.all_extensions: Set[str] = set()

    def load_yaml(self, yaml_file: Path) -> dict:
        """
        加载 YAML 文件

        Args:
            yaml_file: YAML 文件路径

        Returns:
            解析后的字典
        """
        try:
            import yaml
            with open(yaml_file, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)
        except ImportError:
            print("错误: 需要安装 PyYAML 库", file=sys.stderr)
            print("运行: pip install pyyaml", file=sys.stderr)
            sys.exit(1)
        except yaml.YAMLError as e:
            raise ExtensionConfigError(f"YAML 解析错误: {e}")
        except FileNotFoundError:
            raise ExtensionConfigError(f"文件不存在: {yaml_file}")

    def load_config(self):
        """加载扩展配置文件"""
        if not self.config_file.exists():
            raise ExtensionConfigError(f"配置文件不存在: {self.config_file}")

        self.config = self.load_yaml(self.config_file)

        # 验证必需的配置项
        if 'extension_sets' not in self.config:
            raise ExtensionConfigError("配置文件缺少 'extension_sets' 部分")

        if 'default_sets' not in self.config:
            raise ExtensionConfigError("配置文件缺少 'default_sets' 部分")

    def load_metadata(self):
        """加载扩展元数据"""
        if self.metadata_file and self.metadata_file.exists():
            self.metadata = self.load_yaml(self.metadata_file)

    def resolve_extensions(self, set_names: List[str]) -> List[str]:
        """
        解析扩展集合名称为扩展列表

        Args:
            set_names: 扩展集合名称列表

        Returns:
            扩展名称列表
        """
        extensions = []
        extension_sets = self.config.get('extension_sets', {})

        for set_name in set_names:
            if set_name not in extension_sets:
                print(f"警告: 扩展集合 '{set_name}' 不存在，跳过", file=sys.stderr)
                continue

            set_exts = extension_sets[set_name]
            if not isinstance(set_exts, list):
                print(f"警告: 扩展集合 '{set_name}' 不是列表格式，跳过", file=sys.stderr)
                continue

            extensions.extend(set_exts)

        return extensions

    def apply_os_overrides(self, extensions: List[str], os_version: str) -> List[str]:
        """
        应用 OS 特定的覆盖规则

        Args:
            extensions: 原始扩展列表
            os_version: OS 版本 (ubuntu20.04, ubuntu22.04, etc.)

        Returns:
            应用覆盖后的扩展列表
        """
        os_overrides = self.config.get('os_overrides', {})

        if os_version not in os_overrides:
            return extensions

        override = os_overrides[os_version]
        result = list(extensions)

        # 添加额外的扩展
        additional = override.get('additional_extensions', [])
        if additional:
            result.extend(additional)
            print(f"信息: 为 {os_version} 添加扩展: {', '.join(additional)}")

        # 排除扩展
        exclude = override.get('exclude_extensions', [])
        if exclude:
            for ext in exclude:
                if ext in result:
                    result.remove(ext)
                    print(f"信息: 为 {os_version} 排除扩展: {ext}")

        return list(dict.fromkeys(result))  # 去重并保持顺序

    def detect_conflicts(self, extensions: List[str]) -> List[Tuple[str, str]]:
        """
        检测扩展冲突

        Args:
            extensions: 扩展列表

        Returns:
            冲突对列表 (ext1, ext2)
        """
        conflicts = []

        # 定义已知冲突
        known_conflicts = [
            ('postgis', 'postgis_raster'),  # postgis_raster 通常包含在 postgis 中
        ]

        for ext1, ext2 in known_conflicts:
            if ext1 in extensions and ext2 in extensions:
                conflicts.append((ext1, ext2))

        return conflicts

    def resolve_dependencies(self, extensions: List[str]) -> List[str]:
        """
        解析扩展依赖关系

        Args:
            extensions: 扩展列表

        Returns:
            包含依赖的扩展列表
        """
        if not self.metadata:
            return extensions

        resolved = list(extensions)
        visited = set(extensions)

        def add_dependencies(ext_name: str):
            """递归添加依赖"""
            ext_meta = self.metadata.get(ext_name, {})
            deps = ext_meta.get('dependencies', [])

            for dep in deps:
                if dep not in visited:
                    visited.add(dep)
                    resolved.append(dep)
                    add_dependencies(dep)

        for ext in extensions:
            add_dependencies(ext)

        return resolved

    def validate_extensions(self, extensions: List[str]) -> List[str]:
        """
        验证扩展可用性

        Args:
            extensions: 扩展列表

        Returns:
            验证通过的扩展列表
        """
        valid_extensions = []

        for ext in extensions:
            # 检查是否在元数据中
            if self.metadata and ext not in self.metadata:
                print(f"警告: 扩展 '{ext}' 不在元数据中，可能不可用", file=sys.stderr)

            valid_extensions.append(ext)

        return valid_extensions

    def categorize_extensions(self, extensions: List[str]) -> Dict[str, List[str]]:
        """
        分类扩展

        Args:
            extensions: 扩展列表

        Returns:
            按类别分组的扩展字典
        """
        categories = {
            'polar': [],
            'pigsty': [],
            'spatial': [],
            'custom': []
        }

        for ext in extensions:
            # 检查扩展类别
            if ext.startswith('polar_'):
                categories['polar'].append(ext)
            elif ext in ['postgis', 'postgis_raster', 'postgis_sfcgal',
                        'postgis_tiger_geocoder', 'address_standardizer',
                        'pgrouting', 'ogr_fdw', 'pggeoip']:
                categories['spatial'].append(ext)
            elif self.metadata and ext in self.metadata:
                ext_meta = self.metadata[ext]
                category = ext_meta.get('category', 'custom')
                if category not in categories:
                    category = 'custom'
                categories[category].append(ext)
            else:
                categories['custom'].append(ext)

        return categories

    def generate_install_script(self, extensions: List[str],
                                os_version: str,
                                output_file: Path):
        """
        生成扩展安装脚本

        Args:
            extensions: 扩展列表
            os_version: OS 版本
            output_file: 输出文件路径
        """
        # 分类扩展
        categorized = self.categorize_extensions(extensions)

        # 确定包管理器
        if os_version.startswith('ubuntu'):
            pkg_manager = 'apt-get'
            installer = 'apt-get install -y'
        else:  # anolis
            pkg_manager = 'yum'
            installer = 'yum install -y'

        # 生成脚本
        script_lines = [
            "#!/bin/bash",
            "#",
            f"# 扩展安装脚本 - {os_version}",
            f"# 自动生成 by parse-extensions.py",
            "#",
            "",
            "set -e",
            "",
            f"echo '开始为 {os_version} 安装扩展...'",
            "",
        ]

        # PolarDB 扩展 - 从源码编译
        if categorized['polar']:
            script_lines.extend([
                "",
                "# ============================================",
                "# PolarDB 内置扩展 (从源码编译)",
                "# ============================================",
                "",
                f"POLAR_EXTENSIONS={' '.join(categorized['polar'])}",
                "echo \"PolarDB 扩展: $POLAR_EXTENSIONS\"",
                "",
                "# 编译 PolarDB 扩展",
                "cd /build/polardb/external",
                f"for ext in $POLAR_EXTENSIONS; do",
                "    if [ -d \"$ext\" ]; then",
                "        echo \"编译扩展: $ext\"",
                "        make -C \"$ext\" install",
                "    else",
                "        echo \"警告: 扩展目录不存在: $ext\" >&2",
                "    fi",
                "done",
            ])

        # 空间扩展 - 从包管理器安装
        if categorized['spatial']:
            script_lines.extend([
                "",
                "# ============================================",
                "# 空间数据库扩展",
                "# ============================================",
                "",
                f"SPATIAL_EXTENSIONS={' '.join(categorized['spatial'])}",
                "echo \"空间扩展: $SPATIAL_EXTENSIONS\"",
                "",
                "# 安装空间扩展包",
                f"{installer} $SPATIAL_EXTENSIONS || {{",
                "    echo \"警告: 部分空间扩展安装失败\" >&2",
                "}",
            ])

        # Pigsty 扩展
        pigsty_config = self.config.get('extension_sources', {}).get('pigsty', {})
        if pigsty_config.get('enabled', False) and categorized['pigsty']:
            script_lines.extend([
                "",
                "# ============================================",
                "# Pigsty 扩展",
                "# ============================================",
                "",
                f"PIGSTY_EXTENSIONS={' '.join(categorized['pigsty'])}",
                "echo \"Pigsty 扩展: $PIGSTY_EXTENSIONS\"",
                "",
                "# 使用 pig 包管理器安装",
                "if command -v pig &> /dev/null; then",
                "    pig install $PIGSTY_EXTENSIONS || {",
                "        echo \"警告: 部分 Pigsty 扩展安装失败\" >&2",
                "    }",
                "else",
                "    echo \"错误: pig 包管理器未安装\" >&2",
                "    exit 1",
                "fi",
            ])

        # 自定义扩展
        if categorized['custom']:
            custom_exts = [e for e in categorized['custom']
                          if e not in categorized['polar']
                          and e not in categorized['spatial']
                          and e not in categorized['pigsty']]
            if custom_exts:
                script_lines.extend([
                    "",
                    "# ============================================",
                    "# 自定义扩展",
                    "# ============================================",
                    "",
                    f"CUSTOM_EXTENSIONS={' '.join(custom_exts)}",
                    "echo \"自定义扩展: $CUSTOM_EXTENSIONS\"",
                    "",
                    "# 尝试从包管理器安装",
                    f"{installer} $CUSTOM_EXTENSIONS 2>/dev/null || {{",
                    "    echo \"警告: 部分自定义扩展无法从包管理器安装\" >&2",
                    "}",
                ])

        # 完成
        script_lines.extend([
            "",
            "echo '扩展安装完成！'",
            "",
            "# 显示已安装的扩展",
            "echo ''",
            "echo '已安装的扩展:'",
            "psql -c 'SELECT name, default_version, installed_version FROM pg_available_extensions WHERE installed_version IS NOT NULL ORDER BY name;' || true",
            "",
        ])

        # 写入文件
        output_file.parent.mkdir(parents=True, exist_ok=True)
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(script_lines))

        # 设置可执行权限
        os.chmod(output_file, 0o755)

        print(f"✅ 生成安装脚本: {output_file}")

    def generate_metadata(self, extensions: List[str], os_version: str) -> dict:
        """
        生成扩展元数据

        Args:
            extensions: 扩展列表
            os_version: OS 版本

        Returns:
            元数据字典
        """
        categorized = self.categorize_extensions(extensions)

        return {
            'os_version': os_version,
            'total_count': len(extensions),
            'extensions': extensions,
            'categories': {
                category: len(exts)
                for category, exts in categorized.items()
            },
            'category_details': categorized
        }

    def parse(self, os_version: str, output_dir: str) -> Dict:
        """
        解析配置并生成脚本

        Args:
            os_version: 目标 OS 版本
            output_dir: 输出目录

        Returns:
            解析结果字典
        """
        # 加载配置和元数据
        self.load_config()
        self.load_metadata()

        # 解析默认扩展集合
        default_sets = self.config.get('default_sets', [])
        extensions = self.resolve_extensions(default_sets)

        print(f"信息: 默认扩展集合: {', '.join(default_sets)}")
        print(f"信息: 解析到 {len(extensions)} 个扩展")

        # 应用 OS 覆盖
        extensions = self.apply_os_overrides(extensions, os_version)

        # 解析依赖
        extensions = self.resolve_dependencies(extensions)

        # 验证扩展
        extensions = self.validate_extensions(extensions)

        # 检测冲突
        conflicts = self.detect_conflicts(extensions)
        if conflicts:
            print("警告: 检测到扩展冲突:", file=sys.stderr)
            for ext1, ext2 in conflicts:
                print(f"  - {ext1} 与 {ext2}", file=sys.stderr)

        # 去重
        extensions = list(dict.fromkeys(extensions))

        print(f"信息: 最终扩展列表 ({len(extensions)} 个):")
        for ext in extensions:
            print(f"  - {ext}")

        # 生成安装脚本
        output_path = Path(output_dir)
        script_file = output_path / f"install-extensions-{os_version}.sh"
        self.generate_install_script(extensions, os_version, script_file)

        # 生成元数据
        metadata = self.generate_metadata(extensions, os_version)
        metadata_file = output_path / f"extensions-metadata-{os_version}.json"
        with open(metadata_file, 'w', encoding='utf-8') as f:
            json.dump(metadata, f, indent=2, ensure_ascii=False)

        print(f"✅ 生成元数据文件: {metadata_file}")

        return {
            'extensions': extensions,
            'conflicts': conflicts,
            'metadata': metadata
        }


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description='PolarDB Docker 扩展配置解析器',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 为 Ubuntu 24.04 生成安装脚本
  python3 parse-extensions.py --os ubuntu24.04

  # 指定输出目录
  python3 parse-extensions.py --os anolis8 --output /tmp/scripts

  # 为所有支持的 OS 生成脚本
  for os in ubuntu20.04 ubuntu22.04 ubuntu24.04 anolis8 anolis23; do
      python3 parse-extensions.py --os $os
  done
        """
    )

    parser.add_argument(
        '--config',
        default='docker/extensions.yml',
        help='扩展配置文件路径 (默认: docker/extensions.yml)'
    )

    parser.add_argument(
        '--metadata',
        default='docker/scripts/extension-metadata.json',
        help='扩展元数据文件路径 (默认: docker/scripts/extension-metadata.json)'
    )

    parser.add_argument(
        '--os',
        required=True,
        choices=['ubuntu20.04', 'ubuntu22.04', 'ubuntu24.04',
                'anolis8', 'anolis23', 'all'],
        help='目标操作系统版本'
    )

    parser.add_argument(
        '--output',
        default='docker/scripts/generated',
        help='输出目录 (默认: docker/scripts/generated)'
    )

    args = parser.parse_args()

    # 处理 'all' 选项
    os_versions = (
        ['ubuntu20.04', 'ubuntu22.04', 'ubuntu24.04', 'anolis8', 'anolis23']
        if args.os == 'all'
        else [args.os]
    )

    # 为每个 OS 生成脚本
    for os_version in os_versions:
        print(f"\n{'='*60}")
        print(f"处理 OS 版本: {os_version}")
        print(f"{'='*60}\n")

        try:
            parser = ExtensionParser(
                config_file=args.config,
                metadata_file=args.metadata
            )

            result = parser.parse(
                os_version=os_version,
                output_dir=args.output
            )

            if result['conflicts']:
                print(f"\n⚠️  警告: 发现 {len(result['conflicts'])} 个扩展冲突")

            print(f"\n✅ 成功生成 {os_version} 的安装脚本")

        except ExtensionConfigError as e:
            print(f"\n❌ 配置错误: {e}", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            print(f"\n❌ 未知错误: {e}", file=sys.stderr)
            import traceback
            traceback.print_exc()
            sys.exit(1)

    print(f"\n{'='*60}")
    print("✅ 所有脚本生成完成！")
    print(f"{'='*60}\n")


if __name__ == '__main__':
    main()
