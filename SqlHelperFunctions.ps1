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

    $database.Grant($permissionSet, $dbuser.Name)
}

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
    $login = $server.Logins[$loginName]
    if ($login -ne $null) {
	Write-Host "Dropping $loginName"
	$login.Drop()
    }
    Write-Host "Creating $loginName"
    $login = New-Object ('Microsoft.SqlServer.Management.Smo.Login') `
    	-ArgumentList $server, $loginName
    $login.LoginType = 'SqlLogin'
    $login.PasswordExpirationEnabled = $false
    $login.PasswordPolicyEnforced = $false
    $login.Create($password)
}

function Create-DatabaseUser()
{
    param(
        [parameter(mandatory=$true)]
        [Microsoft.SqlServer.Management.Smo.Database]
        $database,

        [parameter(mandatory=$true)]
        [String]
        $userName
    )

    $dbuser = $database.Users[$userName]
    if ($dbuser -ne $null) {
    	Write-Host "Dropping user $userName"
	$dbuser.Drop()
    }

    $dbName = $database.Name

    Write-Host "Creating user $userName under $dbName"
    $dbuser = new-object ('Microsoft.SqlServer.Management.Smo.User') `
        -ArgumentList $database, $userName
    $dbuser.Login = $userName
    $dbuser.Create()
}

function Create-Database()
{
	<# Drop databse if it exists, then create or re-create it #>
    param(
        [parameter(mandatory=$true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $server,

        [parameter(mandatory=$true)]
        [String]
        $dbName
    )

    $database = $server.Databases[$dbName]
    if ($database -ne $null) {
	    Write-Host "Dropping database $dbName"
	    $database.Drop()
    }

    Write-Host "Creating database $dbName"
    $database = new-object ('Microsoft.SqlServer.Management.Smo.Database') `
        -ArgumentList $server, $dbName
    $database.Create()
}

function Set-MixedLoginMode()
{
    param(
        [parameter(mandatory=$true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $server
    )
	$server.Settings.LoginMode = 
		[Microsoft.SqlServer.Management.Smo.ServerLoginMode]::Mixed
	$server.alter()
}

function Restart-SQLInstance($name)
{
    iex ('net stop "SQL Server ({0})"' -f $name)
    iex ('net start "SQL Server ({0})"' -f $name)
}

function Load-Assembly($name)
{
	if (([System.AppDomain]::CurrentDomain.GetAssemblies() | where {$_ -match $name}) -eq $null) {
		try {
			[System.Reflection.Assembly]::LoadWithPartialName($name) | out-null
		} catch [System.Exception] {
			Write-Host "Failed to load assembly '{0}" -f $name -ForegroundColor Red
			Write-Host "$_.Exception.GetType().FullName, $_.Exception.Message" -ForegroundColor Red
		}
	}
}
