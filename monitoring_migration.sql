-- Monitor migration progress
SELECT * FROM target_database.dbo.vw_migration_status
ORDER BY batch_start_time DESC;

-- Check detailed audit log
SELECT * FROM target_database.dbo.data_migration_audit
ORDER BY start_time DESC;

-- Compare row counts
SELECT COUNT(*) FROM mock_linked_server.dbo.mock_source_table;
SELECT COUNT(*) FROM target_database.dbo.target_table;