#25/01/2018 APhilippov: v.2.0
#Orchestrated by main runbook
#Delete VM after $inlineDate of Last Start/Allocation/Deallocation state.

Workflow childVmDelete {
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $SubscriptionName,
         
        [Parameter(Mandatory = $true)]
        [String]
        $inlineDate
    )

    "=============================================================="
    "                  Running VM Cleanup cycle"
    "=============================================================="

    $vmList = Get-AzureRmResource -ResourceType Microsoft.Compute/virtualMachines
    ForEach -Parallel ($vmObject in $vmList) {
        if ((Get-AzureRmVm -Name $vmObject.Name -ResourceGroupName $vmObject.ResourceGroupName -Status).Statuses[1].Code -eq "Powerstate/deallocated") {
            $vmLog = (Get-AzureRMLog -StartTime $inlineDate -ResourceId $vmObject.Id).Authorization | Where-Object -Property Action -in -Value "Microsoft.Compute/virtualMachines/start/action", "Microsoft.Compute/virtualMachines/write"
            if (![boolean]$vmLog) {
                #$result = Remove-AzureRmResource -ResourceId $vmObject.Id -Force
                $result = $false   #[DEBUG]
                Write-Output "VM was not used and been removed | $($result) | $($vmObject.Id) $($vmLog[0].EventTimestamp)"
            }
        }
       
    }

}