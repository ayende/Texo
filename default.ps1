properties { 
  $base_dir  = resolve-path .
  $lib_dir = "$base_dir\SharedLibs"
  $sln_file = "$base_dir\Texo.sln" 
  $version = "1.0.0.0"
  $humanReadableversion = "1.0"
  $tools_dir = "$base_dir\Tools"
  $release_dir = "$base_dir\Release"
  $uploadCategory = "Texo"
  $uploader = "..\Uploader\S3Uploader.exe"
} 

include .\psake_ext.ps1
	
task default -depends Release

task Clean { 
  remove-item -force -recurse $release_dir -ErrorAction SilentlyContinue 
} 

task Init -depends Clean { 
	
	Generate-Assembly-Info `
		-file "$base_dir\Texo\Properties\AssemblyInfo.cs" `
		-title "Texto $version" `
		-description "Simple build engine for GitHub using PowerShell" `
		-company "Hibernating Rhinos" `
		-product "Texo $version" `
		-version $version `
		-copyright "Hibernating Rhinos & Ayende Rahien 2009"

	new-item $release_dir -itemType directory 
} 

task Compile -depends Init { 
  exec msbuild $sln_file
} 


task Release -depends Compile {
	& $tools_dir\zip.exe -9 -A `
		$release_dir\Texo-$humanReadableversion-Build-$env:buildlabel.zip `
		$base_dir\Texo\bin\*.dll `
		$base_dir\Texo\Web.config `
		$base_dir\Texo\Settings.config `
		$base_dir\Texo\GitUpdate.ashx `
		$base_dir\Texo\Builder.ps1 `
		$base_dir\license.txt `
		$base_dir\readme.txt `
		$base_dir\acknowledgements.txt
		
	if ($lastExitCode -ne 0) {
        throw "Error: Failed to execute ZIP command"
    }
}

task Upload -depend Release {
	Write-Host "Starting upload"
	if (Test-Path $uploader) {
		$log = git log -n 1 --oneline		
		&$uploader "$uploadCategory" "$release_dir\NHibernate.Profiler-$humanReadableversion-Build-$env:buildlabel.zip" "$log"
		
		if ($lastExitCode -ne 0) {
			throw "Error: Failed to publish build"
		}
	}
	else {
		Write-Host "could not find upload script $uploadScript, skipping upload"
	}
}