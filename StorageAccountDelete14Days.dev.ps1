
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

    $SubscriptionName = "Enterprise - SE - Restore to Azure" #[<----- dev] 
    # $exceptionList = @("0365diag242","emo")
    
    Select-AzureRmSubscription -Subscription $SubscriptionName
    $inlineDate = (Get-Date).AddDays(-1)
    $storageAccountList = Get-AzureRmStorageAccount

    ForEach -Parallel ($storageAccountObject in $storageAccountList) {
        if (($storageAccountObject.CreationTime -lt $inlineDate) -and ($exceptionList -notcontains $storageAccountObject.StorageAccountName)) {
            Write-Output "$($storageAccountObject.StorageAccountName) time $($storageAccountObject.CreationTime)"
            
            $storageKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccountObject.ResourceGroupName -Name $storageAccountObject.StorageAccountName)[0].Value
       
            # Context is desearilized -- here and after not able to store in variable 
            $containerList = Get-AzureStorageContainer -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)
     
            ForEach -Parallel ($containerObject in $containerList) {
                $blobList = Get-AzureStorageBlob -Container $containerObject.Name -Context (New-AzureStorageContext -StorageAccountName $storageAccountObject.StorageAccountName -StorageAccountKey $storageKey)
                if ($blobList.Name -notmatch "\.vhd" )  {
                    Write-Output "Deleting $($storageAccountObject.StorageAccountName)"
                }
                
            }    
        }
    }
}

StorageAccountDelete14Days -SubscriptionName "Enterprise - SE - Restore to Azure" -exceptionList emeaprgpersistent