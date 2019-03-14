# these are for the storage account to be used
$resourceGroup = "emea-prg-persistent"
$storageAccountName = "emeaprgpersistent"
$containerName = "hq-vbr1-archive"

# get a reference to the storage account and the context
$storageAccount = Get-AzStorageAccount `
  -ResourceGroupName $resourceGroup `
  -Name $storageAccountName
$ctx = $storageAccount.Context 

# get a list of all of the blobs in the container 
$listOfBLobs = (Get-AzStorageBlob -Container $ContainerName -Context $ctx -)

# zero out our total
$length = 0

# this loops through the list of blobs and retrieves the length for each blob
#   and adds it to the total
$listOfBlobs | ForEach-Object {$length = $length + $_.Length}

# output the blobs and their sizes and the total 
Write-Host "List of Blobs and their size (length)"
Write-Host " " 
$listOfBlobs | select Name, Length
Write-Host " "
Write-Host "Total Length = " $length


Measure-Command { (Get-AzStorageBlob -Container $ContainerName -Context $ctx)  }

Get-AzMetric -ResourceId "/subscriptions/{SubscriptionID}/resourceGroups/{RG name}/providers/Microsoft.Storage/storageAccounts/{storageAccount name}" -MetricNames BlobCount -MetricNamespace "blobServices/default"


Get-AzureRmMetric -ResourceId /subscriptions/2550c090-2cef-47e7-9edc-16b8d01a014d/resourceGroups/emea-prg-persistent/providers/Microsoft.Storage/storageAccounts/emeaprgpersistent/blobServices/default -MetricName BlobCount


##Batch processignd d
##

$MaxReturn = 10000
$containerName = "hq-vbr1-archive"
$Total = 0
$Token = $Null

Measure-Command -Expression {
do
 {
     $Blobs = Get-AzStorageBlob -Container $ContainerName -Context $ctx -MaxCount $MaxReturn  -ContinuationToken $Token
     $Total += $Blobs.Count
     if($Blobs.Length -le 0) { Break;}
     $Token = $Blobs[$blobs.Count -1].ContinuationToken;
 }
 While ($Token -ne $Null) }



 Get-AzureRmMetric -ResourceId /subscriptions/2550c090-2cef-47e7-9edc-16b8d01a014d/resourceGroups/emea-prg-persistent/providers/Microsoft.Storage/storageAccounts/emeaprgpersistent/blobServices/default -MetricName BlobCount
