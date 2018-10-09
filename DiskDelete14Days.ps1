
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

    $diskList = Get-AzureRmDisk
    $inlineDate = (Get-Date).AddDays(-14)
    
    ForEach -Parallel ($diskObject in $diskList) 
    {
        if ($diskObject.ManagedBy -eq $null)
        {
           $vmLog = (Get-AzureRMLog -StartTime $inlineDate.DateTime -ResourceId $diskObject.Id).Authorization | Where-Object -Property Action -in -Value "Microsoft.Compute/disks/write"
           if (![boolean]$vmLog)
           {
                Write-Output "$($diskObject.DiskSizeGB)GB - $($diskObject.Id) should be deleted"
                $diskObject | Remove-AzureRmDisk -Force
           }
       }
       
    }

}