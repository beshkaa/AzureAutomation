
#Delete disk after 14 Days of Last Start/Allocation state.

Workflow DiskDelete14Days
{
    param(
         [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
         [String]
         $SubscriptionName
         )

    $InformationPreference = "Continue"
    $WarningPreference = "SilentlyContinue"
    $ErrorActionPreference = "Continue"   


    Select-AzureRmSubscription -Subscription $SubscriptionName

    $diskList = Get-AzureRmDisk
    $inlineDate = (Get-Date).AddDays(-14)
    
    ForEach -Parallel ($diskObject in $diskList) 
    {
        if ($null -eq $diskObject.ManagedBy)
        {
           $vmLog = (Get-AzureRMLog -StartTime $inlineDate.DateTime -ResourceId $diskObject.Id).Authorization | Where-Object -Property Action -in -Value "Microsoft.Compute/disks/write"
           if (![boolean]$vmLog)
           {
                Write-Output "$($diskObject.Id) should be deleted"
                $diskObject | Remove-AzureRmDisk -Force
           }
       }
       
    }

}

DiskDelete14Days -SubscriptionName "Enterprise - SE - Restore to Azure"