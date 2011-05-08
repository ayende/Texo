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
        
        foreach($build in $settings.settings.builds.project)
        {
            if($build.name -ne $project.name)
            {   
                continue; 
            }
             
            $global:build = $build.build
            $build.build = ([int]::Parse($build.build) + 1).ToString()
            break;
        }
         
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
send_email -subject "Finished updating repository: $name" -body $body