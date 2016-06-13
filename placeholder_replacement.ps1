function Replace-Placeholder{
	param(
		[parameter(mandatory=$true)]
		[String]
		$directory,

		[parameter(mandatory=$true)]
		[String]
		$database,

		[parameter(mandatory=$true)]
		[String]
		$username,

		[String]
		$password = ""
	)

	$configFiles = Get-ChildItem $directory -Include @("*.properties","*.conf") -recurse
	#$configFiles
	foreach ($file in $configFiles)
	{
		(Get-Content $file.PSPath) |
		ForEach-Object {
			$_.replace('${database}', $database).
			replace('${username}', $username).
			replace('${password}', $password)
		} | Set-Content $file.PSPath
	}
}
