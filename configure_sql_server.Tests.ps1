. C:\Developer\powershell\configure_sql_server.ps1

Load-Assembly('Microsoft.SqlServer.Smo')

$ServerName = 'localhost'
try {
$Server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName
}
catch [Exception] { Write-Host "Could not get Sql Server Instance" }

function SetUpDatabaseAndLogin()
{
    param(
        [parameter(mandatory=$true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $server,
        [parameter(mandatory=$true)]
        [String]
        $databaseName,
        [parameter(mandatory=$true)]
        [String]
        $loginName
    )
    Set-MixedLoginMode -server $server
    Restart-SQLInstance($server.ServiceName)
    Create-SqlLogin -server $server -loginName $loginName
    Create-Database -server $server -dbName $databaseName
    $server.Refresh()
    $database = $server.Databases[$databaseName]
    Create-DatabaseUser -server $server -database $database -userName $loginName
}

function TearDownDatabaseAndLogin()
{
    param(
        [parameter(mandatory=$true)]
        [Microsoft.SqlServer.Management.Smo.Server]
        $server,
        [parameter(mandatory=$true)]
        [String]
        $databaseName,
        [parameter(mandatory=$true)]
        [String]
        $loginName
    )
    $Database = $server.Databases[$databaseName]
    $User = $Database.Users[$loginName]

    $User.Drop()
    $Database.Drop()
    Delete-SqlLogin -server $server -loginName $loginName
}

Describe 'Test Delete-SqlLogin function' {
    $LoginName = "Test Login"
    It 'Should throw "Sql Login Does Not Exist"' {
        { Delete-SqlLogin -server $Server -loginName $LoginName } | Should Throw
    }

    It 'Should successfully delete and notify' {
        Create-SqlLogin -server $Server -loginName $LoginName
        $Server.Refresh()
        { $Server.Logins[$LoginName] } | Should Not BeNullOrEmpty

        Delete-SqlLogin -server $Server -loginName $LoginName
        $Server.Refresh()
        $Server.Logins[$LoginName] | Should BeNullOrEmpty
    }
}

Describe 'Test Create-SqlLogin function' {
    $LoginName = "Test Login3"
    It 'Should add Login to Sql Server' {
        Create-SqlLogin -server $Server -loginName $LoginName
        $Server.Refresh()
        $Server.Logins[$LoginName] | Should Not BeNullOrEmpty
        $Server.Logins[$LoginName] | Should Match $LoginName
        
        # Clean up
        Delete-SqlLogin -server $Server -loginName $LoginName
    }

    It 'Should throw if Login exists' {
        Create-SqlLogin -server $Server -loginName $LoginName
        $Server.Refresh()
        { Create-SqlLogin -server $Server -loginName $LoginName } | Should Throw "$LoginName already exists!"

        # Clean up
        Delete-SqlLogin -server $Server -loginName $LoginName
    }
}

Describe 'Test Create-Database' {

    $DbName = 'TestDB'

    It 'Should create a database with a given name' {
        Create-Database -server $Server -dbName $DbName
        $Server.Refresh()
        $db = $Server.Databases[$DbName]
        $db | Should Not BeNullOrEmpty
        
        # Clean up
        $db.drop()
    }

    It 'Should return database' {
        $db = Create-Database -server $Server -dbName $DbName
        $db | Should Not BeNullOrEmpty
        $db.GetType() | Should Be 'Microsoft.SqlServer.Management.Smo.Database'

        # Clean up
        $db.drop()
    }
}

Describe 'Test Setting Login Mode' {

    It 'Should set Login Mode to mixed' {
        Set-MixedLoginMode -server $Server
        $Server.Settings.LoginMode | Should Be 'Mixed'
    }
}

Describe 'Test Create-DatabaseUser' {

    $LoginName = 'Test Login'
    $DbName = 'TestDB'

    It 'Should create Sql Login and Add User to Db' {
        Create-SqlLogin -server $Server -loginName $LoginName
        $Server.Refresh()
        $Database = Create-Database -server $Server -dbName $DbName
        $Server.Refresh()
        Create-DatabaseUser -server $Server -database $Database -userName $LoginName
        $Server.Refresh()
        
        $Database = $Server.Databases[$DbName]
        $User = $Database.Users[$LoginName]
        $User.Name | Should Be $LoginName

        # Clean up
        $User.Drop()
        $Database.Drop()
        Delete-SqlLogin -server $Server -loginName $LoginName
    }

    It 'Should throw error Login does not exist' -Skip {
    }

    It 'Should throw error that Database does not exist' -Skip {
    }

    It 'Should throw error that User is already member of Database' -Skip {
    }
}

Describe 'Test Add-ServerPermissions' {
    $LoginName = 'TestLogin'
    $DatabaseName = 'TestDB'
    It 'Should assign server roles to login' -Skip {
        # set up
        SetUpDatabaseAndLogin -server $Server -databaseName $DatabaseName -loginName $LoginName
        $Server.Refresh()

        # operations
        Add-ServerPermissions -login $Server.Logins[$LoginName]
        $ModifiedLogin = $Server.Logins[$LoginName]

        # assertions
        #$ModifiedLogin.ListMembers().Contains('dbcreator') | Should Be $true
        #$ModifiedLogin.ListMembers().Contains('setupadmin') | Should Be $true

        # tear down
        $Server.Refresh()
        TearDownDatabaseAndLogin -server $Server -databaseName $DatabaseName -loginName $LoginName
    }

    It 'Should add few permissions to a permission set' -Skip {
        # set up
        SetUpDatabaseAndLogin -server $Server -databaseName $DatabaseName -loginName $LoginName
        $Server.Refresh()

        # operations
        Add-ServerPermissions -login $Server.Logins[$LoginName]
        $Server.Refresh()
        $ModifiedLogin = $Server.Logins[$LoginName]
        $permissionSet = $Server.EnumServerPermissions($LoginName) | ForEach-Object { $_.PermissionType }
        $otherPermissionSet = New-Object Microsoft.SqlServer.Management.Smo.ServerPermissionSet(
            [Microsoft.SqlServer.Management.Smo.ServerPermission]::AlterAnyDatabase
        )
        $otherPermissionSet.Add(
            [Microsoft.SqlServer.Management.Smo.ServerPermission]::AlterSettings
        )

        # assertions
        Microsoft.SqlServer.Management.Smo.ServerPermissionSet.Equality(
        $permissionSet, $otherPermissionSet) `
        | Should Be $true

        # tear down
        $Server.Refresh()
        TearDownDatabaseAndLogin -server $Server -databaseName $DatabaseName -loginName $LoginName        
    }
}

Describe 'Test Add-DatabasePermissions' {

    $DatabaseName = 'TestDB'
    $LoginName = 'TestLogin'

    It 'Should add several privileges to database user' {
        # set up
        SetUpDatabaseAndLogin -server $Server -databaseName $DatabaseName -loginName $LoginName
        $Server.Refresh()

        # operations
        $Database = $Server.Databases[$DatabaseName]
        Add-DatabasePermissions -database $Database -loginName $LoginName
        $ModifiedLogin = $Server.Logins[$LoginName]

        # assertions
        $Database.Users | ForEach-Object {
            $Database.EnumDatabasePermissions($_.Name) |
            Select PermissionState, PermissionType, Grantee
        } | Format-Table -AutoSize

        # tear down
        $Server.Refresh()
        TearDownDatabaseAndLogin -server $Server -databaseName $DatabaseName -loginName $LoginName
    }
}