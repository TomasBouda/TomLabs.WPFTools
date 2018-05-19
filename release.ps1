# Updates all projects with given version number
param([String]$targetVersion, [String]$releaseNotes)

# FUNCTIONS

function IncreaseVersion(){
	param(
		[Parameter(
			Position=0,
			Mandatory=$true,
			ValueFromPipeline=$true,
			ValueFromPipelineByPropertyName=$true)
		]
		[Alias('VersionString')]
		[String]$version
	)

	$pattern = '(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\.(\d+))?'
	$build = [convert]::ToInt32(($version | Select-String -Pattern $pattern | % {$_.matches.groups[3].Value}), 10) + 1

	return $version -replace $pattern, ('$1.$2.' + $build)
}

function UpdateNode($xml, $nodeName, $value){
Write-Host "setting $nodeName : $value"
	$targetNode = $xml.SelectSingleNode("//$nodeName")
	if(!$targetNode){
		Write-Host "Creating node: $nodeName"
		$targetNode = $xml.CreateElement($nodeName)
		$xml.Project.PropertyGroup.AppendChild($targetNode)
	}
	$targetNode.InnerText = $value
}

function Update-CsProj($csprojPath){
	Write-Host "Updating $csprojPath" -ForegroundColor Green

	$xml = New-Object XML
	$xml.Load($csprojPath)

	# Try to load latest version from AssemblyVersion
	if(!$global:targetVersion){
		$avNode = $xml.SelectSingleNode("//AssemblyVersion");
		if(!$avNode){
			UpdateNode $xml "AssemblyVersion" "1.0.0"
		}
		$global:targetVersion = $xml.SelectSingleNode("//AssemblyVersion").InnerText | IncreaseVersion
	}

	UpdateNode $xml "AssemblyVersion" $global:targetVersion
	UpdateNode $xml "FileVersion" $global:targetVersion
	UpdateNode $xml "Version" $global:targetVersion
	UpdateNode $xml "PackageReleaseNotes" $global:releaseNotes

	$xml.Save($csprojPath)
}

#END FUNCTIONS

$csproj = Get-ChildItem $PWD -Recurse -Include *.csproj | Select-Object -first 1
Update-CsProj($csproj)

(Get-Content "$PWD\appveyor.yml") -replace 'version: (.*)\.\{build\}', ('version: '+$targetVersion+'.{build}') | Out-File "$PWD\appveyor.yml" -Encoding utf8

$desc = if(!$releasenotes) { '#description:  #' } else { 'description: '+$releaseNotes+' #' };
(Get-Content "$PWD\appveyor.yml") -replace '(#)?description: (.*) #', ($desc) | Out-File "$PWD\appveyor.yml" -Encoding utf8

(Get-Content "$PWD\appveyor.yml") -replace 'release: (.*) #', ('release: v'+$targetVersion+' #') | Out-File "$PWD\appveyor.yml" -Encoding utf8

git add -A
git commit -m "Released v$targetVersion"
git tag "v$targetVersion"
git push origin "v$targetVersion"
git push

Write-Host "Updating versions to $targetVersion done." -ForegroundColor Green