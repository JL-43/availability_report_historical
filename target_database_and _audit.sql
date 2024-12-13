-- Create the target database
if db_id('target_database') is null
begin
    create database target_database;
end
go

use target_database;
go

-- Create target table mirroring source structure
if object_id('dbo.target_table', 'U') is not null
begin
    drop table dbo.target_table;
end
go

create table dbo.target_table
(
    event_id int not null,
    starttime datetime not null,
    endtime datetime not null,
    event_name varchar(255) not null,
    event_desc varchar(1000) null,
    col_str1 varchar(100) null,
    col_str2 varchar(100) null,
    col_str3 varchar(100) null,
    col_str4 varchar(100) null,
    col_str5 varchar(100) null,
    col_dec1 decimal(18,2) null,
    col_dec2 decimal(18,2) null,
    col_dec3 decimal(18,2) null,
    col_dec4 decimal(18,2) null,
    col_dec5 decimal(18,2) null,
    col_str6 varchar(100) null,
    col_str7 varchar(100) null,
    col_str8 varchar(100) null,
    col_str9 varchar(100) null,
    col_str10 varchar(100) null,
    col_dec6 decimal(18,2) null,
    col_dec7 decimal(18,2) null,
    col_dec8 decimal(18,2) null,
    col_dec9 decimal(18,2) null,
    col_dec10 decimal(18,2) null,
    constraint PK_target_table primary key clustered (event_id)
);
go

-- Create index on starttime for efficient querying
create nonclustered index IX_target_table_starttime 
on dbo.target_table(starttime);
go

-- Create audit table for tracking operations
if object_id('dbo.data_migration_audit', 'U') is not null
begin
    drop table dbo.data_migration_audit;
end
go

create table dbo.data_migration_audit
(
    audit_id int identity(1,1) primary key,
    batch_id uniqueidentifier not null,      -- To group related operations
    source_database varchar(255) not null,
    source_table varchar(255) not null,
    target_database varchar(255) not null,
    target_table varchar(255) not null,
    date_column varchar(255) not null,
    start_date datetime not null,
    end_date datetime not null,
    rows_processed int null,
    execution_status varchar(50) not null,   -- 'Started', 'Completed', 'Failed'
    info_message varchar(max) null,
    sql_command varchar(max) not null,       -- The actual SQL that was executed
    start_time datetime not null default getdate(),
    end_time datetime null,
    created_by varchar(255) not null default system_user,
    created_at datetime not null default getdate()
);
go

-- Create index on batch_id for efficient querying of related operations
create nonclustered index IX_data_migration_audit_batch_id 
on dbo.data_migration_audit(batch_id);
go

-- Create index on execution_status for monitoring failed operations
create nonclustered index IX_data_migration_audit_status 
on dbo.data_migration_audit(execution_status);
go

-- Create a view for easy monitoring of latest migration status
create or alter view dbo.vw_migration_status
as
select 
    batch_id,
    source_database,
    source_table,
    min(start_date) as batch_start_date,
    max(end_date) as batch_end_date,
    sum(rows_processed) as total_rows_processed,
    min(start_time) as batch_start_time,
    max(end_time) as batch_end_time,
    case 
        when count(case when execution_status = 'Failed' then 1 end) > 0 then 'Failed'
        when count(case when execution_status = 'Started' then 1 end) > 0 then 'In Progress'
        else 'Completed'
    end as batch_status,
    string_agg(case when execution_status = 'Failed' then info_message else null end, '; ') as info_messages
from dbo.data_migration_audit
group by batch_id, source_database, source_table;
go