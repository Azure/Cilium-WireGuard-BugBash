#!/usr/bin/env bash
set -e
set -o pipefail

ACCESS_TOKEN=$(az account get-access-token --query accessToken -o tsv) # No need to edit this
SUBSCRIPTION_ID="SUB ID DOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>
RESOURCE_GROUP="RG NAME GOES HERE" # <YOU NEED TO EDIT THIS!!!!!!> 
CLUSTER_NAME="CLUSTER NAME GOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>
API_VERSION="2025-02-02-preview" # No need to edit this
LOCATION="LOCATION CODE GOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>


curl -s -X PUT \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d @- \
  "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME?api-version=$API_VERSION" <<EOF
{
  "location": "$LOCATION",
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
EOF
