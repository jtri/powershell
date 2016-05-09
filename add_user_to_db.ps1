function add_user_to_db
{

    param (
        [String] $inst = $null,
        [String] $loginName = $null,
        [String] $dbName = $null
    )
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

    if($sqlServer -eq $null) {
        try {
            $sqlServer = New-Object ('Microsoft.SqlServer.Management.SMO.Server') $inst
        } catch [Exception] {
            $error[0] | format-list -force
        }
    }

    $ourLogin = $sqlServer.Logins[$loginName]
    $ourDatabase = $sqlServer.Databases[$dbName]

    if($ourDatabase -eq $null) {
        Write-Host 'Database not found'
        Exit 1
    }
    if($ourLogin -eq $null) {
        Write-Host 'Login not found'
        Exit 1
    }

    $user = $ourDatabase.Users[$loginName]
    if($user -eq $null) {
        Write-Host "Adding $loginName to $dbName"
        $user = New-Object -TypeName Microsoft.SqlServer.Management.Smo.User `
                    -ArgumentList $ourDatabase, $loginName
        $user.Login = $loginName
        $user.Create()
    } else {
        Write-Host "$loginName already mapped to $dbName"
    }
}