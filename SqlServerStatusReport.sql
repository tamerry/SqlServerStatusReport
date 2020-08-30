USE DBA; --  Name your administrative database here
GO

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRY
    DROP PROCEDURE [dbo].[usp_sql_server_status_check_HTML];
END TRY
BEGIN CATCH
END CATCH;
GO

CREATE PROCEDURE [dbo].[usp_sql_server_status_check_HTML] @Test NVARCHAR(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- File name : usp_sql_server_status_check_HTML.sql
    -- Author    : Tamer Yavuz

    DECLARE @Reference NVARCHAR(128) = N'https://veri-analizi.blogspot.com/';
    DECLARE @Report_Name NVARCHAR(128) = N'SQL Server durum raporu';

    -- Just in case @@Servername is null
    DECLARE @Instance NVARCHAR(128)
        =
            (
                SELECT ISNULL(@@Servername, CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128)) + '\' + @@servicename)
            );

    -- Get this many days from the SQL Agent log
    DECLARE @Log_Days_Agent INT = 4;

    -- Build a table for the report
    DECLARE @SQL_Status_Report TABLE
    (
        Line_Number INT NOT NULL IDENTITY(1, 1),
        Information NVARCHAR(MAX)
    );

    -- Main title of the report
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT @Instance + ' at ' + CONVERT(NVARCHAR(17), GETDATE(), 113) + ' Raporun alýndýðý sunucu ve tarih';
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT 'Makina adý : ' + CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(1024));
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT 'Sql Versiyonu : ' + @@version;
    INSERT INTO @SQL_Status_Report
    SELECT 'Sql Serverin Baþlangýç zamaný: ' + CONVERT(NVARCHAR(17), sqlserver_start_time, 113)
    FROM sys.dm_os_sys_info;

    -- Disk Drive Space
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT 'Disk durumu ' + @Instance + ' (En az alanlý birim en üstte)';
    DECLARE @drives TABLE
    (
        drive NVARCHAR(1),
        MbFree INT
    );
    INSERT INTO @drives
    EXEC xp_fixeddrives;
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT drive + ' sürücüsünde  ' + CAST(MbFree / 1000 AS NVARCHAR(20)) + ' GB boþ alan var'
    FROM @drives
    ORDER BY MbFree ASC; -- Show least amount of space first			

    -- Users added in the last X days
    DECLARE @DaysBack INT = 7;
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT 'Son ' + CAST(@DaysBack AS NVARCHAR(12)) + ' günde eklenen yeni kullanýcýlar';
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT name + ' ' + type_desc + ' ' + CONVERT(NVARCHAR(17), create_date, 113) + ' '
           + CAST(DATEDIFF(DAY, create_date, GETDATE()) AS NVARCHAR(12)) + ' gün önce'
    FROM sys.server_principals
    WHERE type_desc IN ( 'WINDOWS_LOGIN', 'WINDOWS_GROUP', 'SQL_LOGIN' )
          AND DATEDIFF(DAY, create_date, GETDATE()) < @DaysBack;

    -- Gather summary of databases using sp_helpdb
    DECLARE @sp_helpdb_results TABLE
    (
        [db_name] NVARCHAR(256),
        [db_size] NVARCHAR(25),
        [owner] NVARCHAR(128),
        [db_id] INT,
        [created_data] DATETIME,
        [status] NVARCHAR(MAX),
        [compatability] INT
    );
    INSERT INTO @sp_helpdb_results
    EXEC sp_helpdb;
    -- Flag databases with an unknown status
    INSERT INTO @sp_helpdb_results
    (
        [db_name],
        [owner],
        [db_size]
    )
    SELECT name,
           'Database durumu bilinmiyor' COLLATE DATABASE_DEFAULT,
           0
    FROM sys.sysdatabases
    WHERE [name] COLLATE DATABASE_DEFAULT NOT IN
          (
              SELECT [db_name] COLLATE DATABASE_DEFAULT FROM @sp_helpdb_results
          );
    -- Remove " MB"
    UPDATE @sp_helpdb_results
    SET [db_size] = REPLACE([db_size], ' MB', '');
    DELETE FROM @sp_helpdb_results
    WHERE [db_size] = '0';
    -- Report summary of databases using sp_helpdb
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT @Instance + ' Sunucusunda ' + CAST(COUNT(*) AS NVARCHAR(8)) + ' adet '
           + CAST(CAST(SUM(CAST(REPLACE([db_size], ' MB', '') AS FLOAT)) AS INT) / 1000 AS NVARCHAR(20))
           + ' GB veri bulunan database var'
    FROM @sp_helpdb_results;

    -- Database sizes
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT 'En büyük database ' + @Instance + ' sunucusunda bulunan';
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT TOP 1
           [db_name] + ' Adýndaki '
           + CONVERT(NVARCHAR(10), ROUND(CONVERT(NUMERIC, LTRIM(REPLACE([db_size], 'Mb', ''))), 0))
           + ' MB boyutundaki Veritabanýdýr'
    FROM @sp_helpdb_results
    ORDER BY [db_size] DESC;

    -- Oldest backup
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT @Instance + 'Sunucusundaki En son full backup';
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT TOP 1
           LEFT(database_name, 30) + ' ' + COALESCE(CONVERT(VARCHAR(10), MAX(backup_finish_date), 121), 'Henüz alýnmadý')
    FROM msdb..backupset
    WHERE database_name NOT IN ( 'tempdb' )
          AND type = 'D'
    GROUP BY database_name
    ORDER BY MAX(backup_finish_date) ASC;

    -- Agent log information
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT @Instance + ' Sunucusunun Son ' + CAST(@Log_Days_Agent AS NVARCHAR(12)) + ' güne ait agent Loglarý';
    DECLARE @SqlAgenterrorLog TABLE
    (
        logdate DATETIME,
        [ProcessInfo] VARCHAR(29),
        errortext VARCHAR(MAX)
    );
    INSERT INTO @SqlAgenterrorLog
    EXEC sys.xp_readerrorlog 0, 2;
    -- Report
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT DISTINCT
           CAST(logdate AS NVARCHAR(28)) + ' ' + [ProcessInfo] + ' ' + LEFT(errortext, 300)
    FROM @SqlAgenterrorLog
    WHERE logdate > DATEDIFF(DAY, -@Log_Days_Agent, GETDATE())
    ORDER BY 1 DESC;

    -- Server log last 20 rows
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT @Instance + ' Sunucusunun Sql server loglarý top 20 ';
    DECLARE @SqlerrorLog TABLE
    (
        logdate DATETIME,
        [ProcessInfo] VARCHAR(29),
        errortext VARCHAR(MAX)
    );
    INSERT INTO @SqlerrorLog
    EXEC sys.xp_readerrorlog;
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT TOP 20
           CAST(logdate AS NVARCHAR(28)) + ' ' + [ProcessInfo] + ' ' + LEFT(errortext, 300)
    FROM @SqlerrorLog
    ORDER BY 1 DESC;

    -- Report Footer
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT @Report_Name + ' ' + @Instance + '  ' + CONVERT(NVARCHAR(17), GETDATE(), 113) + ' bitti';
    INSERT INTO @SQL_Status_Report
    (
        Information
    )
    SELECT 'daha fazla bilgi için  : ' + @Reference;

END;

-- Prepare email
DECLARE @xml NVARCHAR(MAX);
DECLARE @body NVARCHAR(MAX);

SET @xml = CAST(
           (
               SELECT LTRIM(Information) AS 'td'
               FROM @SQL_Status_Report
               ORDER BY Line_Number
               FOR XML PATH('tr'), ELEMENTS
           ) AS NVARCHAR(MAX));

DECLARE @Subject_Line NVARCHAR(128) = @Instance + N' Makinasýna ait durum raporu';
SET @body = N'<html><body><table border = 1 width="80%"><th><H3>' + @Subject_Line + N'</H3></th>';

SET @body = @body + @xml + N'</table></body></html>';
IF (@Test = 'Yes')
BEGIN
    SET @Subject_Line = @Subject_Line + N' Test Mode';
    EXEC msdb.dbo.sp_send_dbmail @profile_name = 'TAMER',              -- replace with your SQL Database Mail Profile 
                                 @body = @body,
                                 @body_format = 'HTML',
                                 @recipients = 'puzzleistt@gmail.com', -- replace with your email address
                                 @subject = @Subject_Line;
    PRINT @body;
END;
ELSE
BEGIN
    EXEC msdb.dbo.sp_send_dbmail @profile_name = 'TAMER',              -- replace with your SQL Database Mail Profile 
                                 @body = @body,
                                 @body_format = 'HTML',
                                 @recipients = 'puzzleistt@gmail.com', -- replace with the monitoring email address 
                                 @subject = @Subject_Line;
END;