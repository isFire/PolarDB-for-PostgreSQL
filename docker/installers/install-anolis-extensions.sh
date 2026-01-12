#!/bin/bash
# =============================================================================
# Anolis/RHEL 扩展安装脚本
# =============================================================================
# 为 Anolis/RHEL 系统安装 PostgreSQL 扩展
# 自动生成 by parse-extensions.py
# =============================================================================

set -e

EXTENSIONS="${EXTENSIONS_LIST:-}"
PG_VERSION="${PG_MAJOR:-15}"

echo "=========================================="
echo "Anolis 扩展安装脚本"
echo "=========================================="
echo "PostgreSQL 版本: ${PG_VERSION}"
echo "扩展列表: ${EXTENSIONS}"
echo ""

# 安装 PolarDB 扩展（从源码编译）
install_polar_extensions() {
    local polar_exts=""

    for ext in $EXTENSIONS; do
        if [[ "$ext" == polar_* ]]; then
            polar_exts="$polar_exts $ext"
        fi
    done

    if [ -n "$polar_exts" ]; then
        echo "[1/4] 安装 PolarDB 扩展: $polar_exts"

        if [ -d /build/polardb/external ]; then
            cd /build/polardb/external

            for ext in $polar_exts; do
                if [ -d "$ext" ]; then
                    echo "  编译 $ext..."
                    make -C "$ext" install || {
                        echo "  警告: $ext 编译失败，跳过"
                    }
                else
                    echo "  警告: 扩展目录不存在: $ext"
                fi
            done
        else
            echo "  警告: PolarDB 源码目录不存在"
        fi
    fi
}

# 安装空间扩展（从包管理器）
install_spatial_extensions() {
    local spatial_exts=""

    for ext in $EXTENSIONS; do
        case "$ext" in
            postgis|pgrouting)
                spatial_exts="$spatial_exts $ext"
                ;;
        esac
    done

    if [ -n "$spatial_exts" ]; then
        echo "[2/4] 安装空间扩展: $spatial_exts"

        # Anolis/RHEL 的空间扩展包名可能不同
        dnf install -y \
            postgis${PG_VERSION//.} \
            postgis${PG_VERSION//.}-client \
            pgrouting${PG_VERSION//.} || {
            echo "  警告: 空间扩展包不可用，尝试 EPEL"

            # 尝试启用 EPEL
            dnf install -y epel-release || true

            dnf install -y \
                postgis${PG_VERSION//.} \
                pgrouting${PG_VERSION//.} || {
                echo "  警告: 无法安装空间扩展"
            }
        }

        # 复制扩展文件
        if [ -d /usr/local/polardb/lib ]; then
            find /usr/lib64/postgresql/* -name "*.so" -exec cp -f {} /usr/local/polardb/lib/ \; 2>/dev/null || true
            find /usr/lib64 -name "*.so" -exec cp -f {} /usr/local/polardb/lib/ \; 2>/dev/null || true
        fi

        if [ -d /usr/local/polardb/share/extension ]; then
            find /usr/share/pgsql* -name "*.sql" -exec cp -f {} /usr/local/polardb/share/extension/ \; 2>/dev/null || true
            find /usr/share/pgsql* -name "*.control" -exec cp -f {} /usr/local/polardb/share/extension/ \; 2>/dev/null || true
        fi
    fi
}

# 安装其他扩展
install_other_extensions() {
    local other_exts=""

    for ext in $EXTENSIONS; do
        case "$ext" in
            polar_*|postgis*|pgrouting)
                continue
                ;;
            *)
                other_exts="$other_exts $ext"
                ;;
        esac
    done

    if [ -n "$other_exts" ]; then
        echo "[3/4] 安装其他扩展: $other_exts"

        # 常见扩展的 RPM 包名映射
        declare -A pkg_map
        pkg_map[pgvector]="pgvector_${PG_VERSION//.}"
        pkg_map[hll]="hll_pg${PG_VERSION//.}"
        pkg_map[pg_repack]="pg_repack_${PG_VERSION//.}"
        pkg_map[pg_stat_statements]="pg_stat_statements"

        for ext in $other_exts; do
            pkg_name="${pkg_map[$ext]}"

            if [ -n "$pkg_name" ]; then
                echo "  安装 $ext (包: $pkg_name)..."
                dnf install -y "$pkg_name" || {
                    echo "  警告: 无法安装 $ext"
                }
            fi

            # 如果包安装失败，尝试从源码编译
            if [ -d "/build/polardb/external/$ext" ]; then
                echo "  从源码编译 $ext..."
                make -C "/build/polardb/external/$ext" install || {
                    echo "  警告: $ext 编译失败"
                }
            fi
        done
    fi
}

# 清理和验证
cleanup_and_verify() {
    echo "[4/4] 清理和验证..."

    # 清理缓存
    dnf clean all || true

    # 验证扩展
    echo ""
    echo "已安装的扩展:"
    ls -la /usr/local/polardb/lib/ | grep -E "\.so$" || echo "  (无 .so 文件)"
    ls -la /usr/local/polardb/share/extension/ | grep -E "\.(sql|control)$" || echo "  (无扩展文件)"

    echo ""
    echo "=========================================="
    echo "✅ 扩展安装完成！"
    echo "=========================================="
}

# 主安装流程
main() {
    install_polar_extensions
    install_spatial_extensions
    install_other_extensions
    cleanup_and_verify
}

# 执行主函数
main
