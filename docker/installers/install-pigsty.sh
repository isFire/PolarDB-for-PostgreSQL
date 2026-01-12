#!/bin/bash
# =============================================================================
# Pigsty 仓库配置和扩展安装脚本
# =============================================================================
# 配置 Pigsty 包仓库并安装扩展
# 自动生成 by parse-extensions.py
# =============================================================================

set -e

PIGSTY_EXTENSIONS="${PIGSTY_EXTENSIONS_LIST:-}"
OS_FAMILY="${OS_FAMILY:-}"
PG_VERSION="${PG_MAJOR:-15}"

echo "=========================================="
echo "Pigsty 扩展安装"
echo "=========================================="
echo "OS 类型: ${OS_FAMILY}"
echo "PostgreSQL 版本: ${PG_VERSION}"
echo "扩展列表: ${PIGSTY_EXTENSIONS}"
echo ""

# 检测 OS 类型
if [ -z "$OS_FAMILY" ]; then
    if [ -f /etc/debian_version ]; then
        OS_FAMILY="debian"
    elif [ -f /etc/redhat-release ]; then
        OS_FAMILY="rhel"
    else
        echo "错误: 无法检测 OS 类型"
        exit 1
    fi
fi

# 配置 Pigsty 仓库
setup_pigsty_repo() {
    echo "[1/3] 配置 Pigsty 包仓库..."

    if [ "$OS_FAMILY" = "debian" ]; then
        echo "  配置 Ubuntu/Debian 仓库..."

        # 安装必要工具
        apt-get update -qq
        apt-get install -y -qq curl ca-certificates gnupg

        # 添加 Pigsty APT 仓库
        curl -fsSL https://repo.pigsty.io/apt | bash

        # 更新包列表
        apt-get update -qq

    elif [ "$OS_FAMILY" = "rhel" ]; then
        echo "  配置 RHEL/CentOS/Anolis 仓库..."

        # 安装必要工具
        dnf install -y -q curl ca-certificates gnupg2 || true

        # 添加 Pigsty YUM 仓库
        curl -fsSL https://repo.pigsty.io/yum | bash

        # 清理缓存
        dnf clean all

    else
        echo "  错误: 不支持的 OS 类型: $OS_FAMILY"
        return 1
    fi

    echo "  ✅ Pigsty 仓库配置完成"
}

# 安装 pig 包管理器
install_pig_package_manager() {
    echo "[2/3] 安装 pig 包管理器..."

    if [ "$OS_FAMILY" = "debian" ]; then
        apt-get install -y -qq pig || {
            echo "  警告: 无法从 APT 安装 pig"
            return 1
        }
    elif [ "$OS_FAMILY" = "rhel" ]; then
        dnf install -y -q pig || {
            echo "  警告: 无法从 YUM 安装 pig"
            return 1
        }
    fi

    echo "  ✅ pig 包管理器安装完成"
}

# 安装 Pigsty 扩展
install_pigsty_extensions() {
    if [ -z "$PIGSTY_EXTENSIONS" ]; then
        echo "[3/3] 无需安装 Pigsty 扩展"
        return 0
    fi

    echo "[3/3] 安装 Pigsty 扩展: $PIGSTY_EXTENSIONS"

    # 检查 pig 是否可用
    if ! command -v pig &> /dev/null; then
        echo "  错误: pig 包管理器未安装"
        return 1
    fi

    # 安装扩展
    for ext in $PIGSTY_EXTENSIONS; do
        echo "  安装 $ext..."

        pig install "$ext" || {
            echo "  警告: 无法安装 $ext，尝试回退方案"

            # 回退：尝试从源码编译
            install_from_source "$ext"
        }
    done

    echo "  ✅ Pigsty 扩展安装完成"
}

# 从源码安装（回退方案）
install_from_source() {
    local ext="$1"

    echo "    尝试从源码编译 $ext..."

    # 检查 PolarDB external 目录
    if [ -d "/build/polardb/external/$ext" ]; then
        make -C "/build/polardb/external/$ext" install || {
            echo "    警告: $ext 源码编译也失败"
        }
    else
        echo "    信息: $ext 源码目录不存在"
    fi
}

# 主安装流程
main() {
    setup_pigsty_repo
    install_pig_package_manager
    install_pigsty_extensions

    echo ""
    echo "=========================================="
    echo "✅ Pigsty 扩展安装完成！"
    echo "=========================================="
}

# 执行主函数
main
