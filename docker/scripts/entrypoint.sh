#!/bin/bash
# =============================================================================
# PolarDB Docker Entrypoint Script
# =============================================================================
# 初始化 PolarDB 数据库并启动服务
# =============================================================================

set -e

# 数据目录
export PGDATA=${PGDATA:-/var/lib/postgresql/data}

# 处理信号
trap 'echo "Received signal"; exit 0' SIGTERM SIGINT

# 如果数据目录为空，初始化数据库
if [ -z "$(ls -A "$PGDATA")" ]; then
    echo "初始化 PolarDB 数据库..."

    # 创建数据目录
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$PGDATA"

    # 以 postgres 用户初始化数据库
    su-exec postgres initdb \
        -D "$PGDATA" \
        -U ${POSTGRES_USER:-polardb} \
        -E UTF8 \
        --locale=C

    # 配置 PostgreSQL
    {
        echo "host all all 0.0.0.0/0 md5"
        echo "local all all trust"
    } >> "$PGDATA/pg_hba.conf"

    echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"
    echo "max_connections = 200" >> "$PGDATA/postgresql.conf"
    echo "shared_buffers = 256MB" >> "$PGDATA/postgresql.conf"

    echo "数据库初始化完成"
fi

# 启动数据库并执行初始化脚本
if [ -d /docker-entrypoint-initdb.d ]; then
    echo "执行初始化脚本..."

    # 临时启动数据库
    su-exec postgres pg_ctl -D "$PGDATA" \
        -o "-c listen_addresses='localhost'" \
        -w start

    # 等待数据库启动
    until su-exec postgres pg_isready -U ${POSTGRES_USER:-polardb}; do
        echo "等待数据库启动..."
        sleep 1
    done

    # 执行所有初始化脚本
    for f in /docker-entrypoint-initdb.d/*.sh; do
        if [ -f "$f" ]; then
            echo "执行: $f"
            su-exec postgres bash "$f"
        fi
    done

    for f in /docker-entrypoint-initdb.d/*.sql; do
        if [ -f "$f" ]; then
            echo "执行: $f"
            su-exec postgres psql -U ${POSTGRES_USER:-polardb} -f "$f"
        fi
    done

    # 停止数据库
    su-exec postgres pg_ctl -D "$PGDATA" -m fast -w stop

    echo "初始化脚本执行完成"
fi

# 启动 PostgreSQL
echo "启动 PolarDB..."
exec su-exec postgres postgres "$@"
