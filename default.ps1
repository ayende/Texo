properties { 
  $base_dir  = resolve-path .
  $lib_dir = "$base_dir\SharedLibs"
  $build_dir = "$base_dir\build" 
  $buildartifacts_dir = "$build_dir\" 
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
  remove-item -force -recurse $buildartifacts_dir -ErrorAction SilentlyContinue 
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
	new-item $buildartifacts_dir -itemType directory 
} 

task Compile -depends Init { 
  exec msbuild "/p:OutDir=""$buildartifacts_dir "" $sln_file"
} 


task Release  -depends Compile {
	& $tools_dir\zip.exe -9 -A -j `
		$release_dir\Texo-$humanReadableversion-Build-$env:buildlabel.zip `
		$build_dir\bin\*.dll `
		$build_dir\Web.config `
		$build_dir\Settings.config `
		$build_dir\GitUpdate.ashx `
		$build_dir\Builder.ps1 `
		license.txt `
		readme.txt `
		acknowledgements.txt
		
	if ($lastExitCode -ne 0) {
        throw "Error: Failed to execute ZIP command"
    }
}

task Upload -depend Release {
	if (Test-Path $uploadScript ) {
		$log = git log -n 1 --oneline		
		msbuild $uploadScript /p:Category=$uploadCategory "/p:Comment=$log" "/p:File=$release_dir\Texo-$humanReadableversion-Build-$env:ccnetnumericlabel.zip"
		
		if ($lastExitCode -ne 0) {
			throw "Error: Failed to publish build"
		}
	}
	else {
		Write-Host "could not find upload script $uploadScript, skipping upload"
	}
}