
#Remove not used resource group.
#All resource groups without StorageAccount,VM object and created more then 14 days ago are removed
Workflow ResourceGroupDelete14Days {
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [String]
        $SubscriptionName
    )

    #To avoid spam in output
    $InformationPreference = "Continue"
    $WarningPreference = "SilentlyContinue"
    $ErrorActionPreference = "Continue" 
    $connectionName = "AzureRunAsConnection"

    try {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         
     
        "Logging in to Azure..."
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection) {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        }
        else {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }

    Select-AzureRmSubscription -Subscription $SubscriptionName
    $inlineDate = (Get-Date).AddDays(-14)

    $resourceGroupList = Get-AzureRmResourceGroup
    
    ForEach -Parallel ($resourceGroupObject in $resourceGroupList) {
        #All resource groups without StorageAccount,VM object and created more then 14 days ago are removed
        if ( !(Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupObject.ResourceGroupName) -and !(Get-AzureRmVM -ResourceGroupName  $resourceGroupObject.ResourceGroupName) -and !((Get-AzureRMLog -StartTime $inlineDate.DateTime -ResourceId $resourceGroupObject.ResourceId).Authorization | Where-Object -Property Action -in -Value "Microsoft.Resources/subscriptions/resourceGroups/write")) {
            $result = (Remove-AzureRmResourceGroup -ResourceGroupName $resourceGroupObject.ResourceGroupName -Force)
            Write-Output "RG was empty and been removed | $($result) | $($resourceGroupObject.ResourceGroupName)"
        }
    }
}
