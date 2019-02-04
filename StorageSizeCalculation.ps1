$VerbosePreference = "Continue"


<#
.SYNOPSIS
   Gets the size (in bytes) of a blob.
.DESCRIPTION
   Given a blob name, sum up all bytes consumed including the blob itself and any metadata,
   all committed blocks and uncommitted blocks.

   Formula reference for calculating size of blob:
       http://blogs.msdn.com/b/windowsazurestorage/archive/2010/07/09/understanding-windows-azure-storage-billing-bandwidth-transactions-and-capacity.aspx
.INPUTS
   $Blob - The blob to calculate the size of.
.OUTPUTS
   $blobSizeInBytes - The calculated size of the blob.
#>


function Get-BlobBytes {
    param (
        [Parameter(Mandatory = $true)]
        $Blob)
 
    # Base + blob name
    $blobSizeInBytes = 124 + $Blob.Name.Length * 2
 
    # Get size of metadata
    $metadataEnumerator = $Blob.ICloudBlob.Metadata.GetEnumerator()
    while ($metadataEnumerator.MoveNext()) {
        $blobSizeInBytes += 3 + $metadataEnumerator.Current.Key.Length + $metadataEnumerator.Current.Value.Length
    }
 
    if ($Blob.BlobType -eq [Microsoft.WindowsAzure.Storage.Blob.BlobType]::BlockBlob) {
        $blobSizeInBytes += 8
        $Blob.ICloudBlob.DownloadBlockList() | 
            ForEach-Object { $blobSizeInBytes += $_.Length + $_.Name.Length }
    }
    else {
        $Blob.ICloudBlob.GetPageRanges() | 
            ForEach-Object { $blobSizeInBytes += 12 + $_.EndOffset - $_.StartOffset }
    }

    return $blobSizeInBytes
}
 
<#
.SYNOPSIS
   Gets the size (in bytes) of a blob container.
.DESCRIPTION
   Given a container name, sum up all bytes consumed including the container itself and any metadata,
   all blobs in the container together with metadata, all committed blocks and uncommitted blocks.
.INPUTS
   $Container - The container to calculate the size of. 
.OUTPUTS
   $containerSizeInBytes - The calculated size of the container.
#>
function Get-ContainerBytes {
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.WindowsAzure.Storage.Blob.CloudBlobContainer]$Container)
 
    # Base + name of container
    $containerSizeInBytes = 48 + $Container.Name.Length * 2
 
    # Get size of metadata
    $metadataEnumerator = $Container.Metadata.GetEnumerator()
    while ($metadataEnumerator.MoveNext()) {
        $containerSizeInBytes += 3 + $metadataEnumerator.Current.Key.Length + 
        $metadataEnumerator.Current.Value.Length
    }

    # Get size for Shared Access Policies
    $containerSizeInBytes += $Container.GetPermissions().SharedAccessPolicies.Count * 512
 
    # Calculate size of all blobs.
    $blobCount = 0
    Get-AzureStorageBlob -Context $storageContext -Container $Container.Name | 
        ForEach-Object { 
        $containerSizeInBytes += Get-BlobBytes $_ 
        $blobCount++
    }
    return @{ "containerSize" = $containerSizeInBytes; "blobCount" = $blobCount }
}



Select-AzureRmSubscription -SubscriptionId 2550c090-2cef-47e7-9edc-16b8d01a014d

$resourceGroupList = Get-AzureRmResourceGroup

foreach ($resourceGroup in $resourceGroupList) {
    $storageAccountList = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName

    if ($null -ne $storageAccountList) {
        foreach ($storageAccount in $storageAccountList) {
 
            # Instantiate a storage context for the storage account.
            $storagePrimaryKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroup.ResourceGroupName -StorageAccountName $storageAccount.StorageAccountName)[0].Value
            $storageContext = New-AzureStorageContext -StorageAccountName $storageAccount.StorageAccountName -StorageAccountKey $storagePrimaryKey

            # Get a list of containers to process.
            $containers = New-Object System.Collections.ArrayList
            if ($ContainerName.Length -ne 0) {
                $container = Get-AzureStorageContainer -Context $storageContext `
                    -Name $ContainerName -ErrorAction SilentlyContinue | 
                    ForEach-Object { $containers.Add($_) } | Out-Null
            }
            else {
                Get-AzureStorageContainer -Context $storageContext | ForEach-Object { $containers.Add($_) } | Out-Null
            }

            # Calculate size.
            $sizeInBytes = 0
            if ($containers.Count -gt 0) {
                $containers | ForEach-Object { 
                    $result = Get-ContainerBytes $_.CloudBlobContainer                   
                    $sizeInBytes += $result.containerSize
                    Write-Output ("Container '{0}' with {1} blobs has a size of {2:F2}MB." -f `
                            $_.CloudBlobContainer.Name, $result.blobCount, ($result.containerSize / 1MB))
                }
                Write-Output ("Total size calculated for {0} containers is {1:F2}GB | {2} | {3}" -f $containers.Count, ($sizeInBytes / 1GB), $storageAccount.CreationTime, $resourceGroup.ResourceGroupName )

                # Launch default browser to azure calculator for data management.
                # Start-Process -FilePath http://www.windowsazure.com/en-us/pricing/calculator/?scenario=data-management
            }
            else {
                Write-Output ("No containers found to process in storage account '{0}'\'{1}'" -f $resourceGroup.ResourceGroupName, $storageAccount.StorageAccountName )
            }
        }
    }
}