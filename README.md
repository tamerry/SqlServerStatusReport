# SqlServerStatusReport

Bir SQL Server'inizin ne zaman yeniden başladığını biliyor musunuz? Pek çok SQL Server örneğini yönetirken, birinin ne zaman yeniden başladığını bilemeyebilirsiniz, bu nedenle size e-postayla gönderilen otomatik bir raporun olması, o örnek için neler olduğu hakkında bir fikir edinmenize yardımcı olabilir.
çalıştırmak için: 
The call for running the stored procedure in test mode is:

Exec [DBA].[dbo].[usp_sql_server_status_check_HTML] @Test=’Yes’		

The call for running the stored procedure when test mode off is:

Exec [DBA].[dbo].[usp_sql_server_status_check_HTML] @Test=’No’	
