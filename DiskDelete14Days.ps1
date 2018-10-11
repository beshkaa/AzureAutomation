#Delete disk after 14 Days of Last Start/Allocation state *(managed and unmanaged).

Workflow DiskDelete14Days {
    #Expecting subscription as a parameter
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [String]
        $SubscriptionName
    )

    #Enviroment behavior 
    $InformationPreference = "Continue"
    $WarningPreference = "SilentlyContinue"
    $ErrorActionPreference = "Continue"   

    #Automation initialization
    $connectionName = "AzureRunAsConnection"
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


    #Enviroment initialization
    Select-AzureRmSubscription -Subscription $SubscriptionName
    $inlineDate = (Get-Date).AddDays(-14)
   
    #Delete all managed disks which have not been used
    $diskList = Get-AzureRmDisk
    ForEach -Parallel ($diskObject in $diskList) {
        if ($null -eq $diskObject.ManagedBy) {
            $vmLog = (Get-AzureRMLog -StartTime $inlineDate.DateTime -ResourceId $diskObject.Id).Authorization | Where-Object -Property Action -in -Value "Microsoft.Compute/disks/write"
            if (![boolean]$vmLog) {
                Write-Output "$($diskObject.DiskSizeGB)GB - $($diskObject.Id) should be deleted"
                $diskObject | Remove-AzureRmDisk -Force
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
                    Write-Output "Deleting blob: $($blobObject.LastModified) - $(((Get-AzureStorageBlob -Container $containerObject.Name -Blob $blobObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey))).ICloudBlob.Uri.AbsoluteUri)"
                    Remove-AzureStorageBlob -Container $containerObject.Name -Blob $blobObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey) -Force
                }
            }
        }
    }
}