use target_database;
go

create or alter procedure dbo.migrate_historical_data
    @source_database varchar(255),
    @source_table varchar(255),
    @date_column varchar(255),
    @target_database varchar(255),
    @target_table varchar(255),
    @days_per_batch int = 3,
    @start_date datetime = null,
    @end_date datetime = '2016-01-01',
    @force_reprocess bit = 0
as
begin
    set nocount on;
    set xact_abort on;

    declare @batch_id uniqueidentifier = newid();
    declare @current_date datetime;
    declare @sql nvarchar(max);
    declare @params nvarchar(max);
    declare @info_message nvarchar(4000);
    declare @rows_affected int;
    declare @msg nvarchar(2048);

    -- Parameter validation
    if @days_per_batch <= 0
    begin
        raiserror('ERROR: Days per batch must be greater than 0', 16, 1);
        return;
    end

    -- Get latest date if not specified
    if @start_date is null
    begin
        set @sql = N'
            select @start_date = max(' + quotename(@date_column) + ')
            from ' + quotename(@source_database) + '.' + quotename('dbo') + '.' + quotename(@source_table);
        
        set @params = N'@start_date datetime output';
        
        begin try
            exec sp_executesql @sql, @params, @start_date output;
        end try
        begin catch
            set @info_message = info_message();
            raiserror('ERROR: Failed to get start date: %s', 16, 1, @info_message);
            return;
        end catch
    end

    set @current_date = @start_date;

    while @current_date >= @end_date
    begin
        declare @batch_start datetime = dateadd(day, -(@days_per_batch - 1), @current_date);
        declare @batch_end datetime = @current_date;

        -- Build SQL command first
        set @sql = N'
            insert into ' + quotename(@target_database) + '.dbo.' + quotename(@target_table) + '
            select *
            from ' + quotename(@source_database) + '.dbo.' + quotename(@source_table) + '
            where cast(' + quotename(@date_column) + ' as date) >= @batch_start
            and cast(' + quotename(@date_column) + ' as date) <= @batch_end';

        -- Create batch info
        declare @batch_info nvarchar(1000) = 
            'INFO: Batch covering ' + convert(varchar, @batch_start, 120) + 
            ' through ' + convert(varchar, @batch_end, 120) +
            case when @force_reprocess = 1 
                then ' (Reprocessing forced)'
                else '' end;

        -- Initial audit insert with batch info
        insert into dbo.data_migration_audit (
            batch_id, source_database, source_table, target_database, target_table,
            date_column, start_date, end_date, execution_status, sql_command,
            info_message
        )
        values (
            @batch_id, @source_database, @source_table, @target_database, @target_table,
            @date_column, @batch_start, @batch_end, 
            case when @force_reprocess = 1 then 'Started (Reprocess)' else 'Started' end,
            @sql,
            @batch_info
        );

        -- Handle reprocessing
        if @force_reprocess = 1
        begin
            -- Mark existing records for reprocess
            update dbo.data_migration_audit
            set execution_status = 'Reprocess'
            where start_date = @batch_start 
            and end_date = @batch_end
            and execution_status = 'Completed';

            -- Clean existing data from target
            set @sql = N'
                delete from ' + quotename(@target_database) + '.dbo.' + quotename(@target_table) + '
                where cast(' + quotename(@date_column) + ' as date) >= @batch_start
                and cast(' + quotename(@date_column) + ' as date) <= @batch_end';

            begin try
                exec sp_executesql @sql, N'@batch_start datetime, @batch_end datetime', 
                    @batch_start, @batch_end;
            end try
            begin catch
                set @info_message = info_message();
                raiserror('ERROR: Failed to clean existing data: %s', 10, 1, @info_message);
                -- Continue processing
            end catch
        end

        -- Process if new or reprocessing
        if @force_reprocess = 1 
        or not exists (
            select 1 
            from dbo.data_migration_audit 
            where start_date = @batch_start 
            and end_date = @batch_end
            and execution_status = 'Completed'
        )
        begin
            set @sql = N'
                insert into ' + quotename(@target_database) + '.dbo.' + quotename(@target_table) + '
                select *
                from ' + quotename(@source_database) + '.dbo.' + quotename(@source_table) + '
                where cast(' + quotename(@date_column) + ' as date) >= @batch_start
                and cast(' + quotename(@date_column) + ' as date) <= @batch_end';

            begin try
                begin transaction;

                exec sp_executesql @sql, N'@batch_start datetime, @batch_end datetime',
                    @batch_start, @batch_end;
                
                set @rows_affected = @@rowcount;

                update dbo.data_migration_audit
                set execution_status = 'Completed',
                    rows_processed = @rows_affected,
                    end_time = getdate()
                where batch_id = @batch_id
                and start_date = @batch_start
                and end_date = @batch_end;

                commit transaction;
            end try
            begin catch
                if @@trancount > 0
                    rollback transaction;

                set @info_message = info_message();
                
                update dbo.data_migration_audit
                set execution_status = 'Failed',
                    info_message = @info_message,
                    end_time = getdate()
                where batch_id = @batch_id
                and start_date = @batch_start
                and end_date = @batch_end;

                set @msg = formatmessage('ERROR: Failed to process batch %s to %s: %s', 
                    cast(@batch_start as varchar(23)),
                    cast(@batch_end as varchar(23)),
                    @info_message);

                raiserror(@msg, 10, 1) with nowait;
            end catch
        end

        set @current_date = dateadd(day, -@days_per_batch, @current_date);
    end
end;
go