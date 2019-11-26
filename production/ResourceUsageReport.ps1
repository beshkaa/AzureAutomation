#functions

Function GetDiskSize ($inDiskURI, $inStorageAccountList) { 
    # User running the script must have Read access to the VM Storage Accounts for these values to be retreive
    $error.clear()
    $DiskContainer = ($inDiskURI.Split('/'))[3]  
    $DiskBlobName = ($inDiskURI.Split('/'))[4]  
 
    # Create Return PS object
    $BlobObject = @{'Name' = $inDiskURI; 'SkuName' = " "; 'SkuTier' = " "; 'DiskSize' = 0}

    # Avoid connecting to Storage if last disk in same Storage Account (Save significant time!) 
    $DiskSA = ((($inDiskURI).Split('/')[2]).Split('.'))[0] 
    $SAobj = $inStorageAccountList | where-object {$_.StorageAccountName -eq $DiskSA} 
    $SARG = $SAobj.ResourceGroupName 
    $SAKeys = Get-AzureRMStorageAccountKey -ResourceGroupName $SARG -Name $DiskSA 
    $SAContext = New-AzureStorageContext -StorageAccountName $DiskSA  -StorageAccountKey $SAKeys[0].value 

    $DiskObj = get-azurestorageblob -Context $SAContext -Container $DiskContainer -Blob $DiskBlobName 
    if ($Error) {   
        $BlobObject.DiskSize = -1  
        $error.Clear()
    } 
    else { 
        [int] $DiskSize = $Diskobj.Length / 1024 / 1024 / 1024 # GB
        $BlobObject.DiskSize = $DiskSize
        $BlobObject.SkuName = $SAobj.Sku.Name
        $BlobObject.SkuTier = $SAobj.Sku.Tier 
        $BlobObject.Date = $DiskObj.LastModified.DateTime                
    }
 
    Return $BlobObject  

    trap { 
        Return $BlobObject 
    } 
}


function GetVMDisks ($virtualmachine) { 
    
    $listStorageAccounts = Get-AzureRmStorageAccount 
    $DiskObj = @()

    #Disk Inventory
    # Get VM OS Disk properties 
    $OSDiskName = '' 
    $OSDiskSize = 0
    $OSDiskRepl = '' 
    $OSDiskTier = ''
    $OSDiskHCache = ''  # Init/Reset

    # Get OS Disk Caching if set 
    $OSDiskHCache = $virtualmachine.StorageProfile.osdisk.Caching

    # Check if OSDisk uses Storage Account
    if ($virtualmachine.StorageProfile.OsDisk.ManagedDisk -eq $null) {
        # Retreive OS Disk Replication Setting, tier (Standard or Premium) and Size 
        $VMOSDiskObj = GetDiskSize -inDiskURI $virtualmachine.StorageProfile.OsDisk.Vhd.uri -inStorageAccountList $listStorageAccounts
        $OSDiskName = $VMOSDiskObj.Name 
        $OSDiskSize = $VMOSDiskObj.DiskSize
        $OSDiskRepl = $VMOSDiskObj.SkuName 
        $OSDiskTier = "Unmanaged"
        $OSDiskType = "OS Disk"
        $OSDiskDate = $VMOSDiskObj.Date
    }
    else {
        $OSDiskID = $virtualmachine.StorageProfile.OsDisk.ManagedDisk.Id
        $VMOSDiskObj = Get-AzureRmDisk -ResourceGroupName $virtualmachine.ResourceGroupName -DiskName $virtualmachine.StorageProfile.OsDisk.Name
        $OSDiskName = $VMOSDiskObj.Name 
        $OSDiskSize = $VMOSDiskObj.DiskSizeGB
        $OSDiskRepl = $VMOSDiskObj.Sku.Name
        $OSDiskTier = "Managed"
        $OSDiskType = "OS Disk"
        $OSDiskDate = $VMOSDiskObj.TimeCreated
    }

    $AllVMDisksPremium = $true 
    if ($OSDiskRepl -notmatch "Premium") { $AllVMDisksPremium = $false } 

    $DiskObj += @([pscustomobject]@{'Name' = $OSDiskName; 'HostCache' = $OSDiskHCache; 'Size' = $OSDiskSize; 'Repl' = $OSDiskRepl; 'Tier' = $OSDiskTier; 'Type' = $OSDiskType; 'AllPremium' = $AllVMDisksPremium; 'Date' = $OSDiskDate})

    # Get VM Data Disks and their properties 
    foreach ($DataDisk in $virtualmachine.StorageProfile.DataDisks) { 

        # Initialize variable before each iteration
        $VMDataDiskName = ''
        $VMDataDiskSize = 0
        $VMDataDiskRepl = ''
        $VMDataDiskTier = ''
        $VMDataDiskHCache = '' # Init/Reset 

        # Get Data Disk Caching if set 
        $VMDataDiskHCache = $DataDisk.Caching
              
        # Check if this DataDisk uses Storage Account
        if ($DataDisk.ManagedDisk -eq $null) {
            # Retreive OS Disk Replication Setting, tier (Standard or Premium) and Size 
            $VMDataDiskObj = GetDiskSize -inDiskURI $DataDisk.vhd.uri -inStorageAccountList $listStorageAccounts
            $VMDataDiskName = $VMDataDiskObj.Name
            $VMDataDiskSize = $VMDataDiskObj.DiskSize
            $VMDataDiskRepl = $VMDataDiskObj.SkuName
            $VMDataDiskTier = "Unmanaged"
            $VMDataDiskType = "Data Disk"
            $VMDataDiskDate = $VMDataDiskObj.Date
        }
        else {
            $DataDiskID = $DataDisk.ManagedDisk.Id
            $VMDataDiskObj = Get-AzureRmDisk -ResourceGroupName $virtualmachine.ResourceGroupName -DiskName $DataDisk.Name
            $VMDataDiskName = $VMDataDiskObj.Name
            $VMDataDiskSize = $VMDataDiskObj.DiskSizeGB
            $VMDataDiskRepl = $VMDataDiskObj.Sku.Name
            $VMDataDiskTier = "Managed"
            $VMDataDiskType = "Data Disk"
            $VMDataDiskDate = $VMDataDiskObj.TimeCreated
        }

        # Check if this datadisk is a premium disk.  If not, set the all Premium disks to false (No SLA)
        if ($VMDataDiskRepl -notmatch "Premium") { $AllVMDisksPremium = $false } 

        # Add Data Disk properties to arrray of Data disks object
        $DiskObj += @([pscustomobject]@{'Name' = $VMDataDiskName; 'HostCache' = $VMDataDiskHCache; 'Size' = $VMDataDiskSize; 'Repl' = $VMDataDiskRepl; 'Tier' = $VMDataDiskTier; 'Type' = $VMDataDiskType ; 'AllPremium' = $AllVMDisksPremium ; 'Date' = $VMDataDiskDate})
    } 
    Return $DiskObj

    trap { 
        Return $DiskObj
    } 
}


#preparation
#$resourceGroupObject = New-Object -TypeName psobject
#$resourceGroupObject | Add-Member -MemberType NoteProperty -Name ResourceGroupName -Value "aphilippov"

#$vmObject = New-Object -TypeName psobject
#$vmObject | Add-Member -MemberType NoteProperty -Name Name -Value "aphil-storage"

#$vmObject = Get-AzureRMVM -ResourceGroupName $resourceGroupObject.ResourceGroupName -Name $vmObject.Name

#initialization for disk inventory
#$virtualmachine = $vmObject
#$listStorageAccounts = Get-AzureRmStorageAccount 

#when it was deployed (timestamp)
#$deploymentObjectTime = ((Get-AzureRmResourceGroupDeployment -ResourceGroupName aphilippov) | Where-Object {$_.DeploymentName -like "CreateVm*" -and $_.Parameters.virtualMachineName.Value -eq $vmObject.Name} | select -First 1).timestamp
#$deploymentObjectTime

$InformationPreference = "Continue"
$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Continue"   
$connectionName = "AzureRunAsConnection"


"**************************************************************"
"                   Audit started"
"=============================================================="

try {
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    }
    else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

Select-AzureRmSubscription -SubscriptionId 2550c090-2cef-47e7-9edc-16b8d01a014d

$resourceGroupList = Get-AzureRmResourceGroup

#TABLE CREATION FOR Report Purpose
$tabelName = "Report Table"
#Create Table object
$table = New-Object system.Data.DataTable “$tabelName”

#Define Columns
$columnObjectType = New-Object system.Data.DataColumn ObjectType, ([string])
$columnType = New-Object system.Data.DataColumn Type, ([string])
$columnSize = New-Object system.Data.DataColumn Size, ([string])
$columnModification = New-Object system.Data.DataColumn Modification, ([string])

#Add the Columns
$table.columns.add($columnObjectType)
$table.columns.add($columnType)
$table.columns.add($columnSize)
$table.columns.add($columnModification)

"Processing objects"

foreach ($resourceGroupObject in $resourceGroupList) {
    #Automation log
    $resourceGroupObject.ResourceGroupName
    
    $vmList = Get-AzureRmVM -ResourceGroupName $resourceGroupObject.ResourceGroupName
    
    If ($vmList.Length -gt 0) {
    #[Report ]Add the row to the table to break ResourceGroup
    $row = $table.NewRow()
    $table.Rows.Add($row) 
    
    #Create a row
    $row = $table.NewRow()
   
    #Enter data in the row
    $row.$columnObjectType = ""
    $row.$columnType = "<b> $($resourceGroupObject.ResourceGroupName) </b>" 
    $row.$columnSize = "$($vmList.Length) VMs"
    $row.$columnModification = ""

    #Add the row to the table
    $table.Rows.Add($row)
    }

    foreach ($vmObject in $vmList) {
        #Automation log
        "|- $($vmObject.Name)" 
        $vmDiskTotalSize = $null
        $deploymentObjectTime = ((Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupObject.ResourceGroupName) | Where-Object {$_.DeploymentName -like "CreateVm*" -and $_.Parameters.virtualMachineName.Value -eq $vmObject.Name} | select -First 1).timestamp  
        $vmDisksList = GetVMDisks $vmObject

        foreach ($vmDisk in $vmDisksList) {
            #Automation log
            "  |-> $($vmDisk.Name)"
              $vmDiskTotalSize = $vmDiskTotalSize+$vmDisk.Size

              if ($null -eq $deploymentObjectTime){
                $deploymentObjectTime = "$($vmDisk.Date)"
              }
        }

        #Create a row
        $row = $table.NewRow()
   
        #Enter data in the row
        $row.$columnObjectType = "<b> $($vmObject.Name) </b>"
        $row.$columnType = "$($vmObject.HardwareProfile.VmSize)" 
        $row.$columnSize = "$($vmDiskTotalSize) GB"
        $row.$columnModification = "$($deploymentObjectTime)"

        #Add the row to the table
        $table.Rows.Add($row)

    }

}

#HTML generation with highlights

$fragments = @()
$fragments+= "<h1> Azure VM/disk usage for $(Get-Date) </h1> <h2> 14 Days checkpoint: $((Get-Date).AddDays(-14)) </h2>"
[xml]$html = $table | convertto-html -Fragment -Property ObjectType, Type, Size, Modification
 
for ($i=1;$i -le $html.table.tr.count-1;$i++) {
    
    #check for disk size
    if ((($html.table.tr[$i].td[2].Length -gt 0) -and (([int]$html.table.tr[$i].td[2].Substring(0,$html.table.tr[$i].td[2].Length-3))) -ge 500))
    {
      $class = $html.CreateAttribute("class")
      $class.value = 'alert'
      $html.table.tr[$i].childnodes[2].attributes.append($class) | out-null
    }

    #check for resource group start section
    if (($false -eq ($html.table.tr[$i].td[0] -and $html.table.tr[$i].td[3])) -and ($true -eq ($html.table.tr[$i].td[1] -and $html.table.tr[$i].td[2]))) {
      $class = $html.CreateAttribute("class")
      $class.value = 'resourcegroup'
      $html.table.tr[$i].attributes.append($class) | out-null
    }

    #check for Premium disk 
    if ($html.table.tr[$i].td[1] -match "Premium"){
        $class = $html.CreateAttribute("class")
        $class.value = 'alert'
        $html.table.tr[$i].childnodes[1].attributes.append($class) | out-null 
    }
  }
$fragments+= $html.InnerXml
$fragments+= "<p class='footer'>$(get-date)</p>"
$convertParams = @{ 
  head = @"
<Title>Azure Usage Report</Title>
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse; width: 75%}
TH {border-width: 1px; padding: 15px; border-style: solid; border-color: black; background-color: #6495ED; min-width: 150px;}
TD {border-width: 1px; padding: 5px;  border-bottom: 1px solid #ddd;}
.alert {font-weight: bold; color: red;}
.resourcegroup { background-color:#f0f0f0; }
</style>
"@
body = $fragments
}
$resultHTML = convertto-html @convertParams | Out-String

#replace special symbols to keep tags
$resultHTML = $resultHTML.replace('&lt;', '<')
$resultHTML = $resultHTML.replace('&gt;', '>')

#$myCredential = Get-AutomationPSCredential -Name 'O365'
#No resolve dns method in automation
#$smptServer = (Resolve-DnsName -Name veeam.com -Type MX)[0].NameExchange 

$Domain = 'veeam.com'
$Uri = 'https://dns.google.com/resolve?name={0}&type=MX' -f $Domain
$smptServer = ((Invoke-RestMethod -Uri $URI).Answer.data[0] -Split ' ')[1]

Send-MailMessage -From 'Azure Automation <reports@democenter.veeam.com>' -To 'veeam.democenter.reports@veeam.com' -Subject "Azure Automation Report $(Get-Date)" -BodyAsHtml ($resultHTML) -SmtpServer $smptServer -Port '25'


"**************************************************************"
"                   Audit finished"
"=============================================================="