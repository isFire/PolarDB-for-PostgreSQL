#!/bin/bash
# =============================================================================
# PolarDB Dockerfile 生成脚本
# =============================================================================
# 用途: 根据 OS 版本和扩展列表生成最终的 Dockerfile
# 用法: ./generate-dockerfile.sh --os ubuntu24.04 [--extensions "ext1 ext2"]
# =============================================================================

set -e

# 默认参数
OS_VERSION=""
EXTENSIONS=""
OUTPUT_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [OPTIONS]

生成 PolarDB Docker 镜像的 Dockerfile

选项:
    --os OS_VERSION        目标操作系统版本
                          (ubuntu20.04, ubuntu22.04, ubuntu24.04, anolis8, anolis23)
    --extensions "LIST"    扩展列表（可选，默认从 extensions.yml 读取）
    --output DIR           输出目录（可选，默认: docker/generated）
    --help                 显示此帮助信息

示例:
    $0 --os ubuntu24.04
    $0 --os anolis8 --output /tmp/docker
    $0 --os ubuntu22.04 --extensions "postgis pgvector"

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --os)
            OS_VERSION="$2"
            shift 2
            ;;
        --extensions)
            EXTENSIONS="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "错误: 未知参数 $1"
            show_help
            exit 1
            ;;
    esac
done

# 验证必需参数
if [ -z "$OS_VERSION" ]; then
    echo "错误: 必须指定 --os 参数"
    show_help
    exit 1
fi

# 设置默认输出目录
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$PROJECT_ROOT/docker/generated"
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 确定 OS 类型和版本
if [[ "$OS_VERSION" =~ ^ubuntu ]]; then
    OS_TYPE="ubuntu"
    VERSION="${OS_VERSION#ubuntu}"
elif [[ "$OS_VERSION" =~ ^anolis ]]; then
    OS_TYPE="anolis"
    VERSION="${OS_VERSION#anolis}"
else
    echo "错误: 不支持的 OS 版本: $OS_VERSION"
    exit 1
fi

# 选择模板文件
TEMPLATE_FILE="$PROJECT_ROOT/docker/templates/Dockerfile.${OS_TYPE}.tmpl"
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "错误: 模板文件不存在: $TEMPLATE_FILE"
    exit 1
fi

# 如果没有提供扩展列表，从 extensions.yml 解析
if [ -z "$EXTENSIONS" ]; then
    echo "信息: 从 extensions.yml 解析扩展列表"
    if [ -f "$SCRIPT_DIR/parse-extensions.py" ]; then
        # 调用 Python 解析器
        cd "$PROJECT_ROOT"
        python3 "$SCRIPT_DIR/parse-extensions.py" --os "$OS_VERSION" --output "$(dirname "$OUTPUT_DIR")"

        # 读取生成的元数据获取扩展列表
        METADATA_FILE="$(dirname "$OUTPUT_DIR")/extensions-metadata-${OS_VERSION}.json"
        if [ -f "$METADATA_FILE" ]; then
            EXTENSIONS=$(python3 -c "import json; d=json.load(open('$METADATA_FILE')); print(' '.join(d['extensions']))" 2>/dev/null || echo "")
        fi
    else
        echo "警告: parse-extensions.py 不存在，使用默认扩展集"
        EXTENSIONS="polar_audit polar_monitor"
    fi
fi

# 如果仍然没有扩展列表，使用默认值
if [ -z "$EXTENSIONS" ]; then
    echo "警告: 使用默认扩展集"
    EXTENSIONS="polar_audit polar_monitor"
fi

echo "信息: 生成 Dockerfile for $OS_VERSION"
echo "信息: 扩展列表: $EXTENSIONS"

# 设置构建参数
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
OUTPUT_FILE="$OUTPUT_DIR/Dockerfile.${OS_VERSION}"

# 使用 envsubst 替换模板变量
export UBUNTU_VERSION="$VERSION"
export ANOLIS_VERSION="$VERSION"
export EXTENSIONS_LIST="$EXTENSIONS"
export BUILD_DATE="$BUILD_DATE"
export VCS_REF="$VCS_REF"

# 生成 Dockerfile
if command -v envsubst &> /dev/null; then
    envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
else
    # 如果没有 envsubst，使用 sed 替换
    sed -e "s/\${UBUNTU_VERSION}/$VERSION/g" \
        -e "s/\${ANOLIS_VERSION}/$VERSION/g" \
        -e "s/\${EXTENSIONS_LIST}/$EXTENSIONS/g" \
        -e "s/\${BUILD_DATE}/$BUILD_DATE/g" \
        -e "s/\${VCS_REF}/$VCS_REF/g" \
        "$TEMPLATE_FILE" > "$OUTPUT_FILE"
fi

echo "✅ 生成 Dockerfile: $OUTPUT_FILE"

# 验证生成的 Dockerfile
if command -v docker &> /dev/null; then
    echo "信息: 验证 Dockerfile 语法..."
    if docker df --help &> /dev/null; then
        echo "信息: Dockerfile 语法检查跳过（需要 docker build 测试）"
    fi
fi

# 生成构建参数文件
cat > "$OUTPUT_DIR/build-args.${OS_VERSION}.sh" << EOF
#!/bin/bash
# Docker 构建参数
# 自动生成 by generate-dockerfile.sh

export UBUNTU_VERSION="${VERSION}"
export ANOLIS_VERSION="${VERSION}"
export EXTENSIONS_LIST="${EXTENSIONS}"
export BUILD_DATE="${BUILD_DATE}"
export VCS_REF="${VCS_REF}"

echo "构建参数:"
echo "  OS 版本: ${OS_VERSION}"
echo "  扩展列表: ${EXTENSIONS}"
echo "  构建日期: ${BUILD_DATE}"
echo "  Git 引用: ${VCS_REF}"
EOF

chmod +x "$OUTPUT_DIR/build-args.${OS_VERSION}.sh"
echo "✅ 生成构建参数文件: $OUTPUT_DIR/build-args.${OS_VERSION}.sh"

echo ""
echo "================================================================================"
echo "✅ Dockerfile 生成完成！"
echo "================================================================================"
echo ""
echo "下一步:"
echo "  1. 查看生成的 Dockerfile: cat $OUTPUT_FILE"
echo "  2. 构建 Docker 镜像:"
echo "     docker build -f $OUTPUT_FILE \\"
echo "       --build-arg UBUNTU_VERSION=${VERSION} \\"
echo "       --build-arg EXTENSIONS_LIST=\"${EXTENSIONS}\" \\"
echo "       -t polardb:${OS_VERSION} ."
echo ""
