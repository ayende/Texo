param(
  [string]$url,
  [string]$ref
)

#reset global vars - useful when we execute for psh, because it reset the previous run values
$global:git = $null
$global:cmd = $null
$global:workingDir = $null
$global:email = $null
$global:name = $null
$global:build = $null

$origin_dir = Get-Location

trap [Exception] {
   cd $origin_dir
   
}

function load_settings([string]$url)
{
     trap [Exception] {
       write-error $_.Exception
       exit
    }
    $mutex = new-object System.Threading.Mutex($settingsFile)
    $mutex.WaitOne()
        
    $settingsFile = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($MyInvocation.ScriptName), "Settings.config")
    
    $settings = [xml](get-content $settingsFile)
    $currentProjects = ""
    foreach ($project in $settings.settings.project)
    {
        $currentProjects += $currentProjects + "`r`n"
        if($project.url -ne $url -or $project.ref -ne $ref)
        {   
            continue; 
        }
        $global:git = $project.git
        $global:cmd = $project.cmd
        $global:workingDir = $project.workingDir
        $global:email = $project.email
        $global:name = $project.name
        $global:build = $project.build
        $project.build = ([int]::Parse($project.build) + 1).ToString()
        
        write-host "Found settings for $url: $name" 
        
        
        $writerSettings = new-object System.Xml.XmlWriterSettings
        $writerSettings.OmitXmlDeclaration = $true
        $writerSettings.NewLineOnAttributes = $true
        $writerSettings.Indent = $true
        
        $writer = [System.Xml.XmlWriter]::Create($settingsFile, $writerSettings)
        
        $settings.WriteTo($writer)
        $writer.Flush()
        $writer.Close()
        
        $mutex.ReleaseMutex()
        $mutex.Close()
        
        return
    }
    
    $body = "Got a notification about a build for $url ($ref), but could not find a matching project to build with`r`nCurrentProjects`r`n"+$currentProjects
    send_email -subject "Could not find matching project for $url" -body $body
    write-error "Could not find matching project for $url"

    exit
}

function send_email([string]$subject, [string]$body)
{  
    trap [Exception] {
       write-error $_.Exception
       exit
    }
    $settingsFile = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($MyInvocation.ScriptName), "Settings.config")
    $settings= [xml](get-content $settingsFile)
    $emailSettings = $settings.settings.email
    $smtp = new-object System.Net.Mail.SmtpClient
    $smtp.Host = $emailSettings.smtpServer
    $smtp.Port = $emailSettings.port
    $smtp.EnableSsl = $emailSettings.useSSL
    $smtp.Credentials = new-object System.Net.NetworkCredential($emailSettings.username, $emailSettings.password)
    $smtp.Send($emailSettings.from,$email, $subject, $body)
    
}

load_settings($url)






$parts = $ref.Split('/')
$branch = $parts[$parts.Length -1]

$git_log = ""
if(Test-Path $workingDir/.git)  # repository exists
{
    Write-Host "Fetching updates from $git /  $branch as $env:username"
    cd $workingDir
    $git_log = git pull origin $branch
    Write-Host $git_log
    if($lastExitCode -ne 0)
    {
      $body = $git_log -join "`r`n"
      write-host $body
      send_email -subject "Failed to update repository: $name" -body $body
      exit
    }
    
    
    git submodule init
    git submodule update
}
else # need new updates
{
    Write-Host "Clone git repository from $git as $env:username"

    $git_log = git clone $git $workingDir 2>&1
    if($lastExitCode -ne 0)
    {
      $body = $git_log -join "`r`n"
      write-host $body
      send_email -subject "Failed to clone repository: $name" -body $body
      exit
    }
    cd $workingDir
    if( $branch -ne "master" ) {  # need to checkout the branch
		$git_log = git checkout remotes/origin/$branch -b $branch
	    $co_exit_code = $lastExitCode
        $body = $git_log -join "`r`n"
        write-host $body
          
        if($co_exit_code -ne 0)
        {
          send_email -subject "Failed to clone repository: $name, could not switch branch to $branch" -body $body
          exit
        }
    } 
    
    git submodule init
    git submodule update
}


write-output $git_log
write-host "done updating from repository" 

$log = $env:push_msg 
if($log -eq $null -or $log.Length -eq 0)
{
    $log = git log -1 --oneline
}

$env:ccnetnumericlabel = $build
$env:buildlabel = $build

write-host "Build started for $name $ref"
send_email -subject "Build started for $name $ref" -body "Starting build for $name for:`r`n$log"
$error.Clear()
$buildStart = [DateTime]::Now
$output = Invoke-Expression "$cmd 2>&1"  -ErrorAction silentlycontinue
if ($error.Count -gt 0 -or $lastexitcode -ne 0) 
{
    $body = "Build failed for $name $ref. Duration $([DateTime]::Now - $buildStart) for:`r`n$log`r`n`r`nBuild Log:`r`n" + ($output -join "`r`n") + "`r`n$($error.Count) Errors: " + ($error -join "`r`n")
    write-host $body
    send_email -subject "Build FAILED for $name" -body $body
    write-host "BUILD FAILED"
}
else
{
   $body = "Build passed for $name $ref. Duration $([DateTime]::Now - $buildStart) for:`r`n$log`r`n`r`n" + ($output -join "`r`n")
   write-host $body
   send_email -subject "Build SUCCESSFULL for $name" -body $body
   write-host "BUILD SUCCESSFULL"
}

cd $origin_dir
