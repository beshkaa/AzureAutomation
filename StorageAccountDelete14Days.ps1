
#Delete container and storage account after 14 days.
#Will delete diag container after 14 days as well, however that will not crash VM. 
Workflow StorageAccountDelete14Days {
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [String]
        $SubscriptionName,
         
        [Parameter(Mandatory = $false)]
        [String[]]
        $exceptionList
    )

    #To avoid spam in output
    $InformationPreference = "Continue"
    $WarningPreference = "SilentlyContinue"
    $ErrorActionPreference = "Continue" 
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
           
    #Delete for last 2 weeks
    $inlineDate = (Get-Date).AddDays(-14)

    Select-AzureRmSubscription -Subscription $SubscriptionName
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
                    Write-Output "$($containerObject.LastModified):$($storageAccountObject.StorageAccountName)\$($containerObject.name) - should be deleted - $(Remove-AzureStorageContainer -Name $containerObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey) -Force -WhatIf)"
                }
            }
          
            #Reinitializing storage accounts without container.
            $containerList = (Get-AzureStorageContainer -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey))
            if (!$containerList) {
                Write-Output "$($storageAccountObject.StorageAccountName) - should be deleted - $(Remove-AzureRmStorageAccount -Name $storageAccountObject.StorageAccountName -ResourceGroupName $storageAccountObject.ResourceGroupName -Force -WhatIf)"
            }
        }
    }
}