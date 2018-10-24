
#Delete VM after 14 Days of deallocation state.
Workflow StorageAccountDelete14Days
{
    param(
         [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
         [String]
         $SubscriptionName
         )


    $SubscriptionName = "Enterprise - SE - Restore to Azure" #[<----- dev] 
    Select-AzureRmSubscription -Subscription $SubscriptionName

    $storageAccountList = Get-AzureRmResource -ResourceType Microsoft.Storage/storageAccounts

    $inlineDate = (Get-Date).AddDays(-14)

    ForEach -Parallel ($storageAccountObject in $storageAccountList) 
    {
        $storageAccountLog = (Get-AzureRMLog -StartTime $inlineDate.DateTime -ResourceId $storageAccountObject.Id).Authorization | Where-Object -Property Action -in -Value "Microsoft.Storage/storageAccounts/write"
           if (![boolean]$storageAccountLog)
              {
                  Write-Output "$($storageAccountObject.Id) Should be deleted"
               }
    }

}

StorageAccountDelete14Days -SubscriptionName "Enterprise - SE - Restore to Azure" -Verbose