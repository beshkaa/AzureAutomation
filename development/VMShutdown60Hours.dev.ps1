workflow VMShutdown60Hours
{
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String]
    $SubscriptionName
    )


$ErrorActionPreference = "silentlyContinue"   
#$connectionName = "AzureRunAsConnection"
#try
#{
    # Get the connection "AzureRunAsConnection "
#    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         
#
#    "Logging in to Azure..."
#    Add-AzureRmAccount `
#        -ServicePrincipal `
#        -TenantId $servicePrincipalConnection.TenantId `
#        -ApplicationId $servicePrincipalConnection.ApplicationId `
#        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
#}
#catch 
#{
#        if (!$servicePrincipalConnection)
#        {
#            $ErrorMessage = "Connection $connectionName not found."
#            throw $ErrorMessage
#        } else {
#        Write-Error -Message $_.Exception
#        throw $_.Exception
#        }
#}

Select-AzureRmSubscription -Subscription $SubscriptionName

$vmList = Get-AzureRmResource -ResourceType Microsoft.Compute/virtualMachines

$inlineDate = Get-Date
$inlineDate = $inlineDate.AddHours(-60)
Write-Output $inlineDateAdd

ForEach -Parallel ($vmObject in $vmList) 
{
    if ((Get-AzureRMVm -Name $vmObject.Name -ResourceGroupName $vmObject.ResourceGroupName -Status).Statuses[1].Code -ne "Powerstate/deallocated")
    {
        $vmLog = (Get-AzureRMLog -StartTime $inlineDate.DateTime -ResourceId $vmObject.Id).Authorization | Where-Object -Property Action -in -Value "Microsoft.Compute/virtualMachines/start/action", "Microsoft.Compute/virtualMachines/write"
        if (![boolean]$vmLog)
        {
            Write-Output ($vmObject.Name +" should be powered off ")
            #Stop-AzureRmVM -ResourceGroupName $vmObject.ResourceGroupName -Name $vmObject.Name -Force
        }
    }   
}
}

VMShutdown60Hours -SubscriptionName "Enterprise - SE - Restore to Azure"