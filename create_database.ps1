function create_sql_database 
{

    param (
        [String] $inst,
        [String] $username,
        [String] $password,
        [String] $dbName
    )
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

    try {
        $sqlServer = New-Object ('Microsoft.SqlServer.Management.SMO.Server') $inst
        #if($username -eq "" -and $password -eq "") {
        #    $sqlServer.ConnectionContext.LoginSecure = $true
        #} else {
        #    $sqlServer.ConnectionContext.LoginSecure = $false
        #    $sqlServer.ConnectionContext.set_Login($username)
        #    $sqlServer.ConnectionContext.set_Password($password)
        #}

        if($sqlServer.Databases[$dbName] -eq $null) {
            $db = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Database($sqlServer, $dbName)
            $db.Create()
        } else {
            Write-Host "Database already exists!"
        }

    } catch [Exception] {
        $error[0] | format-list -force
    }
}