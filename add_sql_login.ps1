function add_sql_login 
{

    param (
        [String] $inst = $null,
        [String] $loginName = $null,
        [String] $password = '',
        [String] $loginType = 'SqlLogin',
        [String] $loginRole = 'sysadmin'
    )

    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

    if ($sqlServer -eq $null) {
        try {
            $sqlServer = New-Object ('Microsoft.SqlServer.Management.SMO.Server') $inst
        } catch [Exception] {
            $error[0] | format-list -force
        }
    }

    if($sqlServer.Logins[$loginName] -ne $null) {
        Write-Host "$loginName already exists!"
        Exit 1
    }

    Write-Host "Creating login $loginName"
    try {
        $newLogin = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login `
                        -ArgumentList $sqlServer, $loginName
        $newLogin.LoginType = $loginType
        $newLogin.PasswordExpirationEnabled = $false
        $newLogin.PasswordPolicyEnforced = $false
        $newLogin.Create($password)
        $newLogin.AddToRole($loginRole)
        $newLogin.Alter()
    } catch [Exception] {
        $error[0] | format-list -force
    }

    $sqlServer.Refresh()

    if($sqlServer.Logins[$loginName] -ne $null) {
        Write-Host 'Login created successfully'
    }
}