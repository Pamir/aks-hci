```bash
Get-AksHciKubernetesVersion
Get-AksHciClusterUpdates -name target1
Update-AksHciCluster -name target1 -kubernetesVersion v1.21.2

#Update the container operating system version without updating the Kubernetes version
Update-AksHciCluster -name myCluster -operatingSystem

```

### Known Issues
https://docs.microsoft.com/en-us/azure-stack/aks-hci/known-issues-upgrade