
#Delete container and storage account after 14 days.
#Will delete diag container after 14 days as well, however that will not crash VM. 

workflow childStorageAccountDelete {

    param(
        [Parameter(Mandatory = $true)]
        [String]
        $SubscriptionName,
         
        [Parameter(Mandatory = $true)]
        [String]
        $inlineDate,

        [Parameter(Mandatory = $false)]
        [String[]]
        $exceptionList
    )

    "=============================================================="
    "                 Storage Account Cleanup cycle"
    "=============================================================="

    $storageAccountList = Get-AzureRmStorageAccount
    ForEach -Parallel ($storageAccountObject in $storageAccountList) {
        if (($storageAccountObject.CreationTime -lt $inlineDate) -and ($exceptionList -notcontains $storageAccountObject.StorageAccountName)) {
            
            #Getting storage key from vault
            $storageKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccountObject.ResourceGroupName -Name $storageAccountObject.StorageAccountName)[0].Value
       
            # Context is desearilized -- here and after not able to store it in variable. Using ()
            $containerList = Get-AzureStorageContainer -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)
            
            #Removing all containers older then 14 days without VHD inside. VHD Deletion is handled as part of DiskDelete job, as req more complecated logic
            ForEach ($containerObject in $containerList) {
                $blobList = Get-AzureStorageBlob -Container $containerObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)
                if (($containerObject.LastModified -lt $inlineDate) -and !($blobList.Name -match "\.vhd" )) {
                    $result = Remove-AzureStorageContainer -Name $containerObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey) -PassThru -Force
                    #$result = $false
                    Write-Output " Container is overdue and been deleted | $($result) | $($containerObject.LastModified) | $($storageAccountObject.StorageAccountName)\$($containerObject.name)"
                }
            }
          
            #Removing storage accounts without containers. 
            if (!$containerList) {
                $result = Remove-AzureRmStorageAccount -Name $storageAccountObject.StorageAccountName -ResourceGroupName $storageAccountObject.ResourceGroupName -Force   #Outpit is void? Microsoft, really?!
                $result = $true
                Write-Output "Storage Account is empty and been deleted | $($storageAccountObject.StorageAccountName) | $($result)"
            }
        }
    }
}