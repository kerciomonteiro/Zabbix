# Clean up extra Azure Container Registries

This script helps clean up the multiple container registries that were created due to the previous naming convention issue.

## List all container registries in the resource group

```powershell
az acr list --resource-group Devops-Test --output table
```

## Delete extra container registries (keep only the one following the new naming convention)

The correct name should be: `acrzabbixdevopseastus`

```powershell
# List all ACRs to identify which ones to delete
$acrList = az acr list --resource-group Devops-Test --query "[].name" -o tsv

Write-Host "Found ACRs:"
$acrList | ForEach-Object { Write-Host "- $_" }

# Keep only the ACR with the correct naming pattern
$correctAcrName = "acrzabbixdevopseastus"
Write-Host "Correct ACR name should be: $correctAcrName"

# Delete other ACRs
$acrList | ForEach-Object {
    if ($_ -ne $correctAcrName) {
        Write-Host "Deleting ACR: $_"
        az acr delete --name $_ --resource-group Devops-Test --yes
    } else {
        Write-Host "Keeping ACR: $_"
    }
}
```

## Alternative: Manual cleanup

If you prefer to delete them manually:

```powershell
# List all ACRs
az acr list --resource-group Devops-Test --query "[].{Name:name, CreationDate:creationDate}" --output table

# Delete specific ACRs (replace with actual names)
az acr delete --name "acrzabbixdevopseastus29devopseastus" --resource-group Devops-Test --yes
az acr delete --name "acrzabbixdevopseastus30devopseastus" --resource-group Devops-Test --yes
# Add more delete commands as needed
```

## Prevent future duplicates

The workflow has been updated to:
1. Use consistent environment names (without run numbers)
2. Import existing resources before creating new ones
3. Use a simplified container registry naming: `acrzabbixdevops{location}`

This should prevent creating duplicate resources in future deployments.
