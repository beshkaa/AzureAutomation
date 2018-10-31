workflow CleanupOrchestration {
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
        [String]
        $SubscriptionName
       
    )
    $daysToCheck = "-5"
    $excepionList = ""
    $inlineDate = (Get-Date).AddDays($daysToCheck)

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

    $output = Select-AzureRmSubscription -Subscription $SubscriptionName -ErrorAction Stop

    #[DEBUG]devChildRunbook -inlineDate $inlineDate

    "Subscription name     : "+$output.Subscription.Name

    #VM Cleanup cycle      
    childVmDelete -SubscriptionName $SubscriptionName -inlineDate $inlineDate
    
    #Disk Cleanup cycle      
    childDiskDelete -SubscriptionName $SubscriptionName -inlineDate $inlineDate


    Write-Output "Cleanup workflow finished."

}