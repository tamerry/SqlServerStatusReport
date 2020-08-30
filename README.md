# SqlServerStatusReport

Do you know when a SQL Server instance restarts? When you manage many SQL Server instances you may not know when one restarts, so having an automated report emailed to you could be helpful to get an idea what's going on for that instance.

The call for running the stored procedure in test mode is:

Exec [DBA].[dbo].[usp_sql_server_status_check_HTML] @Test=’Yes’			
The call for running the stored procedure when test mode off is:

Exec [DBA].[dbo].[usp_sql_server_status_check_HTML] @Test=’No’	