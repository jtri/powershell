# Some of the sql files have USE statements, this script will search and replace
# the value with the desired value
function Change-UseStatement
{
	param(
  	[String]
  	$replaceWith,
  	[String]
  	$Directory
	)


	$sqlFiles = Get-ChildItem $Directory *.sql -recurse
	foreach ($file in $sqlFiles)
	{
  	(Get-Content $file.PSPath) |
  	ForEach-Object { $_ -replace "USE \[.+\]", "USE [$replaceWith]" } |
  	Set-Content $file.PSPath
	}
}
