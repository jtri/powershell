<#
The MIT License (MIT)

Copyright (c) 2015 Michael Kropat

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>

<#
.SYNOPSIS
Run schema migration scripts on a SQL Server databse
.DESCRIPTION
The database version is kept track of in an extended property ('db-version') on
the SQL Server database.  The version number comes from the prefix of the
filename of each .sql migration script (see -SchemaDir parameter help for more
information).
.PARAMETER Server
The SQL Server instance to connect to.  For example: (local)\SQLEXPRESS
.PARAMETER Database
The name of the database to run the migration on.
.PARAMETER SchemaDir
A directory containing one or more .sql files that have a numeric prefix in the
filename.  The numeric prefix represents the database version that that
particular migration script upgrades the database to.  Versions are compared by
_string ordering_ to determine which one is greater.  To minimize version
control merge conflicts, it is recommended to use the current date in YYYYMMDD
format, followed by a -NN (-01, -02, etc.) sequentially incrementing counter.
An example schema directory might look like:
  20150221-01-create-table.sql
  20150221-02-populate-table.sql
  20150222-disallow-nulls.sql
.EXAMPLE
.\migrate-db.ps1 -Database 'your-db' -SchemaDir .\Db\Schema
.NOTES
Downgrade/rollback scripts aren't supported.  It wouldn't be hard to add
support for them.
If you get errors like: '"Could not load file or assembly 'Microsoft.SqlServer.BatchParser'
then try running the x86 version of PowerShell.
#>

param(
    [String]
    $Server = '(local)\SQLEXPRESS',

    [parameter(Mandatory=$true)]
    [String]
    $Database,

    [parameter(Mandatory=$true)]
    [String]
    $SchemaDir
)

Add-Type -AssemblyName 'Microsoft.SqlServer.Smo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91'

function main {
    $db = Open-Database $Server $Database

    $original = Get-DbVersion $db

    Write-Host "Database '$Database' is at version: $original"

    $migrations = Get-SchemaMigrations $SchemaDir

    try {
        Invoke-Migrations $db $migrations
    }
    finally {
        $current = Get-DbVersion $db

        if ($current -gt $original) {
            Write-Host "It has been migrated to: $current"
        }
        else {
            Write-Host "No migration performed — $original is the current version."
        }
    }
}

function Open-Database($Server, $Database) {
    $s = New-Object Microsoft.SqlServer.Management.Smo.Server $Server
    $db = $s.Databases[$Database]
    if ($db -eq $null) {
        throw "Unable to open database '$Database'"
    }
    $db
}

function Get-SchemaMigrations($Dir) {
    Get-ChildItem -Path $Dir -File -Filter '*.sql' |
        where { $_ -match '^([-_0-9]+)' } |
        foreach {
            $prefix = ($_.Name | Select-String -Pattern '^([-_0-9]+)').Matches[0].Groups[1].Value

            @{
                Path = $_.FullName
            }
        }
}

function Invoke-Migrations($Database, $Migrations) {
    try {
        foreach ($m in $Migrations) {
            Invoke-Migration $Database $m
        }
    }
    catch {
        throw $_.Exception
    }
}

function Invoke-Migration($Database, $Migration) {
    $conn = Get-DbConnection $Database
    $script = Get-Content $Migration.Path -Raw

    $conn.BeginTransaction()

        $Database.ExecuteNonQuery($script)
        Set-DbVersion $Database $Migration.Version

    $conn.CommitTransaction()
}

function Get-DbConnection {
    param(
        [Microsoft.SqlServer.Management.Smo.Database]
        $Database
    )

    [Microsoft.SqlServer.Management.Common.ServerConnection]$Database.Parent.ConnectionContext
}

$script:versionPropertyName = 'db-version'

function Get-DbVersion {
    param(
        [Microsoft.SqlServer.Management.Smo.Database]
        $Database
    )

    if ($Database.ExtendedProperties.Contains($script:versionPropertyName)) {
        [String]$Database.ExtendedProperties['db-version'].Value
    }
    else {
        '0'
    }
}

function Set-DbVersion {
    param(
        [Microsoft.SqlServer.Management.Smo.Database]
        $Database,
        $Version
    )

    if ($Database.ExtendedProperties.Contains($script:versionPropertyName)) {
        $property = $Database.ExtendedProperties[$script:versionPropertyName]
        $property.Value = $Version
        $property.Alter()
    }
    else {
        $property = New-Object Microsoft.SqlServer.Management.Smo.ExtendedProperty -ArgumentList $Database,$script:versionPropertyName,$Version
        $property.Create()
    }
}

main
