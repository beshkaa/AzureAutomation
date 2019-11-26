workflow childResourceGroupDelete
{

    param(
        [Parameter(Mandatory = $true)]
        [String]
        $SubscriptionName,
         
        [Parameter(Mandatory = $true)]
        [String]
        $inlineDate,

        [Parameter(Mandatory = $false)]
        [String[]]
        $exceptionList
    )

    "=============================================================="
    "                 Resource Group Cleanup cycle"
    "=============================================================="

    $resourceGroupList = Get-AzureRmResourceGroup
    
    ForEach -Parallel ($resourceGroupObject in $resourceGroupList) {
        #All resource groups without StorageAccount,VM object and created more then 14 days ago are removed
        
        #"Checking "+$resourceGroupObject.ResourceGroupName #[DEBUG]
        #"-- RmVM insidwe: "+!(Get-AzureRmVM -ResourceGroupName  $resourceGroupObject.ResourceGroupName) #[DEBUG]
        #"-- Active in 14: "+!((Get-AzureRMLog -StartTime $inlineDate -ResourceId $resourceGroupObject.ResourceId).Authorization | Where-Object -Property Action -in -Value "Microsoft.Resources/subscriptions/resourceGroups/write") #[DEBUG]
        
        if (($exceptionList -notcontains $resourceGroupObject.ResourceGroupName) -and !(Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupObject.ResourceGroupName) -and !(Get-AzureRmVM -ResourceGroupName  $resourceGroupObject.ResourceGroupName) -and !((Get-AzureRMLog -StartTime $inlineDate -ResourceId $resourceGroupObject.ResourceId).Authorization | Where-Object -Property Action -in -Value "Microsoft.Resources/subscriptions/resourceGroups/write")) {
            #$result = (Remove-AzureRmResourceGroup -ResourceGroupName $resourceGroupObject.ResourceGroupName -Force)
            $result = $false
            Write-Output "RG was empty and been removed | $($result) | $($resourceGroupObject.ResourceGroupName)"
        }
    }
}

 #$date = (Get-Date).AddDays(-14) #[DEBUG]
 #childResourceGroupDelete -SubscriptionName "Enterprise - SE - Restore to Azure" -inlineDate $date -exceptionList "aphilippov" #[DEBUG]