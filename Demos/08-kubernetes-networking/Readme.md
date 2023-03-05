#### Kubernetes Networking 
```bash
New-AksHciCluster -name mycluster -nodePoolName nodepool1 -nodeCount 1 --primaryNetworkPlugin flannel
#ssh into target cluster 
ip link show type veth
ip link show type bridge
bridgle link show | grep cni0
ip route
```