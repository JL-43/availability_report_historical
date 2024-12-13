EXEC dbo.migrate_historical_data
    @source_database = 'mock_linked_server',
    @source_table = 'mock_source_table',
    @date_column = 'starttime',
    @target_database = 'target_database',
    @target_table = 'target_table',
    @days_per_batch = 3,
    @start_date = '2023-01-01',
    @end_date = '2022-12-01',
    @force_reprocess = 0;

-- below should fail gracefully

-- Should fail gracefully
EXEC dbo.migrate_historical_data
    @source_database = 'invalid_db',
    @source_table = 'mock_source_table',
    @date_column = 'starttime',
    @target_database = 'target_database',
    @target_table = 'target_table',
    @days_per_batch = 3;