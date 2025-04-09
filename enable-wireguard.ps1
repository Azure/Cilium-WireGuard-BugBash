 $ErrorActionPreference = "Stop"

$accessToken = (az account get-access-token --query accessToken -o tsv) # No need to edit this
$subscriptionId = "SUB ID DOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>
$resourceGroup = "RG NAME GOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>
$clusterName = "CLUSTER NAME GOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>
$apiVersion = "2025-02-02-preview" # No need to edit this
$location = "LOCATION CODE GOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>

$jsonPayload = @"
{
  "location": "$location",
  "properties": {
    "networkProfile": {
      "networkPlugin": "cilium",
      "networkPluginMode": "overlay",
      "networkDataplane": "cilium",
      "networkPolicy": "cilium",
      "advancedNetworking": {
        "enabled": true,
        "observability": {
          "enabled": true
        },
        "security": {
          "enabled": true,
          "advancedNetworkPolicies": "None",
          "transitEncryption": {
             "type": "WireGuard"
          }
        } 
      }
    }
  }
}
"@

$url = ("https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.ContainerService/managedClusters/{2}?api-version={3}" -f $subscriptionId, $resourceGroup, $clusterName, $apiVersion)

 $response = Invoke-RestMethod -Uri $url -Method Put -Headers @{
    Authorization = "Bearer $accessToken"
    "Content-Type" = "application/json"
} -Body $jsonPayload

$response | ConvertTo-Json -Depth 10 

