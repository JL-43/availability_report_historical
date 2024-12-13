use mock_linked_server;
go

if object_id('dbo.mock_source_table', 'U') is not null
begin
    drop table dbo.mock_source_table;
end
go

-- Create the table with appropriate indexing and compression
create table dbo.mock_source_table
(
    event_id int identity(1,1) not null,
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
    constraint PK_mock_source_table primary key clustered (event_id)
) with (data_compression = page);
go

-- Create a numbers table for faster generation
if object_id('tempdb..#Numbers') is not null drop table #Numbers;
create table #Numbers (Number int primary key);

-- Generate numbers 1 to 5000 more efficiently
with 
    E1(N) AS (select 1 from (values (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) t(N)), -- 10 rows
    E2(N) AS (select 1 from E1 a cross join E1 b), -- 100 rows
    E4(N) AS (select 1 from E2 a cross join E2 b), -- 10,000 rows
    Numbers AS (select row_number() over (order by (select null)) as Number 
                from E4)
insert into #Numbers (Number)
select Number 
from Numbers 
where Number <= 5000;

-- Set up variables for batch insertion
declare @BatchSize int = 50000;
declare @current_date datetime = '2020-01-01';
declare @end_date datetime = dateadd(day, -1, cast(getdate() as date));

-- Turn off logging for bulk insert
set nocount on;

-- Configure transaction
set xact_abort on;

-- Batch insert with minimal logging
while @current_date <= @end_date
begin
    insert into dbo.mock_source_table with (tablock)
    (
        starttime, endtime, event_name, event_desc,
        col_str1, col_str2, col_str3, col_str4, col_str5,
        col_dec1, col_dec2, col_dec3, col_dec4, col_dec5,
        col_str6, col_str7, col_str8, col_str9, col_str10,
        col_dec6, col_dec7, col_dec8, col_dec9, col_dec10
    )
    select 
        dateadd(second, Number, @current_date),
        dateadd(second, Number+300, @current_date),
        concat('Event ', Number),
        concat('Description for event ', Number),
        'val1', 'val2', 'val3', 'val4', 'val5',
        abs(checksum(newid())) % 1000 + rand(),
        abs(checksum(newid())) % 1000 + rand(),
        abs(checksum(newid())) % 1000 + rand(),
        abs(checksum(newid())) % 1000 + rand(),
        abs(checksum(newid())) % 1000 + rand(),
        'val6', 'val7', 'val8', 'val9', 'val10',
        abs(checksum(newid())) % 1000 + rand(),
        abs(checksum(newid())) % 1000 + rand(),
        abs(checksum(newid())) % 1000 + rand(),
        abs(checksum(newid())) % 1000 + rand(),
        abs(checksum(newid())) % 1000 + rand()
    from #Numbers
    where Number <= 5000;

    set @current_date = dateadd(day, 1, @current_date);

    -- Commit every batch to prevent transaction log growth
    if datepart(day, @current_date) % 30 = 0
    begin
        checkpoint;
    end
end

create nonclustered index IX_mock_source_table_starttime 
on dbo.mock_source_table(starttime);
go