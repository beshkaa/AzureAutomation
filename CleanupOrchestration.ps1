workflow CleanupOrchestration {
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [String]
        $SubscriptionName,
       
        [Parameter(Mandatory = $true)]
        [String]
        $daysToCheck,

        [Parameter(Mandatory = $false)]
        [String[]]
        $exceptionListSA,

        [Parameter(Mandatory = $false)]
        [String[]]
        $exceptionListRG

    )
 
    $InformationPreference = "Continue"
    $WarningPreference = "SilentlyContinue"
    $ErrorActionPreference = "Continue"   
    $connectionName = "AzureRunAsConnection"

    $inlineDate = (Get-Date).AddDays(-$daysToCheck)

    "**************************************************************"
    "                   Cleanup workflow started."
    "=============================================================="
    
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

    $result = Select-AzureRmSubscription -Subscription $SubscriptionName -ErrorAction Stop

    "Subscription name     : " + $result.Subscription.Name

    Checkpoint-Workflow
    #VM Cleanup cycle      
    childVmDelete -SubscriptionName $SubscriptionName -inlineDate $inlineDate
    
    Checkpoint-Workflow
    #Disk Cleanup cycle      
    childDiskDelete -SubscriptionName $SubscriptionName -inlineDate $inlineDate -exceptionListSA $exceptionListSA

    Checkpoint-Workflow
    #Storage Account Delete
    childStorageAccountDelete -SubscriptionName $SubscriptionName -inlineDate $inlineDate -exceptionList $exceptionListSA

    Checkpoint-Workflow
    #Resource Group Delete
    childResourceGroupDelete -SubscriptionName $SubscriptionName -inlineDate $inlineDate -exceptionList $exceptionListRG


    "=============================================================="
    "                   Cleanup workflow finished."
    "**************************************************************"
}