#
# Azure SQL Database SKU Reccomendations
#
CD "C:\Program Files\Microsoft Data Migration Assistant"

# Gather performance counter data
#
# Notes:
#  - winrm quickconfig must configure correctly (e.g. no public networks)
#  - script needs to be run as Administrator
#
.\SkuRecommendationDataCollectionScript.ps1 `
    -ComputerName ALPHAP51 `
    -OutputFilePath "C:\temp\dma\sku-counters.csv" `
    -CollectionTimeInSeconds 180 `
    -DbConnectionString "Server=localhost;Initial Catalog=master;Integrated Security=SSPI;"

# Gather performance counter data
.\DmaCmd.exe /Action=SkuRecommendation `
    /SkuRecommendationInputDataFilePath="C:\temp\dma\sku-counters.csv" `
    /SkuRecommendationTsvOutputResultsFilePath="C:\temp\dma\sku-prices.csv" `
    /SkuRecommendationJsonOutputResultsFilePath="C:\temp\dma\sku-prices.json" `
    /SkuRecommendationOutputResultsFilePath="C:\temp\dma\sku-prices.html" `
    /SkuRecommendationCurrencyCode=EUR `
    /SkuRecommendationOfferName="MS-AZR-0063P" `
    /SkuRecommendationRegionName=WestEurope `
    /SkuRecommendationSubscriptionId="INSERT_SUBSCRIPTION_ID_HERE" `
    /AzureAuthenticationInteractiveAuthentication=True `
    /AzureAuthenticationClientId="INSERT_CLIENT_ID_HERE" `
    /AzureAuthenticationTenantId="INSERT_TENANT_ID_HERE"


.\DmaCmd.exe /Action=SkuRecommendation `
    /SkuRecommendationInputDataFilePath="C:\temp\dma\sku-counters.csv" `
    /SkuRecommendationTsvOutputResultsFilePath="C:\temp\dma\sku-prices.csv" `
    /SkuRecommendationJsonOutputResultsFilePath="C:\temp\dma\sku-prices.json" `
    /SkuRecommendationOutputResultsFilePath="C:\temp\dma\sku-prices.html" `
    /SkuRecommendationPreventPriceRefresh=true
