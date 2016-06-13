param(

    [String]
    $serverName = 'SQLEXPRESS',

    [String]
    $instance = "$env:computername\$serverName",

    [parameter(mandatory=$true)]
    [String]
    $databaseName,

    [parameter(mandatory=$true)]
    [String]
    $loginName,

    [parameter(mandatory=$true)]
    [String]
    $CMD
)

function Create-SqlLogin()
{
    param(
        [parameter(mandatory=$true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $server,

        [parameter(mandatory=$true)]
        [String]
        $loginName,

        [String]
        $password = ''
    )
    $login = New-Object ('Microsoft.SqlServer.Management.Smo.Login') `
        -ArgumentList $server, $loginName
    $login.LoginType = 'SqlLogin'
    $login.PasswordExpirationEnabled = $false
    $login.PasswordPolicyEnforced = $false
    $login.Create($password)
}

function Add-DatabasePermissions()
{
    param(
    [parameter(Mandatory=$true)]
    [Microsoft.SqlServer.Management.Smo.Database]
    $database,
    [parameter(Mandatory=$true)]
    [String]
    $loginName
    )

    $dbuser = $database.Users[$loginName]

    $permissionSet = New-Object Microsoft.SqlServer.Management.Smo.DatabasePermissionSet(
        [Microsoft.SqlServer.Management.Smo.DatabasePermission]::Alter)
    $permissionSet.Add(
        [Microsoft.SqlServer.Management.Smo.DatabasePermission]::CreateTable)
    $permissionSet.Add(
        [Microsoft.SqlServer.Management.Smo.DatabasePermission]::Insert)
    $permissionSet.Add(
        [Microsoft.SqlServer.Management.Smo.DatabasePermission]::Delete)
    $permissionSet.Add(
        [Microsoft.SqlServer.Management.Smo.DatabasePermission]::Update)
    $permissionSet.Add(
        [Microsoft.SqlServer.Management.Smo.DatabasePermission]::Select)
    $permissionSet.Add(
        [Microsoft.SqlServer.Management.Smo.DatabasePermission]::Connect)
    $permissionSet.Add(
        [Microsoft.SqlServer.Management.Smo.DatabasePermission]::References)
    $permissionSet.Add(
        [Microsoft.SqlServer.Management.Smo.DatabasePermission]::CreateProcedure)
    $permissionSet.Add(
        [Microsoft.SqlServer.Management.Smo.DatabasePermission]::CreateView)
    $permissionSet.Add(
        [Microsoft.SqlServer.Management.Smo.DatabasePermission]::Execute)

    $database.Grant($permissionSet, $dbuser.Name)
}

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo') | Out-Null

$server = New-Object Microsoft.SqlServer.Management.Smo.Server $instance
$database = $server.Databases[$databaseName]

if ($database -eq $null) {
    Write-Host "Creating database $databaseName"
    $database = New-Object Microsoft.SqlServer.Management.Smo.Database `
        -ArgumentList $server, $databaseName
    $database.Create();
}
else {
    Write-Host "Dropping $databaseName."
    $database.Drop()

    Write-Host "Creating database $databaseName."
    $database = New-Object Microsoft.SqlServer.Management.Smo.Database `
        -ArgumentList $server, $databaseName
    $database.Create();
}

$login = $server.Logins[$loginName]

if ($login -eq $null) {
    Write-Host "Creating login $loginName"
    Create-SqlLogin -server $server -loginName $loginName
}
else {
    Write-Host "Dropping login $loginName."
    $login.Drop()
    Write-Host "Creating login $loginName."
    Create-SqlLogin -server $server -loginName $loginName
}

$dbuser = $database.Users[$loginName]
if ($dbuser -eq $null) {
    Write-Host "Adding $loginName as user to database $databaseName."
    $dbuser = new-object ('Microsoft.SqlServer.Management.Smo.User') `
        -ArgumentList $database, $loginName
    $dbuser.Login = $loginName
    $dbuser.Create()
}
else {
    Write-Host "Dropping user $loginName from $databaseName."
    $dbuser.Drop()
    Write-Host "Adding $loginName as user to database $databaseName."
    $dbuser = new-object ('Microsoft.SqlServer.Management.Smo.User') `
        -ArgumentList $database, $loginName
    $dbuser.Login = $loginName
    $dbuser.Create()
}

Write-Host "Adding permissions to $loginName."
Add-DatabasePermissions -database $database -loginName $loginName

$flywayMetadataTableName = 'schema_version'

if ($database.Tables[$flywayMetadataTableName] -eq $null) {
    Write-Host "Flyway metadata table $flywayMetadataTableName does not exist."
    Write-Host 'Baselining database.'
    & $CMD 'migrate'

    Write-Host 'Attempting to migrate forward.'
    & $CMD 'migrate'
    & $CMD 'info'
}
else {
    Write-Host 'Flyway has been used against this database already.'
    Write-Host 'Attempting to migrate forward.'
    & $CMD 'migrate'
    & $CMD 'info'
}
