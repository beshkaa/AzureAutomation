
#Delete VM after 14 Days of deallocation state.
Workflow StorageAccountDelete14Days {
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [String]
        $SubscriptionName,
         
        [Parameter(Mandatory = $false)]
        [String[]]
        $exceptionList
    )

    $InformationPreference = "Continue"
    $WarningPreference = "SilentlyContinue"
    $ErrorActionPreference = "Continue" 

    #[<----- dev] 
    $SubscriptionName = "Enterprise - SE - Restore to Azure" 
    
    Select-AzureRmSubscription -Subscription $SubscriptionName
    $inlineDate = (Get-Date).AddDays(-14)
    $storageAccountList = Get-AzureRmStorageAccount


    
    ForEach -Parallel ($storageAccountObject in $storageAccountList) {
        if (($storageAccountObject.CreationTime -lt $inlineDate) -and ($exceptionList -notcontains $storageAccountObject.StorageAccountName)) {
            
            $storageKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccountObject.ResourceGroupName -Name $storageAccountObject.StorageAccountName)[0].Value
       
            # Context is desearilized -- here and after not able to store in variable 
            $containerList = Get-AzureStorageContainer -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)
            
            #Removing all containers older then 14 days without VHD inside. VHD Deletion is handled as part of DiskDelete job, as more complecated
            ForEach ($containerObject in $containerList) {
                $blobList = Get-AzureStorageBlob -Container $containerObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)
                if (($containerObject.LastModified -lt $inlineDate) -and !($blobList.Name -match "\.vhd" )) {
                    Write-Output "$($containerObject.LastModified):$($storageAccountObject.StorageAccountName)\$($containerObject.name) - should be deleted - $(Remove-AzureStorageContainer -Name $containerObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey) -Force -WhatIf)"
                }
            }
          
            #Removing empty storage accounts
            $containerList = (Get-AzureStorageContainer -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey))
            if (!$containerList) {
                Write-Output "$($storageAccountObject.StorageAccountName) - should be deleted - $(Remove-AzureRmStorageAccount -Name $storageAccountObject.StorageAccountName -ResourceGroupName $storageAccountObject.ResourceGroupName -Force -WhatIf)"
            }
        }
    }
}

StorageAccountDelete14Days -SubscriptionName "Enterprise - SE - Restore to Azure" -exceptionList emeaprgpersistent, demoazurerestore