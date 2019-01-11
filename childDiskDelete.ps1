workflow childDiskDelete {
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $SubscriptionName,
         
        [Parameter(Mandatory = $true)]
        [String]
        $inlineDate,

        [Parameter(Mandatory = $true)]
        [String[]]
        $exceptionListSA
    )

    "=============================================================="
    "                  Running Disk Cleanup cycle"
    "=============================================================="
    "Stage 1(managed)"
    #Delete all managed disks which have not been used
        $diskList = Get-AzureRmDisk
        ForEach -Parallel ($diskObject in $diskList) {
            if ($null -eq $diskObject.ManagedBy) {
                $vmLog = (Get-AzureRMLog -StartTime $inlineDate -ResourceId $diskObject.Id).Authorization | Where-Object -Property Action -in -Value "Microsoft.Compute/disks/write"
                if (![boolean]$vmLog) {
                    $result = ($diskObject | Remove-AzureRmDisk -Force).Status
                    #$result = $false  #[DEBUG]
                    Write-Output "Disk was not used and been removed | $($result) | $($diskObject.DiskSizeGB)GB | $($diskObject.ResourceGroupName)\$($diskObject.Name) $($vmLog[0].EventTimestamp)"
                }
            }
        }
    
    "---------------------------------------------------------------"
    "Stage 2(unmanaged)"
    #Disassemble Container up to blob level and find&kill unused VHD
    $storageAccountList = Get-AzureRmStorageAccount
    ForEach -Parallel ($storageAccountObject in $storageAccountList) {
        # Write-Output "+ $($storageAccountObject.StorageAccountName) +" #[DEBUG]
        
        #Exclusion of presistent SA
        if ($exceptionListSA -notcontains $storageAccountObject.StorageAccountName) {
            $storageKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccountObject.ResourceGroupName -Name $storageAccountObject.StorageAccountName)[0].Value
            # Context is desearilized -- here and after not able to store in variable 
            $containerList = Get-AzureStorageContainer -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)
 
            #Disassembling container
            ForEach -Parallel ($containerObject in $containerList) {
                # Write-Output "[ $($containerObject.Name) ]"  #[DEBUG]
                
                $blobList = $null
                #Veeam Archive Blob is processed very slow. Getting only containers without Veeam/Archive folder
                if ( !(Get-AzureStorageBlob -Container $containerObject.Name -MaxCount 1 -Prefix Veeam/Archive -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)) ) {
                    $blobList = Get-AzureStorageBlob -Container $containerObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)                    
                }

                #Fetch all the Page blobs with extension, unlocked, with .vhd as only Page blobs can be attached as disk to Azure VMs
                ForEach -Parallel ($blobObject in $blobList) {
                    # write-output " $($blobObject.BlobType)     $((Get-AzureStorageBlob -Container $containerObject.Name -Blob $blobObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)).ICloudBlob.Properties.LeaseStatus)     $($blobObject.LastModified)     $($blobObject.Name)"  #DEBUG
                    
                    #Can move circumstances for optimization
                    if (($blobObject.Name -match "\.vhd$" ) -and (((Get-AzureStorageBlob -Container $containerObject.Name -Blob $blobObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)).ICloudBlob.Properties.LeaseStatus) -eq 'Unlocked') -and ($blobObject.LastModified -le $inlineDate) -and ($blobObject.BlobType -eq 'PageBlob')) {
                        $size = [math]::Round($blobObject.Length / 1073741824)
                        $uri = ((Get-AzureStorageBlob -Container $containerObject.Name -Blob $blobObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey))).ICloudBlob.Uri.AbsoluteUri
                        $result = (Remove-AzureStorageBlob -Container $containerObject.Name -Blob $blobObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey) -Force -PassThru)
                        #$result = $false #[DEBUG]
                        Write-Output "Blob was not used and been deleted | $result | $($size)GB | $($blobObject.LastModified) | $($uri)"
                    }
                }
            }
        }
    }

}

# $date = (Get-Date).AddDays(-14) #[DEBUG]
# childDiskDelete -SubscriptionName "Enterprise - SE - Restore to Azure" -inlineDate $date -exceptionListSA "emeaprgpersistent", "demoazurerestore" #[DEBUG]