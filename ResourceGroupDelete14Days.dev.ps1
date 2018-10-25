
#Remove not used resource group.
#All resource groups without StorageAccount,VM object and created more then 14 days ago are removed
Workflow ResourceGroupDelete14Days
{
    param(
         [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
         [String]
         $SubscriptionName
         )


    $SubscriptionName = "Enterprise - SE - Restore to Azure" #[<----- dev] 
    Select-AzureRmSubscription -Subscription $SubscriptionName
    $inlineDate = (Get-Date).AddDays(-14)

    $resourceGroupList = Get-AzureRmResourceGroup
    
    ForEach -Parallel ($resourceGroupObject in $resourceGroupList) 
    {
        #All resource groups without StorageAccount,VM object and created more then 14 days ago are removed
        if ( !(Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupObject.ResourceGroupName) -and !(Get-AzureRmVM -ResourceGroupName  $resourceGroupObject.ResourceGroupName) -and !((Get-AzureRMLog -StartTime $inlineDate.DateTime -ResourceId $resourceGroupObject.ResourceId).Authorization | Where-Object -Property Action -in -Value "Microsoft.Resources/subscriptions/resourceGroups/write")) {
        Write-Output "RG was empty and been removed | $(Remove-AzureRmResourceGroup -ResourceGroupName $resourceGroupObject.ResourceGroupName -Force -WhatIf) | $($resourceGroupObject.ResourceGroupName)"
        }
    }
}

ResourceGroupDelete14Days -SubscriptionName "Enterprise - SE - Restore to Azure" -Verbose