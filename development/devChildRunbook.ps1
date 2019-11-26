workflow devChildRunbook
{

    param(
        [Parameter(Mandatory = $true)]
        [String]
        $inlineDate
    )

    "-----just a string-----"
    Select-AzureRmSubscription -Subscription "testerror"
    
    $inlineDate

    Write-Error "panic panic"
}