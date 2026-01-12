-- =============================================================================
-- PolarDB Docker 初始化 SQL
-- =============================================================================
-- 自动启用常用扩展
-- =============================================================================

-- 启用 pg_stat_statements（查询性能监控）
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 启用 adminpack（管理工具）
CREATE EXTENSION IF NOT EXISTS adminpack;

-- 显示已安装的扩展
\dx

-- 创建监控视图
CREATE OR REPLACE VIEW pg_extension_info AS
SELECT
    e.name AS extension_name,
    e.default_version,
    e.installed_version,
    n.nspname AS schema_name,
    e.extversion AS extension_version
FROM pg_extension e
JOIN pg_namespace n ON e.extnamespace = n.oid
ORDER BY e.name;

-- 授予公共角色查询权限
GRANT SELECT ON pg_extension_info TO PUBLIC;

COMMENT ON VIEW pg_extension_info IS '扩展信息视图';

-- 显示完成信息
SELECT 'PolarDB 初始化完成！' AS status;
SELECT '已安装的扩展:' AS info;
SELECT * FROM pg_extension_info;
