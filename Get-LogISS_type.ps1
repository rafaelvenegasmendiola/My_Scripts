$ScriptBlock = {
$xml = "C:\Windows\System32\inetsrv\config\applicationHost.config"
Function Get-NormalLogging_Fields {
    Import-Module WebAdministration
    $sites = (Get-ChildItem IIS:/Sites)
    $NormalFields = @()
    foreach ($site in $sites | ?{$_.name -ne "TelventMon"}) {
        $flags = $site.logFile.logExtFileFlags
        $i = 0
        foreach ($flag in $flags.Split(",")) {        
            $properties = @{
                Site = $site.name
                Order = $i++
                Flag = $flag
                Type = "Normal"
            }
            $NormalFields += New-Object -TypeName psobject -Property $properties        
        }
    }
    return $NormalFields 
}
Function Get-AdvancedLogging_Fields {
param ($xml)
[xml]$Application_host_file = Get-Content $xml
$Advfields = @()
$paths = $Application_host_file.configuration.location
foreach ($path in ($paths | ?{$_.path -ne "" -and $_.path -ne "TelventMon"})) {
    $flags = $path."system.webServer".advancedLogging.server.logDefinitions.logDefinition.selectedFields.logField
    $i = 0
    foreach ($flag in $flags) {
        if ($flag.logHeaderName -ne "") {
            $flagname = $flag.logHeaderName
        }
        else {
            $flagdefinition = ($Application_host_file.configuration."system.webServer".advancedLogging.server.fields.field | ?{$_.id -eq $flag.id})
            if ($flagdefinition.logheadername) {
                $flagname = $flagdefinition.logheadername
            }
            else {
                $flagname = $flagdefinition.id
            }
        }
        $Properties = @{
            Site = $path.Path
            FlagHeader = $flagname
            Order = $i++
            Type = "AdvLog"
        }
        $Advfields += New-Object -TypeName psobject -Property $Properties
    }
}
return $Advfields
}
Function Get-NormalLogging_Fields {
    Import-Module WebAdministration
    $sites = (Get-ChildItem IIS:/Sites)
    $NormalFields = @()
    foreach ($site in $sites | ?{$_.name -ne "TelventMon"}) {
        $flags = $site.logFile.logExtFileFlags
        $i = 0
        foreach ($flag in $flags.Split(",")) {        
            $properties = @{
                Site = $site.name
                Order = $i++
                FlagHeader = $flag
                Type = "Normal"
            }
            $NormalFields += New-Object -TypeName psobject -Property $properties        
        }
    }
    return $NormalFields 
}
Function Get-CompareFlags_normal_log {    
    $hashtable_normal_log = @{0="Date";1="Time";2="ClientIP";3="UserName";4="ServerIP";5="Method";6="UriStem";7="UriQuery";8="HttpStatus";9="Win32Status";10="BytesSent";11="BytesRecv";12="TimeTaken";13="ServerPort";14="UserAgent";15="Cookie";16="Referer";17="ProtocolVersion";18="Host";19="HttpSubStatus"}
    $report = @()
    $sites = (Get-NormalLogging_Fields).site | Get-Unique
    foreach ($site in $sites) {
        $obj = (Get-NormalLogging_Fields) | ?{$_.site -eq $site}
        if ($hashtable_normal_log.count -lt (Get-NormalLogging_Fields | ?{$_.site -eq $site}).count) {
            $count = ((Get-NormalLogging_Fields) | ?{$_.site -eq $site}).count
        }
        else {
            $count = $hashtable_normal_log.count
        }                    
        For ($i=0; $i -lt ($count); $i++) {
            if ($hashtable_normal_log[$i] -eq (($obj).FlagHeader[$i])) {
                $Properties = @{
                    Site = $obj.site[$i]
                    FlagHeader = $obj.FlagHeader[$i]
                    Order = $obj.order[$i]
                    Status = "OK"
                    Hash = $hashtable_normal_log[$i]
                    Type = "Normal Log"
                }
                $Report += New-object -TypeName psobject -Property $Properties                
            }
            else {
                $Properties = @{
                    Site = $obj.site[$i]
                    FlagHeader = $obj.FlagHeader[$i]
                    Order = $obj.order[$i]
                    Status = "Error"
                    Hash = $hashtable_normal_log[$i]
                    Type = "Normal Log"
                }
                $Report += New-object -TypeName psobject -Property $Properties                
            }
        }
    }
    return $Report
}
Function Get-CompareFlags_advanced_log {
    param($xml)
    $hastable_advanced_logging = @{0="date";1="time";2="s-sitename";3="s-computername";4="s-ip";5="cs-method";6="cs-uri-stem";7="cs-uri-query";8="s-port";9="cs-username";10="c-ip";11="cs-version";12="cs(Referer)";13="cs(Host)";14="sc-status";15="sc-substatus";16="sc-win32-status";17="sc-bytes";18="cs-bytes";19="TimeTaken";20="True-Client-IP";21="X-Forwarded-For";22="cs(User-Agent)";23="cs(Cookie)"}
    $report = @()
    $sites = (Get-AdvancedLogging_Fields -xml $xml).site | Get-Unique
    foreach ($site in $sites) {
        $obj = (Get-AdvancedLogging_Fields -xml $xml) | ?{$_.site -eq $site}
        if ($hastable_advanced_logging.count -lt ((Get-AdvancedLogging_Fields -xml $xml) | ?{$_.site -eq $site}).count) {
            $count = ((Get-AdvancedLogging_Fields -xml $xml) | ?{$_.site -eq $site}).count
        }
        else {
            $count = $hastable_advanced_logging.count
        }                
           For ($i=0; $i -lt ($count); $i++) {
            if ($hastable_advanced_logging[$i] -eq (($obj).FlagHeader[$i])) {
                $Properties = @{
                    Site = $obj.site[$i]
                    FlagHeader = $obj.FlagHeader[$i]
                    Order = $obj.order[$i]
                    Status = "OK"
                    Hash = $hastable_advanced_logging[$i]
                    Type = "Advanced Log"
                }
                $Report += New-object -TypeName psobject -Property $Properties                
            }
            else {
                $Properties = @{
                    Site = $obj.site[$i]
                    FlagHeader = $obj.FlagHeader[$i]
                    Order = $obj.order[$i]
                    Status = "ERROR"
                    Hash = $hastable_advanced_logging[$i]
                    Type = "Advanced Log"
                }
                $Report += New-object -TypeName psobject -Property $Properties                
            }
        }
    }
    return $Report
}
Function Get-Convert_Report_advanced_log_html {
    param($xml)
    $body = ""
    $body += "<h1>$env:COMPUTERNAME</h1>"
    foreach ($site in ((Get-CompareFlags_advanced_log -xml $xml).site | Get-unique)) {
        $body += "<h2>$site</h2>"
        $body += "<h3>$((Get-CompareFlags_advanced_log -xml $xml | ?{$_.site -eq $site}).Type | Get-unique)</h3>"
        $body += (Get-CompareFlags_advanced_log -xml $xml | ?{$_.site -eq $site}) | select site,order,hash,FlagHeader,status | ConvertTo-Html -As Table -Fragment
    }    
    ConvertTo-Html -Body $body
}
Function Get-Convert_Report_normal_log_html {   
    $body = ""
    $body += "<h1>$env:COMPUTERNAME</h1>"
    foreach ($site in ((Get-CompareFlags_normal_log).site | Get-unique)) {
        if (!$site) {}
        else {
        $body += "<h2>$site</h2>"
        $body += "<h3>$((Get-CompareFlags_normal_log | ?{$_.site -eq $site}).Type | Get-unique)</h3>"
        $body += (Get-CompareFlags_normal_log | ?{$_.site -eq $site}) | select site,hash,FlagHeader,status | ConvertTo-Html -As Table -Fragment
        }
    }
    ConvertTo-Html -Body $body
}
Function Get-Type_Log {
param ($xml)
[xml]$Application_host_file = Get-Content $xml
$AdvLogSection = (($Application_host_file.configuration.configSections.sectionGroup | ?{$_.name -eq "system.applicationHost"}).section) | ?{$_.name -eq "advancedLogging"}
if ($AdvLogSection) {
    Get-Convert_Report_advanced_log_html -xml $xml
}
else {
    Get-Convert_Report_normal_log_html
}
}
Get-Type_Log -xml $xml
}
$servernames = Get-Content C:\Itconic\Apps\Logs\Server\Server.txt
$c1 = 0
$body = ""
foreach ($server in $servernames) {
    $c1++
    Write-Progress -activity "Revisando $server" -CurrentOperation $server -Status "Processing $($c1) of $($servernames.count)" -PercentComplete (($c1 / $servernames.count) * 100) -ErrorAction SilentlyContinue
    $body += Invoke-Command -ComputerName $server -ScriptBlock $ScriptBlock
}
$report_file = "C:\temp\report_file.html"
$a = "<style>"
$a = $a + "BODY{font-face:verdana;font-size: 10pt}"
$a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$a = $a + "TH{border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color:thistle;font-face:verdana}"
$a = $a + "TD{border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color:palegoldenrod;font-face:verdana}"
$a = $a + "</style>"
ConvertTo-Html -Body $body -Head $a | Out-File $report_file
$smtpserver = "192.168.226.54"
$entorno = "$env:COMPUTERNAME"
$from = "$entorno@vueling.com"
$to = "rafael.venegas@itconic.com"#,"apps.mcs.support@itconic.com" 
$subject = "Report Log IIS $env:COMPUTERNAME"
$body2 = Get-Content $report_file | Out-String
Send-MailMessage -smtpServer $smtpserver -from $from -to $to -subject $subject -BodyAsHtml $body2