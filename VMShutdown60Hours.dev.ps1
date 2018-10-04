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
    if ((Get-AzureRMVm -Name $vmObject.Name -ResourceGroupName $vmObject.ResourceGroupName -Status).Statuses[1].Code -eq "Powerstate/running")
    {
        $vmLog = Get-AzureRMLog -StartTime $inlineDate.DateTime -ResourceId $vmObject.Id | Where-Object {($_.Authorization.Action -eq "Microsoft.Compute/virtualMachines/start/action") -or ($_.Authorization.Action -eq "Microsoft.Compute/virtualMachines/write")}
        Write-Output $inlineDate.DateTime
        Write-Output $vmLog
        if (![boolean]$vmLog)
        {
            Write-Output ($vmObject.Name +" should be powered off ")
            Stop-AzureRmVM -ResourceGroupName $vmObject.ResourceGroupName -Name $vmObject.Name -Force
        }
    }   
}
}

VMShutdown60Hours -SubscriptionName "Enterprise - SE - Restore to Azure"