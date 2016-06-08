# Some of the sql files have USE statements, this script will search and replace
# the value with the desired value

param(
  [String]
  $replace,
  [String]
  $Directory
)


$sqlFiles = Get-ChildItem $Directory *.sql -recurse
foreach ($file in $sqlFiles)
{
  (Get-Content $file.PSPath) |
  ForEach-Object { $_ -replace "USE \[.+\]", "USE [$replace]" } |
  Set-Content $file.PSPath
}
