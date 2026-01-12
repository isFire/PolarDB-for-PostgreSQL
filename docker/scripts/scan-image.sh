#!/bin/bash
# =============================================================================
# 镜像安全扫描和验证脚本
# =============================================================================
# 使用 Trivy 扫描 Docker 镜像漏洞
# =============================================================================

set -e

IMAGE="${1:-}"
SEVERITY="${2:-HIGH,CRITICAL}"
OUTPUT_FORMAT="${3:-table}"

echo "=========================================="
echo "Docker 镜像安全扫描"
echo "=========================================="
echo "镜像: ${IMAGE}"
echo "严重级别: ${SEVERITY}"
echo ""

# 检查 Trivy 是否安装
if ! command -v trivy &> /dev/null; then
    echo "错误: Trivy 未安装"
    echo ""
    echo "安装 Trivy:"
    echo "  macOS: brew install trivy"
    echo "  Linux:"
    echo "    wget -qO - https://github.com/aquasecurity/trivy/releases/download/v0.50.0/trivy_0.50.0_Linux-64bit.tar.gz"
    echo "    tar -xzf trivy_0.50.0_Linux-64bit.tar.gz"
    echo "    sudo mv trivy /usr/local/bin/"
    exit 1
fi

# 检查镜像是否存在
if ! docker image inspect "$IMAGE" &> /dev/null; then
    echo "警告: 镜像 ${IMAGE} 不在本地"
    echo "尝试拉取镜像..."
    docker pull "$IMAGE" || {
        echo "错误: 无法拉取镜像 ${IMAGE}"
        exit 1
    }
fi

echo "[1/3] 扫描镜像漏洞..."
echo ""

# 执行扫描
trivy image --severity "$SEVERITY" --format "$OUTPUT_FORMAT" "$IMAGE"

echo ""
echo "[2/3] 扫描镜像配置..."
echo ""

trivy image --severity "$SEVERITY" --format "$OUTPUT_FORMAT" \
    --scanners config,secrets "$IMAGE" || true

echo ""
echo "[3/3] 生成完整报告..."
echo ""

# 生成 SARIF 报告（用于 GitHub Security）
REPORT_FILE="trivy-report-$(date +%Y%m%d-%H%M%S).sarif"
trivy image --severity "$SEVERITY" --format sarif \
    --output "$REPORT_FILE" "$IMAGE" || true

echo "报告已保存: $REPORT_FILE"

echo ""
echo "=========================================="
echo "✅ 安全扫描完成！"
echo "=========================================="
echo ""
echo "建议:"
echo "  • 修复 HIGH 和 CRITICAL 级别的漏洞"
echo "  • 使用最小化基础镜像"
echo "  • 定期更新基础镜像和扩展"
echo "  • 启用 Docker Content Trust 签名镜像"
