
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

    $vmList = Get-AzureRmResource -ResourceType Microsoft.Compute/virtualMachines

    $inlineDate = (Get-Date).AddDays(-14)
    # [TBD] $inlineDate = $inlineDate.AddDays(-14)

    ForEach -Parallel ($vmObject in $vmList) 
    {
        if ((Get-AzureRmVm -Name $vmObject.Name -ResourceGroupName $vmObject.ResourceGroupName -Status).Statuses[1].Code -eq "Powerstate/deallocated")
        {
           $vmLog = Get-AzureRmLog -StartTime $inlineDate -ResourceId $vmObject.Id | Where-Object {($_.Authorization.Action -eq "Microsoft.Compute/virtualMachines/start/action") -or ($_.Authorization.Action -eq "Microsoft.Compute/virtualMachines/write")}
           if ([boolean]$vmLog)
              {
                  Write-Output "$($vmObject.Id) Should be deleted"
               }
       }
    
    
    }

}

StorageAccountDelete14Days -SubscriptionName "Enterprise - SE - Restore to Azure" -Verbose