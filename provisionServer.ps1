[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

# Install MS SQL Server 2014 with chocolatey and Configuration file -- unattended
Invoke-Expression 'choco install mssqlserver2014express -y -packageParameters="/CONFIGURATIONFILE=C:\powershell\Configuration.ini"'

# Create Login

# Create Database

# Add user to above database

# Run SQL scripts