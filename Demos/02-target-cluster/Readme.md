```bash
# deprecated
New-AksHciCluster -name mycluster -nodePoolName linuxnodepool -nodeCount 1 -osType Linux
#Preferred
Get-AksHciVmSize
New-AksHciCluster -name mycluster -nodePoolName nodepool1 -nodeCount 1 -nodeVmSize Standard_K8S3_v1 -osType linux
#SourceCode -

#https://github.com/microsoft/wssdagent
#https://github.com/microsoft/moc-pkg/blob/master/pkg/vmsize/vmsize.go 
New-AksHciCluster -name mycluster -nodePoolName nodepool1 -nodeCount 1 -osType linux -taints sku=gpu:NoSchedule
New-AksHciCluster -name mycluster -nodePoolName nodepool1 -nodeCount 1 -osType linux -nodeMaxPodCount 100
New-AksHciCluster -name mycluster -controlPlaneVmSize Standard_D4s_v3 -loadBalancerVmSize Standard_A4_v2 -nodePoolName nodepool1 -nodeCount 3 -nodeVmSize Standard_D8s_v3

New-AksHciCluster -name mycluster -controlPlaneNodeCount 3 -nodePoolName nodepool1 -nodeCount 3

New-AksHciCluster -name mycluster -nodePoolName nodepool1 -nodeCount 3 -enableMonitoring
#Please try with Arc
New-AksHciCluster -name mycluster -nodePoolName nodepool1 -nodeCount 3 -enableAdAuth

New-AksHciCluster -name mycluster -enableAutoScaler $true -autoScalerProfileName myAutoScalerProfile

```

Advnced Autoscaling
```bash
New-AksHciAutoScalerProfile -Name asp1 -AutoScalerProfileConfig @{ "min-node-count"=2; "max-node-count"=7; 'scale-down-unneeded-time'='1m'}

#change autoscaler config
Set-AksHciAutoScalerProfile -name myProfile -autoScalerProfileConfig @{ "max-node-count"=5; "min-node-count"=2 }

New-AksHciCluster -name mycluster -enableAutoScaler -autoScalerProfileName myAutoScalerProfile


Set-AksHciCluster -Name <string> [-enableAutoScaler <boolean>] [-autoScalerProfileName <String>] 

Set-AksHciCluster -Name <string> -enableAutoScaler $false

kubectl --kubeconfig $(Get-AksHciConfig).Kva.kubeconfig logs -l app=<cluster_name>-cluster-autoscaler
kubectl --kubeconfig $(Get-AksHciConfig).Kva.kubeconfig get events

kubectl --kubeconfig ~\.kube\config describe configmap cluster-autoscaler-status


```