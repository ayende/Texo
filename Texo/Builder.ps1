param(
  [string]$url
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
    $settingsFile = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($MyInvocation.ScriptName), "Settings.config")
    $settings = [xml](get-content $settingsFile)
    $currentProjects = ""
    foreach ($project in $settings.settings.project)
    {
        $currentProjects += $currentProjects + "`r`n"
        if($project.url -ne $url)
        {   
            continue; 
        }
        write-host "Found settings for $url: $project.name" 
        $global:git = $project.git
        $global:cmd = $project.cmd
        $global:workingDir = $project.workingDir
        $global:email = $project.email
        $global:name = $project.name
        $global:build = $project.build
        $project.build = ([int]::Parse($project.build) + 1).ToString()
        
        $writerSettings = new-object System.Xml.XmlWriterSettings
        $writerSettings.OmitXmlDeclaration = $true
        $writerSettings.NewLineOnAttributes = $true
        $writerSettings.Indent = $true
        
        $writer = [System.Xml.XmlWriter]::Create($settingsFile, $writerSettings)
        
        $settings.WriteTo($writer)
        $writer.Flush()
        return
    }
    
    $body = "Got a notification about a build for $url, but could not find a matching project to build with`r`nCurrentProjects`r`n"+$currentProjects
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


if(Test-Path $workingDir/.git)  # repository exists
{
    Write-Host "Fetching updates from $git"
    cd $workingDir
    git pull
    git submodule update
}
else # need new updates
{
    Write-Host "Clone git repository from $git"
    git clone $git $workingDir
    git sumbodule init
    git sumdoule update
    cd $workingDir
}

$log = $env:push_msg 
if($log -eq $null -or $log.Length -eq 0)
{
    git log -1 --oneline
}

$env:ccnetnumericlabel = $build
$env:buildlabel = $build

write-host "Build started for $name"
send_email -subject "Build started for $name " -body "Starting build for $name for:`r`nlog"
$error.Clear()
$buildStart = [DateTime]::Now
$output = Invoke-Expression "$cmd 2>&1"  -ErrorAction silentlycontinue
if ($error.Count -gt 0 -or $lastexitcode -ne 0) 
{
    $body = "Build failed for $name. Duration $([DateTime]::Now - $buildStart) for:`r`n$log`r`n`r`nBuild Log:`r`n" + ($output -join "`r`n")
    write-host $body
    send_email -subject "Build FAILED for $name" -body $body
    write-host "BUILD FAILED"
}
else
{
   $body = "Build passed for $name. Duration $([DateTime]::Now - $buildStart) for:`r`n$log`r`n`r`n" + ($output -join "`r`n")
   write-host $body
   send_email -subject "Build SUCCESSFULL for $name" -body $body
   write-host "BUILD SUCCESSFULL"
}

cd $origin_dir