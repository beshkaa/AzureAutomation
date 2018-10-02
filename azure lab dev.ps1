# Enable parallel
Workflow VmTracker
{
    param(
         [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
         [String]
         $SubscriptionName
    )


#   $SubscriptionName = "Enterprise - SE - Restore to Azure"
    Select-AzureRmSubscription -Subscription $SubscriptionName

    $vmList = Get-AzureRmResource -ResourceType Microsoft.Compute/virtualMachines

    $inlineDate = Get-Date
    $inlineDate = $inlineDate.AddHours(-60)

    ForEach -Parallel ($vmObject in $vmList) 
    {
        if ((Get-AzureRMVm -Name $vmObject.Name -ResourceGroupName $vmObject.ResourceGroupName -Status).Statuses[1].Code -eq "Powerstate/running")
        {
           $vmLog = Get-AzureRMLog -StartTime $inlineDate -ResourceId $vmObject.Id | Where-Object {($_.Authorization.Action -eq "Microsoft.Compute/virtualMachines/start/action") -or ($_.Authorization.Action -eq "Microsoft.Compute/virtualMachines/write")}
           if (![boolean]$vmLog)
              {
                  Write-Output "$($vmObject.Id) Should be powered off"
               }
       }
    
    
    }

}

VmTracker -SubscriptionName "Enterprise - SE - Restore to Azure"-Verbose