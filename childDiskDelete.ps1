workflow childDiskDelete {
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $SubscriptionName,
         
        [Parameter(Mandatory = $true)]
        [String]
        $inlineDate
    )

    "=============================================================="
    "                  Running Disk Cleanup cycle"
    "=============================================================="

    #Delete all managed disks which have not been used
    $diskList = Get-AzureRmDisk
    ForEach -Parallel ($diskObject in $diskList) {
        if ($null -eq $diskObject.ManagedBy) {
            $vmLog = (Get-AzureRMLog -StartTime $inlineDate -ResourceId $diskObject.Id).Authorization | Where-Object -Property Action -in -Value "Microsoft.Compute/disks/write"
            if (![boolean]$vmLog) {
                #  $result = ($diskObject | Remove-AzureRmDisk -Force).Status
                $result = $false  #[DEBUG]
                Write-Output "Disk was not used and been removed | $($result) | $($vmLog[0].EventTimestamp) |$($diskObject.DiskSizeGB)GB | $($diskObject.Id) | $vmLog[0]."
            }
        }
    }
    
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
                    
                    #$result = (Remove-AzureStorageBlob -Container $containerObject.Name -Blob $blobObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey) -Force -PassThru)
                    $result = $false
                    Write-Output "Blob was not used and been deleted | $result | $($blobObject.LastModified) | $([math]::round($blob.Length/1MB)) | $(((Get-AzureStorageBlob -Container $containerObject.Name -Blob $blobObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey))).ICloudBlob.Uri.AbsoluteUri)"
                }
            }
        }
    }
}