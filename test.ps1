$currentPath = Split-Path ((Get-Variable MyInvocation -Scope Script).Value).MyCommand.Path
Write-Host "$currentPath"

#Import-Module "$currentPath\add_sql_login.ps1"
#Import-Module "$currentPath\create_database.ps1"
#Import-Module "$currentPath\add_user_to_db.ps1"
."$currentPath\add_sql_login.ps1"
."$currentPath\create_database.ps1"
."$currentPath\add_user_to_db.ps1"

add_sql_login -inst 'localhost' -loginName 'Jj' -password ''
create_sql_database -inst 'localhost' -username 'Jj' -password '' -dbName 'testDB'
add_user_to_db -inst 'localhost' -loginName 'Jj' -dbName 'testDB'