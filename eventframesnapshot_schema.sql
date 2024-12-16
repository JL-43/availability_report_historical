if object_id('dbo.eventframesnapshot_h', 'U') is not null
begin
	drop table dbo.eventframesnapshot_h;
end
go

create table dbo.eventframesnapshot_h
(
  [efs_eventframeattributeid] varchar(100),
  [efs_time] varchar(100),
  [efs_value] varchar(100),
  [efs_valueint] varchar(100),
  [efs_valuedbl] varchar(100),
  [efs_valuestr] varchar(100),
  [efs_valueguid] varchar(100),
  [efs_valuedatetime] varchar(100),
  [efs_status] varchar(100),
  [efs_annotated] varchar(100),
  [efs_isgood] varchar(100),
  [efs_questionable] varchar(100),
  [efs_substituted] varchar(100),
  [efs_eventframetemplateattributeid] varchar(100),
  [ef_id] varchar(100),
  [ef_name] varchar(100),
  [ef_description] varchar(100),
  [starttime] varchar(100),
  [endtime] varchar(100),
  [ef_eventframetemplateid] varchar(100),
  [ef_primaryparentid] varchar(100),
  [ef_primaryparentreferencetypeid] varchar(100),
  [ef_primaryreferencedelementid] varchar(100),
  [ef_revision] varchar(100),
  [ef_severity] varchar(100),
  [ef_isroot] varchar(100),
  [ef_arevaluescaptured] varchar(100),
  [ef_isannotated] varchar(100),
  [ef_islocked] varchar(100),
  [ef_canbeacknowledged] varchar(100),
  [ef_haschildren] varchar(100),
  [ef_hasreferencedelements] varchar(100),
  [ef_securitydescriptor] varchar(2000),
  [ef_modified] varchar(100),
  [ef_checkouttime] varchar(100),
  [ef_checkoutusername] varchar(100),
  [ef_checkoutmachinename] varchar(100),
  [ef_acknowledged] varchar(100),
  [ef_acknowledgedby] varchar(100),
  [efa_id] varchar(100),
  [efa_path] varchar(100),
  [efa_name] varchar(100),
  [efa_level] varchar(100),
  [efa_description] varchar(100),
  [efa_isconfigurationitem] varchar(100),
  [efa_ismanualdataentry] varchar(100),
  [efa_ishidden] varchar(100),
  [efa_traittype] varchar(100),
  [efa_valuetype] varchar(100),
  [efa_enumerationsetid] varchar(100),
  [efa_enumerationsetname] varchar(100),
  [efa_datareferencepluginid] varchar(100),
  [efa_configstring] varchar(100),
  [efa_defaultuomid] varchar(100),
  [efa_eventframetemplateattributeid] varchar(100),
  [efa_eventframeid] varchar(100)
);
go

-- index on starttime for efficient querying
-- create nonclustered index IX_target_table_starttime 
-- on dbo.eventframesnapshot_h(starttime);
-- go

-- audit table
if object_id('dbo.data_migration_audit', 'U') is not null
begin
    drop table dbo.data_migration_audit;
end
go

create table dbo.data_migration_audit
(
    audit_id int identity(1,1) primary key,
    batch_id uniqueidentifier not null,
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
    sql_command varchar(max) not null,       -- sql that was executed
    start_time datetime not null default getdate(),
    end_time datetime null,
    created_by varchar(255) not null default system_user,
    created_at datetime not null default getdate()
);
go

-- create index on batch_id for efficient querying of related operations
create nonclustered index IX_data_migration_audit_batch_id 
on dbo.data_migration_audit(batch_id);
go

-- create index on execution_status for monitoring failed operations
create nonclustered index IX_data_migration_audit_status 
on dbo.data_migration_audit(execution_status);
go

-- migration status view
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