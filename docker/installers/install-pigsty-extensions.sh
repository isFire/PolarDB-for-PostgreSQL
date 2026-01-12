#!/bin/bash
# =============================================================================
# Pigsty 扩展安装脚本
# =============================================================================
# 使用 pig 包管理器安装 Pigsty 扩展
# 支持失败时回退到源码构建
# 自动生成 by parse-extensions.py
# =============================================================================

set -e

# =============================================================================
# 配置变量
# =============================================================================

PIGSTY_EXTENSIONS="${PIGSTY_EXTENSIONS_LIST:-}"
OS_FAMILY="${OS_FAMILY:-}"
PG_VERSION="${PG_MAJOR:-15}"
BUILD_FROM_SOURCE="${BUILD_FROM_SOURCE:-true}"
MAX_RETRIES="${MAX_RETRIES:-2}"

# 日志文件
LOG_FILE="/tmp/pigsty-extension-install.log"
METADATA_FILE="/tmp/pigsty-extension-metadata.json"

# =============================================================================
# 辅助函数
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_success() {
    log "SUCCESS" "$@"
}

# =============================================================================
# 依赖解析
# =============================================================================

# 扩展依赖映射（Pigsty 扩展的常见依赖）
declare -A EXTENSION_DEPENDENCIES
EXTENSION_DEPENDENCIES=(
    ["postgis_raster"]="postgis"
    ["postgis_tiger_geocoder"]="postgis postgis_sfcgal"
    ["address_standardizer"]="postgis"
    ["pgrouting"]="postgis"
    ["timescaledb"]=""
    ["pgvector"]=""
    ["pg_repack"]=""
    ["pg_cron"]=""
    ["plv8"]=""
    ["pg_auto_failover"]=""
    ["hll"]=""
    ["tdigest"]=""
)

resolve_dependencies() {
    local ext="$1"
    local deps="${EXTENSION_DEPENDENCIES[$ext]}"

    if [ -n "$deps" ]; then
        echo "$deps"
    fi
}

check_dependencies_installed() {
    local ext="$1"
    local deps
    deps=$(resolve_dependencies "$ext")

    if [ -z "$deps" ]; then
        return 0
    fi

    log_info "检查 $ext 的依赖: $deps"

    for dep in $deps; do
        if ! psql -c "SELECT 1 FROM pg_available_extensions WHERE name = '$dep'" | grep -q 1; then
            log_warn "依赖 $dep 未安装"
            return 1
        fi
    done

    return 0
}

install_dependencies() {
    local ext="$1"
    local deps
    deps=$(resolve_dependencies "$ext")

    if [ -z "$deps" ]; then
        return 0
    fi

    log_info "安装 $ext 的依赖: $deps"

    for dep in $deps; do
        # 检查是否已在 Pigsty 扩展列表中
        if echo "$PIGSTY_EXTENSIONS" | grep -q "$dep"; then
            log_info "依赖 $dep 已在安装列表中"
            continue
        fi

        # 尝试安装依赖
        log_info "安装依赖: $dep"
        pig install "$dep" || {
            log_warn "无法安装依赖 $dep，尝试从源码"
            install_extension_from_source "$dep"
        }
    done
}

# =============================================================================
# 扩展安装
# =============================================================================

install_extension_with_pig() {
    local ext="$1"
    local retry="$2"

    log_info "使用 pig 安装 $ext (尝试 $retry/$MAX_RETRIES)"

    # 安装依赖
    install_dependencies "$ext"

    # 使用 pig 安装
    if pig install "$ext" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "成功安装 $ext"
        record_extension_metadata "$ext" "pig" "success"
        return 0
    else
        log_error "pig 安装 $ext 失败"
        record_extension_metadata "$ext" "pig" "failed"
        return 1
    fi
}

install_extension_from_source() {
    local ext="$1"

    if [ "$BUILD_FROM_SOURCE" != "true" ]; then
        log_info "跳过从源码编译 $ext (BUILD_FROM_SOURCE=false)"
        return 1
    fi

    log_info "尝试从源码编译 $ext"

    # 检查 PolarDB external 目录
    if [ -d "/build/polardb/external/$ext" ]; then
        log_info "在 PolarDB external 目录中找到 $ext"

        # 检查是否有 Makefile
        if [ -f "/build/polardb/external/$ext/Makefile" ]; then
            log_info "编译 $ext..."

            if make -C "/build/polardb/external/$ext" clean install 2>&1 | tee -a "$LOG_FILE"; then
                log_success "成功从源码编译 $ext"
                record_extension_metadata "$ext" "source" "success"
                return 0
            else
                log_error "从源码编译 $ext 失败"
                record_extension_metadata "$ext" "source" "failed"
                return 1
            fi
        else
            log_warn "没有找到 Makefile，跳过编译"
            record_extension_metadata "$ext" "source" "no-makefile"
            return 1
        fi
    else
        log_info "$ext 不在 PolarDB external 目录中"
        record_extension_metadata "$ext" "source" "not-found"
        return 1
    fi
}

install_extension_with_fallback() {
    local ext="$1"
    local retry=1

    log_info "开始安装扩展: $ext"

    while [ $retry -le $MAX_RETRIES ]; do
        # 尝试使用 pig 安装
        if install_extension_with_pig "$ext" "$retry"; then
            return 0
        fi

        # 重试
        retry=$((retry + 1))

        if [ $retry -le $MAX_RETRIES ]; then
            log_info "等待 2 秒后重试..."
            sleep 2
        fi
    done

    # 所有 pig 尝试都失败，尝试从源码编译
    log_warn "pig 安装失败，尝试从源码编译"
    if install_extension_from_source "$ext"; then
        return 0
    fi

    # 所有方法都失败
    log_error "无法安装 $ext"
    record_extension_metadata "$ext" "all" "failed"
    return 1
}

# =============================================================================
# 元数据记录
# =============================================================================

init_metadata() {
    cat > "$METADATA_FILE" <<EOF
{
  "install_timestamp": "$(date -Iseconds)",
  "os_family": "$OS_FAMILY",
  "pg_version": "$PG_VERSION",
  "extensions": {}
}
EOF
}

record_extension_metadata() {
    local ext="$1"
    local method="$2"
    local status="$3"

    # 使用 jq 更新 JSON，如果没有 jq 则使用 sed
    if command -v jq &> /dev/null; then
        jq --arg ext "$ext" \
           --arg method "$method" \
           --arg status "$status" \
           --arg timestamp "$(date -Iseconds)" \
           '.extensions[$ext] = {
               method: $method,
               status: $status,
               timestamp: $timestamp
           }' "$METADATA_FILE" > "${METADATA_FILE}.tmp" &&
        mv "${METADATA_FILE}.tmp" "$METADATA_FILE"
    else
        # 简单的 JSON 追加（不推荐，仅作为后备方案）
        echo "  \"$ext\": {\"method\": \"$method\", \"status\": \"$status\", \"timestamp\": \"$(date -Iseconds)\"}" >> "$METADATA_FILE.tmp"
    fi
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "安装摘要"
    echo "=========================================="

    if [ -f "$METADATA_FILE" ]; then
        echo "详细安装信息: $METADATA_FILE"
        echo ""

        if command -v jq &> /dev/null; then
            jq '.' "$METADATA_FILE" || cat "$METADATA_FILE"
        else
            cat "$METADATA_FILE"
        fi
    fi

    echo ""
    echo "日志文件: $LOG_FILE"
}

# =============================================================================
# 验证安装
# =============================================================================

verify_extension() {
    local ext="$1"

    log_info "验证 $ext 安装..."

    # 检查扩展是否在可用扩展列表中
    if psql -c "SELECT 1 FROM pg_available_extensions WHERE name = '$ext'" | grep -q 1; then
        log_success "$ext 已正确安装"

        # 显示扩展版本信息
        psql -c "SELECT name, default_version, installed_version FROM pg_available_extensions WHERE name = '$ext';" | tee -a "$LOG_FILE"

        return 0
    else
        log_error "$exp 未找到"
        return 1
    fi
}

# =============================================================================
# 主安装流程
# =============================================================================

main() {
    echo "=========================================="
    echo "Pigsty 扩展安装"
    echo "=========================================="
    echo "开始时间: $(date)"
    echo "OS 类型: ${OS_FAMILY}"
    echo "PostgreSQL 版本: ${PG_VERSION}"
    echo "扩展列表: ${PIGSTY_EXTENSIONS}"
    echo "最大重试次数: ${MAX_RETRIES}"
    echo "从源码编译: ${BUILD_FROM_SOURCE}"
    echo ""

    # 检查参数
    if [ -z "$PIGSTY_EXTENSIONS" ]; then
        log_info "未指定 Pigsty 扩展，退出"
        exit 0
    fi

    # 检查 pig 命令
    if ! command -v pig &> /dev/null; then
        log_error "pig 包管理器未安装，请先运行 install-pigsty.sh"
        exit 1
    fi

    # 初始化日志和元数据
    echo "" > "$LOG_FILE"
    init_metadata

    # 统计变量
    local total=0
    local success=0
    local failed=0

    # 安装每个扩展
    for ext in $PIGSTY_EXTENSIONS; do
        total=$((total + 1))
        echo ""
        echo "=========================================="
        echo "[$total] 安装扩展: $ext"
        echo "=========================================="

        if install_extension_with_fallback "$ext"; then
            success=$((success + 1))
            verify_extension "$ext"
        else
            failed=$((failed + 1))
        fi
    done

    # 打印摘要
    print_summary

    echo ""
    echo "=========================================="
    echo "安装统计"
    echo "=========================================="
    echo "总数: $total"
    echo "成功: $success"
    echo "失败: $failed"
    echo ""

    if [ $failed -gt 0 ]; then
        log_warn "部分扩展安装失败"
        exit 1
    fi

    log_success "所有扩展安装完成！"
    exit 0
}

# 执行主函数
main
