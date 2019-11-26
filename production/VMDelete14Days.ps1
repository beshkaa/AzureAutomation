
#Delete VM after 14 Days of Last Start/Allocation state.

Workflow VMDelete14Days
{
    param(
         [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
         [String]
         $SubscriptionName
         )

    $InformationPreference = "Continue"
    $WarningPreference = "SilentlyContinue"
    $ErrorActionPreference = "Continue"   
    $connectionName = "AzureRunAsConnection"

     try
     {
         # Get the connection "AzureRunAsConnection "
         $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         
     
         "Logging in to Azure..."
         Add-AzureRmAccount `
             -ServicePrincipal `
             -TenantId $servicePrincipalConnection.TenantId `
             -ApplicationId $servicePrincipalConnection.ApplicationId `
             -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
     }
     catch 
     {
             if (!$servicePrincipalConnection)
             {
                 $ErrorMessage = "Connection $connectionName not found."
                 throw $ErrorMessage
             } else {
             Write-Error -Message $_.Exception
             throw $_.Exception
             }
     }
        
    Select-AzureRmSubscription -Subscription $SubscriptionName

    $vmList = Get-AzureRmResource -ResourceType Microsoft.Compute/virtualMachines
    $inlineDate = (Get-Date).AddDays(-14)
    
    ForEach -Parallel ($vmObject in $vmList) 
    {
        if ((Get-AzureRmVm -Name $vmObject.Name -ResourceGroupName $vmObject.ResourceGroupName -Status).Statuses[1].Code -eq "Powerstate/deallocated")
        {
           $vmLog = (Get-AzureRMLog -StartTime $inlineDate.DateTime -ResourceId $vmObject.Id).Authorization | Where-Object -Property Action -in -Value "Microsoft.Compute/virtualMachines/start/action", "Microsoft.Compute/virtualMachines/write"
           if (![boolean]$vmLog)
           {
                Write-Output "$($vmObject.Id) should be deleted"
                Remove-AzureRmResource -ResourceId $vmObject.Id -Force
           }
       }
       
    }

}