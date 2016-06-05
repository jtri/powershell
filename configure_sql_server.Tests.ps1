. C:\scripts\configure_sql_server.ps1

Load-Assembly('Microsoft.SqlServer.Smo')

$ServerName = 'localhost'
try {
$Server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName
}
catch [Exception] { Write-Host "Could not get Sql Server Instance" }

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

    It 'Should throw error Login does not exist' {
    }

    It 'Should throw error that Database does not exist' {
    }

    It 'Should throw error that User is already member of Database' {
    }
}