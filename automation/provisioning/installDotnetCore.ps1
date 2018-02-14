Param (
	[string]$sdk,
	[string]$version,
	[string]$mediaDir
)
$scriptName = 'installDotnetCore.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
	$error.clear()
	Write-Host "$expression"
	try {
		$output = Invoke-Expression $expression
	    if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
	} catch { echo $_.Exception|format-list -force; exit 2 }
    if ( $error[0] ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $output
}

cmd /c "exit 0"
Write-Host "`n[$scriptName] ---------- start ----------"
if ( $sdk ) {
	Write-Host "[$scriptName] sdk      : $sdk (choices yes or no)"
} else {
	$sdk = 'no'
	Write-Host "[$scriptName] sdk      : $sdk (default, choices yes or no)"
}

if ( $version ) {
	Write-Host "[$scriptName] version  : $version"
} else {
	$version = '2.1.4'
	Write-Host "[$scriptName] version  : $version (default)"
}

if ( $mediaDir ) {
	Write-Host "[$scriptName] mediaDir : $mediaDir`n"
} else {
	$mediaDir = 'C:\.provision'
	Write-Host "[$scriptName] mediaDir : $mediaDir (not passed, set to default)`n"
}

if ( $sdk -eq 'yes' ) {
	$file = "dotnet-sdk-${$version}-win-x64.exe"
	$installer = "${mediaDir}\${file}"
	if ( Test-Path $installer ) {
		Write-Host "[$scriptName] Installer $installer found, download not required`n"
	} else {
		Write-Host "[$scriptName] $file does not exist in $mediaDir, listing contents"
		try {
			Get-ChildItem $mediaDir | Format-Table name
		    if(!$?) { $installer = listAndContinue }
		} catch { $installer = listAndContinue }

		Write-Host "[$scriptName] Attempt download"
		executeExpression "(New-Object System.Net.WebClient).DownloadFile('https://download.microsoft.com/download/1/1/5/115B762D-2B41-4AF3-9A63-92D9680B9409/dotnet-sdk-2.1.4-win-x64.exe', '$installer')"
	}
	
	$proc = executeExpression "Start-Process -FilePath '$installer' -ArgumentList '/INSTALL /QUIET /NORESTART /LOG $installer.log' -PassThru -Wait"
	if ( $proc.ExitCode -ne 0 ) {
		Write-Host "`n[$scriptName] Exit with `$LASTEXITCODE = $($proc.ExitCode)`n"
	    exit $proc.ExitCode
	}
}

# Reload the path (without logging off and back on)
Write-Host "[$scriptName] Reload path " -ForegroundColor Green
$env:Path = executeExpression "[System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')"

Write-Host "`n[$scriptName] ---------- stop -----------"
exit 0