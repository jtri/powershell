. .\SqlHelperFunctions
. .\changeuse
. .\placeholder_replacement

function main
{
	param (
		[String]
		$instance = "$env:computername\SQLEXPRESS",
		
		[parameter(mandatory=$true)]
		[String]
		$databaseName,
		
		[parameter(mandatory=$true)]
		[String]
		$loginName,
		
		[parameter(mandatory=$true)]
		[String]
		$CMD,

		[parameter(mandatory=$true)]
		[String]
		$directory,
		
		[String]
		$password = ''
	)
	Load-Assembly('Microsoft.SqlServer.Smo')

	try {
		$server = New-Object Microsoft.SqlServer.Management.Smo.Server $instance
	}
	catch [Exception] {
		Write-Host 'Error getting SQL Server instance'
		Exit 1
	}

	Create-SqlLogin -server $server -loginName $loginName -password $password

	Create-Database -server $server -dbName $databaseName

	$server.Refresh()
	$database = $server.Databases[$databaseName]

	Create-DatabaseUser -database $database -userName $loginName

	Write-Host 'Adding databse permissions'
	Add-DatabasePermissions -database $database -loginName $loginName

	Change-UseStatement -Directory $directory -replaceWith $databaseName

	Replace-Placeholder -directory 'C:\Developer\Projects\migrations' -database $databaseName -password "" -username $loginName

	$liquibaseMetadataTableName = 'DATABASECHANGELOG'

	Write-Host 'Applying pending migrations'
	& $CMD 'update'
}
main
