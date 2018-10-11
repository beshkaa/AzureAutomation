

Workflow DeleteUnattachedVHD14Days {
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [String]
        $SubscriptionName
    )

    $InformationPreference = "Continue"
    $WarningPreference = "SilentlyContinue"
    $ErrorActionPreference = "Continue"
     
    #Enviroment Initialization
    Select-AzureRmSubscription -Subscription $SubscriptionName
    $inlineDate = (Get-Date).AddDays(-14)

    #Disassemble Container up to blob level and find&kill unused VHD
    $storageAccountList = Get-AzureRmStorageAccount
    ForEach -Parallel ($storageAccountObject in $storageAccountList) {
        $storageKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccountObject.ResourceGroupName -Name $storageAccountObject.StorageAccountName)[0].Value
        
        # Context is desearilized -- here and after not able to store in variable 
        $containerList = Get-AzureStorageContainer -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)
      
        ForEach -Parallel ($containerObject in $containerList) {
            $blobList = Get-AzureStorageBlob -Container $containerObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)
            
            #Fetch all the Page blobs with extension, unlocked, with .vhd as only Page blobs can be attached as disk to Azure VMs
            ForEach -Parallel ($blobObject in $blobList) {
                
                #[DEBUG] write-output " $($blobObject.BlobType)     $((Get-AzureStorageBlob -Container $containerObject.Name -Blob $blobObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)).ICloudBlob.Properties.LeaseStatus)     $($blobObject.LastModified)     $($blobObject.Name)" 
                #Can move circumstances for optimization
                if (($blobObject.Name -match "\.vhd" ) -and (((Get-AzureStorageBlob -Container $containerObject.Name -Blob $blobObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)).ICloudBlob.Properties.LeaseStatus) -eq 'Unlocked') -and ($blobObject.LastModified -le $inlineDate) -and ($blobObject.BlobType -eq 'PageBlob')) {
                    Write-Output "Deleting blob: $($blobObject.LastModified) - $(((Get-AzureStorageBlob -Container $containerObject.Name -Blob $blobObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey))).ICloudBlob.Uri.AbsoluteUri)"
                    Remove-AzureStorageBlob -Container $containerObject.Name -Blob $blobObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey) -Force
                }
            }
        }
    }
}

DeleteUnattachedVHD14Days -SubscriptionName "Enterprise - SE - Restore to Azure"