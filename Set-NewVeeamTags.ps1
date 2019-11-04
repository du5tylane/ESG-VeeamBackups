break
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
set-location $dir

$VSphere = get-content .\vsphere.txt

Write-output "My directory is $dir"

If (get-command Get-VBRCredentials -ErrorAction silentlycontinue)
{
    Write-Output "Veeam snapin loaded"
}
else
{
    Write-Output "attempting to load veeam snapins"
    Import-Module veeam*
}

Add-PSSnapin VeeamPSSnapin -ErrorAction Ignore

# set credentials
$User = Get-Content .\account.txt
$pw = convertto-securestring (get-content .\encrypt.txt) -key (Get-Content .\10112017.key)
$Creds = New-Object System.Management.Automation.PSCredential($User,$pw)

# General variables that are dictacted by physical localtion
$site = $env:COMPUTERNAME.substring(0,5)
if ($site -eq "USBOI")
{
    # Have to put in a bandaid due to legacy naming convention
    # The datacenter name can not be changed due to citrix is bound to the legacy name
    $site = "Involta"
}
Write-Output "loction is $Site"

$backupserver = $env:COMPUTERNAME
Write-Output "backupserver is $backupserver"

$veeamcreds = Get-VBRCredentials -Name $($User)
$maxConcurrentJobs = 10
$backuppathserverarray = 'BackupPath:eccosan01','BackupPath:eccosan02'

# connect to vmware
if (Get-VIServer -Server $($VSphere) -Credential $Creds)
{
    Write-Output "Connected to viserver vcsa"
}
else
{
    Write-Output "Not connected, attempting to connect"
    Connect-VIServer -Server $($VSphere) -Credential $Creds 
}



# get the location in vmware (aka datacenter)
$Datacenter = @()
Get-VM -name $env:computername* | Get-View | ForEach-Object{
  $row = "" | Select-Object Name, Path
  $row.Name = $_.Name
  $current = Get-View $_.Parent
  $path = $_.Name
  do {
    $parent = $current
     if($parent.Name -ne "vm"){$path =  $parent.Name}
     $current = Get-View $current.Parent
  } while ($current.Parent -ne $null)
  $row.Path = $path
  $Datacenter += $row
}
# confirm we gathered the 'datacenter' object from vmware.
if ($Datacenter)
{
    Write-Output "Datacenter identified from child VM:  $Datacenter"
    # get all of the other virtual machines\guests in the datacenter object from vmware
    $VMs = get-vm -Location $Datacenter.path | 
        Where-Object {$_.powerstate -eq 'PoweredOn'} |
        Where-Object {$_.name -notlike "Template*"} | 
        Where-Object {$_.name -notlike "*d0*"} | 
        Where-Object {$_.name -notlike "*bkup*"} |
        Where-Object {$_.name -notlike "*test*"} |
        Where-Object {$_.name -notlike "*usboixenp*"} |
        Where-Object {$_.name -notlike "esgboi-*"}

        # Where-Object {(Get-TagAssignment -Entity $_ | Select-Object -ExpandProperty Tag) -notlike 'NoBackup'}
    
    Write-output "The following VM(s) (Count: $(($VMs | measure-object).count)) were found: `n $($VMs)"
    start-sleep 5
    # Loop through the virtual machines, starting powershell jobs up to the maximum concurrent
    function set-esgtag ()
    {
        param(
            [Parameter(Mandatory = $True)]
            [string] $location,
            [Parameter(Mandatory = $True)]
            [string] $tag
        )
        $newtag = $tag
        # "VeeamZip:In3Days"
        $tagverify = get-tag $tag -ErrorAction silentlycontinue
        if ($tagVerify)
        {
            $VMs = get-vm -location $location
            
            if ($location)
            {
                foreach($virtmachine in $VMs)
                {   
                    $virtmachine | New-TagAssignment $newtag
                    # $virtmachine | New-TagAssignment $retentiontag
                }
            }
        }
    }
}
break

$tags = ((Get-TagAssignment $virtmachine).tag.name) | Where-Object {$_ -like "tier*"}
$retentiontag = "VeeamZip:In2Weeks"
If ($tags)
{
    if ($tags -like "*eccosan01*")
    {
        $backuppathserver = "BackupPath:eccosan01"
    }
    elseif ($tags -like "*eccosan02*")
    {
        $backuppathserver = "BackupPath:eccosan02"
    }
    elseif ($tags -like "*synology*")
    {
        $backuppathserver = "BackupPath:usbo2bkupp01"
    }
} else {
    $backuppathserver = Get-Random -inputobject $backuppathserverarray
    # "$($backuppathserverarray[(Get-Random -Maximum ([array]$backuppathserverarray).count)])"
    Write-host "No VeeamTags configured.  Defaulting to $backuppathserver" -foregroundcolor red
    
}