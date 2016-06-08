param(
  [$String]
  $DatabaseName,
  [$String]
  $LoginName
)

$instance = "$env:computername\SQLEXPRESS"

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')

$server = new-object Microsoft.SqlServer.Management.Smo.Server $instance

$database = $server.Databases[$DatabaseName]

$dbuser = $database.Users[$LoginName]

$permissionSet = new-object Microsoft.SqlServer.Management.Smo.DatabasePermissionSet(
[Microsoft.SqlServer.Management.Smo.DatabasePermission]::Alter)
$permissionSet.add([Microsoft.SqlServer.Management.Smo.DatabasePermission]::CreateTable)
$permissionSet.add([Microsoft.SqlServer.Management.Smo.DatabasePermission]::Insert)
$permissionSet.add([Microsoft.SqlServer.Management.Smo.DatabasePermission]::Delete)
$permissionSet.add([Microsoft.SqlServer.Management.Smo.DatabasePermission]::Update)
$permissionSet.add([Microsoft.SqlServer.Management.Smo.DatabasePermission]::Select)
$permissionSet.add([Microsoft.SqlServer.Management.Smo.DatabasePermission]::Connect)
$permissionSet.add([Microsoft.SqlServer.Management.Smo.DatabasePermission]::References)

$database.Grant($permissionSet, $dbuser.Name)
