#functions

Function GetDiskSize ($inDiskURI,$inStorageAccountList) { 
    # User running the script must have Read access to the VM Storage Accounts for these values to be retreive
    $error.clear() 
    $DiskContainer = ($inDiskURI.Split('/'))[3]  
    $DiskBlobName = ($inDiskURI.Split('/'))[4]  
 
    # Create Return PS object
    $BlobObject = @{'Name' = $inDiskURI; 'SkuName' = " "; 'SkuTier' = " "; 'DiskSize' = 0}

    # Avoid connecting to Storage if last disk in same Storage Account (Save significant time!) 
        $DiskSA = ((($inDiskURI).Split('/')[2]).Split('.'))[0] 
        $SAobj = $inStorageAccountList | where-object {$_.StorageAccountName -eq $DiskSA} 
        $SARG = $SAobj.ResourceGroupName 
        $SAKeys = Get-AzureRMStorageAccountKey -ResourceGroupName $SARG -Name $DiskSA 
        $SAContext = New-AzureStorageContext -StorageAccountName $DiskSA  -StorageAccountKey $SAKeys[0].value 

    $DiskObj = get-azurestorageblob -Context $SAContext -Container $DiskContainer -Blob $DiskBlobName 
    if ($Error) {   
        $BlobObject.DiskSize = -1  
        $error.Clear() 
    } 
    else { 
        [int] $DiskSize = $Diskobj.Length / 1024 / 1024 / 1024 # GB
        $BlobObject.DiskSize = $DiskSize
        $BlobObject.SkuName = $SAobj.Sku.Name
        $BlobObject.SkuTier = $SAobj.Sku.Tier 
    }  
 
    Return $BlobObject  

    trap { 
        Return $BlobObject 
    } 
}



#preparation
$resourceGroupObject = New-Object -TypeName psobject
$resourceGroupObject | Add-Member -MemberType NoteProperty -Name ResourceGroupName -Value "aphilippov"

$vmObject = New-Object -TypeName psobject
$vmObject | Add-Member -MemberType NoteProperty -Name Name -Value "aphil-storage"

$vmObject = Get-AzureRMVM -ResourceGroupName $resourceGroupObject.ResourceGroupName -Name $vmObject.Name

#initialization for disk inventory
$virtualmachine = $vmObject
$listStorageAccounts = Get-AzureRmStorageAccount 

#when it was deployed (timestamp)
$deploymentObjectTime = ((Get-AzureRmResourceGroupDeployment -ResourceGroupName aphilippov) | Where-Object {$_.DeploymentName -like "CreateVm*" -and $_.Parameters.virtualMachineName.Value -eq $vmObject.Name} | select -First 1).timestamp
$deploymentObjectTime

#size of vm
$vmObject.HardwareProfile.VmSize
$vmObject.StorageProfile.OsDisk.DiskSizeGB

{ 
    
$listStorageAccounts = Get-AzureRmStorageAccount 

#Disk Inventory
# Get VM OS Disk properties 
$OSDiskName = '' 
$OSDiskSize = 0
$OSDiskRepl = '' 
$OSDiskTier = ''
$OSDiskHCache = ''  # Init/Reset

# Get OS Disk Caching if set 
$OSDiskHCache = $virtualmachine.StorageProfile.osdisk.Caching

# Check if OSDisk uses Storage Account
if ($virtualmachine.StorageProfile.OsDisk.ManagedDisk -eq $null) {
    # Retreive OS Disk Replication Setting, tier (Standard or Premium) and Size 
    $VMOSDiskObj = GetDiskSize -inDiskURI $virtualmachine.StorageProfile.OsDisk.Vhd.uri -inStorageAccountList $listStorageAccounts
    $OSDiskName = $VMOSDiskObj.Name 
    $OSDiskSize = $VMOSDiskObj.DiskSize
    $OSDiskRepl = $VMOSDiskObj.SkuName 
    $OSDiskTier = "Unmanaged"
}
else {
    $OSDiskID = $virtualmachine.StorageProfile.OsDisk.ManagedDisk.Id
    $VMOSDiskObj = $AllMAnagedDisks | where-object {$_.id -eq $OSDiskID }
    $OSDiskName = $VMOSDiskObj.Name 
    $OSDiskSize = $VMOSDiskObj.DiskSizeGB
    $OSDiskRepl = $VMOSDiskObj.AccountType
    $OSDiskTier = "Managed"
}

$AllVMDisksPremium = $true 
if ($OSDiskRepl -notmatch "Premium") { $AllVMDisksPremium = $false } 

# Get VM Data Disks and their properties 
$DataDiskObj = @()
$VMDataDisksObj = @() 
foreach ($DataDisk in $virtualmachine.StorageProfile.DataDisks) { 

    # Initialize variable before each iteration
    $VMDataDiskName = ''
    $VMDataDiskSize = 0
    $VMDataDiskRepl = ''
    $VMDataDiskTier = ''
    $VMDataDiskHCache = '' # Init/Reset 

    # Get Data Disk Caching if set 
    $VMDataDiskHCache = $DataDisk.Caching
              
    # Check if this DataDisk uses Storage Account
    if ($DataDisk.ManagedDisk -eq $null) {
        # Retreive OS Disk Replication Setting, tier (Standard or Premium) and Size 
        $VMDataDiskObj = GetDiskSize -inDiskURI $DataDisk.vhd.uri -inStorageAccountList $listStorageAccounts
        $VMDataDiskName = $VMDataDiskObj.Name
        $VMDataDiskSize = $VMDataDiskObj.DiskSize
        $VMDataDiskRepl = $VMDataDiskObj.SkuName
        $VMDataDiskTier = "Unmanaged"
    }
    else {
        $DataDiskID = $DataDisk.ManagedDisk.Id
        $VMDataDiskObj = $AllMAnagedDisks | where-object {$_.id -eq $DataDiskID }
        $VMDataDiskName = $VMDataDiskObj.Name
        $VMDataDiskSize = $VMDataDiskObj.DiskSizeGB
        $VMDataDiskRepl = $VMDataDiskObj.AccountType
        $VMDataDiskTier = "Managed"
    }

    # Add Data Disk properties to arrray of Data disks object
    $DataDiskObj += @([pscustomobject]@{'Name' = $VMDataDiskName; 'HostCache' = $VMDataDiskHCache; 'Size' = $VMDataDiskSize; 'Repl' = $VMDataDiskRepl; 'Tier' = $VMDataDiskTier})

    # Check if this datadisk is a premium disk.  If not, set the all Premium disks to false (No SLA)
    if ($VMDataDiskRepl -notmatch "Premium") { $AllVMDisksPremium = $false } 
} 

}