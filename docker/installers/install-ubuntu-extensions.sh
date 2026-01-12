#!/bin/bash
# =============================================================================
# Ubuntu 扩展安装脚本
# =============================================================================
# 为 Ubuntu 系统安装 PostgreSQL 扩展
# 自动生成 by parse-extensions.py
# =============================================================================

set -e

EXTENSIONS="${EXTENSIONS_LIST:-}"
PG_VERSION="${PG_MAJOR:-15}"

echo "=========================================="
echo "Ubuntu 扩展安装脚本"
echo "=========================================="
echo "PostgreSQL 版本: ${PG_VERSION}"
echo "扩展列表: ${EXTENSIONS}"
echo ""

# 更新包列表并安装基础工具
echo "[1/5] 更新包管理器..."
apt-get update -qq

# 安装 PolarDB 扩展（从源码编译）
install_polar_extensions() {
    local polar_exts=""

    for ext in $EXTENSIONS; do
        if [[ "$ext" == polar_* ]]; then
            polar_exts="$polar_exts $ext"
        fi
    done

    if [ -n "$polar_exts" ]; then
        echo "[2/5] 安装 PolarDB 扩展: $polar_exts"

        # 确保 PolarDB 源码目录存在
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
            postgis|postgis_raster|postgis_sfcgal|postgis_tiger_geocoder|address_standardizer|pgrouting|ogr_fdw|pggeoip)
                spatial_exts="$spatial_exts $ext"
                ;;
        esac
    done

    if [ -n "$spatial_exts" ]; then
        echo "[3/5] 安装空间扩展: $spatial_exts"

        # 安装空间扩展包
        apt-get install -y --no-install-recommends \
            postgresql-${PG_VERSION}-postgis-3 \
            postgresql-${PG_VERSION}-postgis-3-scripts \
            postgresql-${PG_VERSION}-postgis-3-tiger-geocoder \
            postgresql-${PG_VERSION}-address-standardizer \
            postgresql-${PG_VERSION}-pgrouting \
            postgresql-${PG_VERSION}-pgrouting-scripts || {
            echo "  警告: 部分空间扩展安装失败"
        }

        # 复制扩展到 PolarDB 安装目录
        if [ -d /usr/local/polardb/lib ]; then
            cp -f /usr/lib/postgresql/${PG_VERSION}/lib/*.so /usr/local/polardb/lib/ 2>/dev/null || true
        fi

        if [ -d /usr/local/polardb/share/extension ]; then
            cp -f /usr/share/postgresql/${PG_VERSION}/extension/*.sql /usr/local/polardb/share/extension/ 2>/dev/null || true
            cp -f /usr/share/postgresql/${PG_VERSION}/extension/*.control /usr/local/polardb/share/extension/ 2>/dev/null || true
        fi
    fi
}

# 安装 Pigsty 扩展
install_pigsty_extensions() {
    local pigsty_exts=""

    for ext in $EXTENSIONS; do
        # 检查是否是需要从 Pigsty 安装的扩展
        case "$ext" in
            timescaledb|pg_cron|pg_auto_failover|plv8|pg_stat_statements)
                pigsty_exts="$pigsty_exts $ext"
                ;;
        esac
    done

    if [ -n "$pigsty_exts" ]; then
        echo "[4/5] 安装 Pigsty 扩展: $pigsty_exts"

        # 检查 pig 是否可用
        if command -v pig &> /dev/null; then
            for ext in $pigsty_exts; do
                echo "  安装 $ext..."
                pig install "$ext" || {
                    echo "  警告: 无法从 Pigsty 安装 $ext"
                }
            done
        else
            echo "  信息: pig 包管理器未安装，尝试从包管理器安装"

            # 尝试从 Ubuntu 仓库安装
            apt-get install -y --no-install-recommends \
                postgresql-${PG_VERSION}-timescaledb \
                postgresql-${PG_VERSION}-pgcron || {
                echo "  警告: 部分 Pigsty 扩展无法安装"
            }
        fi
    fi
}

# 安装其他扩展（从包管理器）
install_other_extensions() {
    local other_exts=""

    # 排除已处理的扩展
    for ext in $EXTENSIONS; do
        case "$ext" in
            polar_*|postgis*|pgrouting|address_standardizer|ogr_fdw|pggeoip|timescaledb|pg_cron|pg_auto_failover|plv8|pg_stat_statements)
                continue
                ;;
            *)
                other_exts="$other_exts $ext"
                ;;
        esac
    done

    if [ -n "$other_exts" ]; then
        echo "[5/5] 安装其他扩展: $other_exts"

        # 尝试从包管理器安装
        apt-get install -y --no-install-recommends \
            postgresql-${PG_VERSION}-pgvector \
            postgresql-${PG_VERSION}-hll \
            postgresql-${PG_VERSION}-repack \
            postgresql-${PG_VERSION}-pg-stat-statements || {
            echo "  警告: 部分扩展无法从包管理器安装"
        }

        # 对于无法从包管理器安装的扩展，尝试编译
        for ext in $other_exts; do
            if [ -d "/build/polardb/external/$ext" ]; then
                echo "  编译 $ext..."
                make -C "/build/polardb/external/$ext" install || {
                    echo "  警告: $ext 编译失败"
                }
            fi
        done
    fi
}

# 主安装流程
main() {
    install_polar_extensions
    install_spatial_extensions
    install_pigsty_extensions
    install_other_extensions

    echo ""
    echo "=========================================="
    echo "✅ 扩展安装完成！"
    echo "=========================================="
}

# 执行主函数
main
