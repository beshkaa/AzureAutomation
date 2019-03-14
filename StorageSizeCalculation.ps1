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
    
    #Exception for VBR container 
    If (!(Get-AzureStorageBlob -Container $Container.Name -MaxCount 1 -Prefix Veeam/Archive -Context $storageContext)) {
        Get-AzureStorageBlob -Context $storageContext -Container $Container.Name | 
            ForEach-Object { 
            $containerSizeInBytes += Get-BlobBytes $_ 
            $blobCount++
        }
    } else { $containerSizeInBytes="Veeam Container"; $blobCount ="?"}

    return @{ "containerSize" = $containerSizeInBytes; "blobCount" = $blobCount }
}



$InformationPreference = "Continue"
$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Continue"   
$connectionName = "AzureRunAsConnection"


"**************************************************************"
"                   Calculation started."
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
$columnResourceGroup = New-Object system.Data.DataColumn ResourceGroup, ([string])
$columnStorageAccount = New-Object system.Data.DataColumn StorageAccount, ([string])
$columnName = New-Object system.Data.DataColumn Name, ([string])
$columnType = New-Object system.Data.DataColumn Type, ([string])
$columnChildren = New-Object system.Data.DataColumn Children, ([string])
$columnSize = New-Object system.Data.DataColumn Size, ([string])
$columnModification = New-Object system.Data.DataColumn Modification, ([string])

#Add the Columns
$table.columns.add($columnResourceGroup)
$table.columns.add($columnStorageAccount)
$table.columns.add($columnName)
$table.columns.add($columnType)
$table.columns.add($columnChildren)
$table.columns.add($columnSize)
$table.columns.add($columnModification)


#Core Processing. Disassabme Azure by ResourceGroup -> Storage Account -> Container 
foreach ($resourceGroup in $resourceGroupList) {
    $storageAccountList = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName
    
    if ($null -ne $storageAccountList) {
        foreach ($storageAccount in $storageAccountList) {
        
            $blobMetericResourceId = ($storageAccount.Id+"/blobServices/default")

        #[Report] Storage Account Details -- total Size and Objects #
            #Create a row
              $row = $table.NewRow()
   
            #Enter data in the row
              $row.$columnResourceGroup = "" 
              $row.$columnStorageAccount = "" 
              $row.$columnName = "<b> $($storageAccount.StorageAccountName) </b>"
              $row.$columnType = ""
              $row.$columnChildren = "$((Get-AzureRmMetric -ResourceId $blobMetericResourceId -MetricName BlobCount -EndTime (Get-Date).AddHours(-2) -AggregationType Total).Data.Total) Objects"
              $row.$columnSize = "$(  [math]::round(((Get-AzureRmMetric -ResourceId  $storageAccount.Id -MetricName UsedCapacity -EndTime (Get-Date).AddHours(-2) -AggregationType Total).Data.Total/1GB),2)) GB"
              $row.$columnModification = $storageAccount.CreationTime

            #Add the row to the table
              $table.Rows.Add($row)

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

            # Calculate size of container. 
            if ($containers.Count -gt 0) {
                $containers | ForEach-Object { 
                    $result = Get-ContainerBytes $_.CloudBlobContainer                   
                    
                    
                    $row = $table.NewRow()
   
                    #Enter data in the row
                    $row.$columnResourceGroup = $resourceGroup.ResourceGroupName 
                    $row.$columnStorageAccount = $storageAccount.StorageAccountName 
                    $row.$columnName = $_.CloudBlobContainer.Name
                    $row.$columnType = "Container"
                    $row.$columnChildren = "$($result.blobCount) blobs"
                    #Exception for VBR container
                    if ($result.containerSize -ne "Veeam Container") { $row.$columnSize = "$([math]::round(($result.containerSize / 1MB), 2)) MB" } else { $row.$columnSize = "Veeam Container" }
                    $row.$columnModification = $_.LastModified.DateTime
                 
                    #Add the row to the table
                    $table.Rows.Add($row)
                    
                    #Automation output
                    Write-Output ("Container '{0}' with {1} blobs has a size of {2:F2} . | {3}" -f `
                            $_.CloudBlobContainer.Name, $result.blobCount, $result.containerSize, $_.LastModified )
                }


                #[Report] Row with total amount of data in storage account. Decided to depricate
                #  $row = $table.NewRow()
   
                #Enter data in the row
                #  $row.$columnResourceGroup = $resourceGroup.ResourceGroupName 
                #  $row.$columnStorageAccount = $storageAccount.StorageAccountName 
                #  $row.$columnName = "Total"
                #  $row.$columnType = "Storage account "
                #  $row.$columnChildren = "$($containers.Count) Containers"
                #  $row.$columnSize = [math]::round(($sizeInBytes / 1GB), 2)
                #  $row.$columnModification = $storageAccount.CreationTime
                #  $table.Rows.Add($row)
                
                #[Report ]Add the row to the table to break data between containers
                  $row = $table.NewRow()
                  $table.Rows.Add($row) 
               
            ### [TBD] Should be replaced on azmetric
              #  Write-Output ("Total size calculated for {0} containers is {1:F2}GB | {2} | {3}\{4}" -f $containers.Count, ($sizeInBytes / 1GB), $storageAccount.CreationTime, $resourceGroup.ResourceGroupName, $storageAccount.StorageAccountName )
            }
            else {
                
                $row = $table.NewRow()
   
                #Enter data in the row
                $row.$columnResourceGroup = ""
                $row.$columnStorageAccount = ""
                $row.$columnName = "Empty or Access denied by firewall"
                $row.$columnType = " "
                $row.$columnChildren = ""
                $row.$columnSize = " "
                $row.$columnModification = ""
             
                #Add the row to the table
                $table.Rows.Add($row) 
                
                #Add splitter
                $row = $table.NewRow()
                $table.Rows.Add($row) 

                #Automation output
                Write-Output ("No containers found to process in storage account '{0}\{1}'" -f $resourceGroup.ResourceGroupName, $storageAccount.StorageAccountName )
            
            
            }
        }
    }
}



#Prepare data and send email
$preContent = "<h1> Storage consumption details for $(Get-Date) </h1> <h2> 14 Days checkpoint: $((Get-Date).AddDays(-14)) </h2>"
$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@
$resultHTML = $table | ConvertTo-Html -Property Name, Size, Modification, Children  -PreContent $preContent -Head $Header| Out-String
# Replacement of < > if using tags to format data. 
    $resultHTML = $resultHTML.replace('&lt;', '<')
    $resultHTML = $resultHTML.replace('&gt;', '>')

#$myCredential = Get-AutomationPSCredential -Name 'O365'
#No resolve dns method in automation
#$smptServer = (Resolve-DnsName -Name veeam.com -Type MX)[0].NameExchange 

$Domain = 'veeam.com'
$Uri = 'https://dns.google.com/resolve?name={0}&type=MX' -f $Domain
$smptServer = ((Invoke-RestMethod -Uri $URI).Answer.data[0] -Split ' ')[1]

Send-MailMessage -From 'Azure Automation <reports@democenter.veeam.com>' -To 'veeam.democenter.reports@veeam.com' -Subject "Azure Automation Report $(Get-Date)" -BodyAsHtml ($resultHTML) -SmtpServer $smptServer -Port '25'
