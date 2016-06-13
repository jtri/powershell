param(
    [String]
    $ServerName = 'SQLEXPRESS',

    [parameter(Mandatory=$true)]
    [String]
    $DatabaseName,

    [parameter(Mandatory=$true)]
    [String]
    $UserName
)

function main
{
    Load-Assembly('Microsoft.SqlServer.Smo')
    Load-Assembly('Microsoft.SqlServer.SqlWmiManagement')

    $instance = "$env:computername\$ServerName"

    try {
        $Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
    } catch [Exception] {
        Write-Host "$_.Exception.GetType().FullName, $_.Exception.Message" -ForegroundColor Red
    }

    $Database = $Server.Databases[$DatabaseName]
    if($Database -eq $null) {
        Write-Host 'Database does not exist'
        Write-Host "Creating $DatabaseName"
        $Database = Create-Database -server $Server -databaseName $DatabaseName
    }

    $DatabaseUser = $Database.Users[$UserName]
    if($DatabaseUser -eq $null) {
        Write-Host "$UserName is not a user of $DatabaseName"
        Write-Host "Creating Sql Login $UserName"
        Create-SqlLogin -server $Server -loginName $UserName
        Write-Host "Creating database user $UserName"
        Create-DatabaseUser -server $Server -database $Database -userName $UserName
    }

    Write-Host 'Adding permissions'
    $Server.Refresh()
    $Database = $Server.Databases[$DatabaseName]
    Add-DatabasePermissions -database $Database -loginName $UserName
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
    $loginNames = $server.Logins
    if(-not ($server.Logins.Contains($loginName))) {
        $login = New-Object ('Microsoft.SqlServer.Management.Smo.Login') `
            -ArgumentList $server, $loginName
        $login.LoginType = 'SqlLogin'
        $login.PasswordExpirationEnabled = $false
        $login.PasswordPolicyEnforced = $false
        $login.Create($password)
    } else {
        Write-Host "$loginName already exists"
    }
}

function Create-Database()
{
    param(
        [parameter(mandatory=$true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $server,

        [parameter(mandatory=$true)]
        [String]
        $databaseName
    )

    $db = new-object ('Microsoft.SqlServer.Management.Smo.Database') `
        -ArgumentList $server, $databaseName
    $db.Create()
    $db
}

function Create-DatabaseUser()
{
    param(
        [parameter(mandatory=$true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $server,

        [parameter(mandatory=$true)]
        [Microsoft.SqlServer.Management.Smo.Database]
        $database,

        [parameter(mandatory=$true)]
        [String]
        $userName
    )
    $user = $database.Users[$userName]
    if($user -eq $null) {
        $user = new-object ('Microsoft.SqlServer.Management.Smo.User') `
            -ArgumentList $database, $userName
        $user.Login = $userName
        $user.Create()
    } else {
        Write-Host "$userName is already a user of $database.Name"
    }
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

main