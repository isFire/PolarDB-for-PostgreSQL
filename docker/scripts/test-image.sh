#!/bin/bash
# =============================================================================
# Docker 镜像测试脚本
# =============================================================================
# 验证生成的 Docker 镜像功能
# =============================================================================

set -e

IMAGE="${1:-polardb:latest}"
POSTGRES_USER="${POSTGRES_USER:-polardb}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-polardb}"
POSTGRES_DB="${POSTGRES_DB:-polardb}"

echo "=========================================="
echo "Docker 镜像测试"
echo "=========================================="
echo "镜像: ${IMAGE}"
echo ""

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0

# 测试函数
test_case() {
    local name="$1"
    local command="$2"

    echo "测试: $name"
    if eval "$command"; then
        echo "  ✅ 通过"
        ((TESTS_PASSED++))
        return 0
    else
        echo "  ❌ 失败"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 启动容器
echo "[1/6] 启动容器..."
CONTAINER_ID=$(docker run -d \
    --name polardb-test \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -p 5432:5432 \
    "$IMAGE")

echo "容器 ID: $CONTAINER_ID"
echo ""

# 等待容器启动
echo "等待数据库启动..."
sleep 10

# 测试数据库连接
echo "[2/6] 测试数据库连接..."
test_case "pg_isready" "docker exec $CONTAINER_ID pg_isready -U $POSTGRES_USER"

# 测试扩展加载
echo "[3/6] 测试扩展加载..."
test_case "列出扩展" "docker exec $CONTAINER_ID psql -U $POSTGRES_USER -d $POSTGRES_DB -c '\dx' 2>/dev/null"

# 测试创建数据库
echo "[4/6] 测试数据库操作..."
test_case "创建表" "docker exec $CONTAINER_ID psql -U $POSTGRES_USER -d $POSTGRES_DB -c 'CREATE TABLE test_table (id serial primary key, name text);' 2>/dev/null"

# 测试插入数据
echo "[5/6] 测试数据插入..."
test_case "插入数据" "docker exec $CONTAINER_ID psql -U $POSTGRES_USER -d $POSTGRES_DB -c \"INSERT INTO test_table (name) VALUES ('test');\" 2>/dev/null"

# 测试查询数据
echo "[6/6] 测试数据查询..."
test_case "查询数据" "docker exec $CONTAINER_ID psql -U $POSTGRES_USER -d $POSTGRES_DB -c 'SELECT COUNT(*) FROM test_table;' 2>/dev/null"

# 检查镜像元数据
echo ""
echo "=========================================="
echo "镜像元数据"
echo "=========================================="

docker inspect "$IMAGE" | grep -A 10 '"Labels":' || true

# 检查镜像大小
echo ""
echo "镜像信息:"
docker images "$IMAGE" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# 停止并删除容器
echo ""
echo "清理测试容器..."
docker stop $CONTAINER_ID >/dev/null 2>&1
docker rm $CONTAINER_ID >/dev/null 2>&1

echo ""
echo "=========================================="
echo "测试结果总结"
echo "=========================================="
echo "通过: $TESTS_PASSED"
echo "失败: $TESTS_FAILED"
echo "总计: $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo "状态: ✅ 所有测试通过"
    exit 0
else
    echo "状态: ❌ 部分测试失败"
    exit 1
fi
