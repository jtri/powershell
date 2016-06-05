param(
    [String]
    $ServerName = 'SQLEXPRESS',

    [parameter(Mandatory=$true)]
    [String]
    $DatabaseName,

    [String]
    $LoginName = 'Test Login'
)

function main
{
    Load-Assembly('Microsoft.SqlServer.Smo')
    Load-Assembly('Microsoft.SqlServer.SqlWmiManagement')

    $MachineObject = 
    New-Object ('Microsoft.SqlServer.Management.Smo.WMI.ManagedComputer') .

    $ProtocolUri = 
    "ManagedComputer[@Name='$env:computername']/ServerInstance[@Name='$Server']/ServerProtocol"

    $tcp = $MachineObject.GetSmoObject($ProtocolUri + "[@Name='Tcp']")
    $np = $MachineObject.GetSmoObject($ProtocolUri + "[@Name='Np']")

    <# The array indices are hardcoded, but can be set in a way similar to
       $tcp and $np: by appending the right @Name=... values #>
	$tcp.IsEnabled = $true
	$tcp.IPAddresses[8].IPAddressProperties[0].Value = ''
	$tcp.IpAddresses[8].IPAddressProperties[1].Value = '1433'
	$tcp.alter()

	$np.IsEnabled = $true
	$np.ProtocolProperties[0].Value = $true
	$np.alter()

    $instance = "$env:computername\$ServerName"
    try {
        $Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
    } catch [Exception] {
        Write-Host "$_.Exception.GetType().FullName, $_.Exception.Message" -ForegroundColor Red
    }

	Set-MixedLoginMode -server $server
    Restart-SQLInstance($Server)
    Create-SqlLogin -server $Server -loginName $LoginName
    $Database = Create-Database -server $Server -dbName $DatabaseName
    Create-DatabaseUser -server $Server -databse $Database -userName $LoginName
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
    if($loginNames[$loginName] -eq $null) {
        $login = New-Object ('Microsoft.SqlServer.Management.Smo.Login') `
            -ArgumentList $server, $loginName
        $login.LoginType = 'SqlLogin'
        $login.PasswordExpirationEnabled = $false
        $login.PasswordPolicyEnforced = $false
        $login.Create($password)
    } else {
        throw "$loginName already exists!"
    }
}

function Delete-SqlLogin()
{
    param(
        [parameter(mandatory=$true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $server,
        [parameter(mandatory=$true)]
        [String]
        $loginName
    )
    if($server.Logins[$loginName] -eq $null) {
        throw "Sql Login does not exist"
    }
    $server.Logins[$loginName].Drop()
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
    if($server.Logins[$userName] -eq $null) {
        Write-Host "$userName was not found."
        Exit 1
    }
    if($database -eq $null) {
        Write-Host "$db was not found."
        Exit 1
    }
    if($database.Users[$userName] -ne $null) {
        Write-Host "$userName already a user of $db."
        Exit 1
    }

    $user = new-object ('Microsoft.SqlServer.Management.Smo.User') `
        -ArgumentList $database, $userName
    $user.Login = $userName
    $user.Create()
}

function Create-Database()
{
    param(
        [parameter(mandatory=$true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $server,

        [parameter(mandatory=$true)]
        [String]
        $dbName
    )

    $db = new-object ('Microsoft.SqlServer.Management.Smo.Database') `
        -ArgumentList $server, $dbName
    $db.Create()
    # return database
    $db
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