
#### Introduction
In this article, we will investigate the functionality of the AKS Hybrid LoadBalancer, specifically focusing on the allocation of LoadBalancer-type services, the internal mechanisms of load balancing, and the reservation of external IP addresses. This comprehensive post aims to provide a clear understanding of the AKS Hybrid LoadBalancer's key components and their respective roles.

You have several options for creating an AKS Hybrid target cluster, including using the Windows Admin Center (WAC), PowerShell, Azure CLI, and Azure Portal. When utilizing the PowerShell functions of the AKS Hybrid module, you have the flexibility to modify the default settings as needed to customize the cluster according to your requirements. 


In the following command, we will create a target cluster featuring three HAProxy servers. The VM size of the load balancer will be configured with 4 CPUs and 6 GB of memory
```bash
$lbCfg New-AksHciLoadBalancerSetting -name "haProxyLB" -loadBalancerSku HAProxy -vmSize Standard_K8S3_v1 -loadBalancerCount 3
New-AksHciCluster -name "holidays" -nodePoolName "thanksgiving" -nodeCount 3 -OSType linux -nodeVmSize Standard_A4_v2 -loadBalancerSettings $lbCfg

```
The high-level illustration provided below presents the architecture of the AKS Hybrid target cluster, offering a  visual representation of the components and their relationships within the system, allowing for a better understanding of the overall structure for loadbalancing.
In the illustration, the green HAProxy server represents the active server, while the red HAProxy servers signify the passive ones
![AKS Target Cluster Architecture](./aks-loadbalancer/high-level-architecture.png)

When you run the 'kubectl get pods' command or attempt to interact with your Kubernetes API server, the HAProxy server accepts the traffic and  routes the command to the appropriate control plane server. When you finish your installation, on a clean target cluster, there are two IP addresses assigned to your  loadbalancers!
The first IP address, 192.168.0.17 is assigned from the NodeIpPool, while the other IP address, 192.168.0.156, is assigned from the VIP Pool. This allocation method ensures that the IP addresses are appropriately distributed within the AKS Hybrid cluster
![LoadBalancer IPs](./aks-loadbalancer/loadbalancer-ips.png)

Kubernetes Services can be assigned an external IP address when they need to be accessible from outside the cluster, such as when providing a public-facing API, web application, or any other service that needs to be exposed to the internet or external networks.

A Kubernetes Service gets an external IP address when its type is set to  LoadBalancer. Here's a brief overview of these service types:

**LoadBalancer:** When a Service is configured as a LoadBalancer, an external load balancer is provisioned by the cloud provider or the on-premises infrastructure. The load balancer directs external traffic to the pods backing the service. The Service gets an external IP address, which is typically assigned by the  the external load balancer which in our case is HA Proxy Servers.

**NodePort:** In the case of a NodePort service, a specific port is opened on each node in the cluster, and traffic sent to that port is forwarded to the appropriate pods backing the service. While this type of service doesn't automatically get an external IP address, you can still access the service externally by using the IP address of any node in the cluster and the allocated NodePort. In some cases, you might set up an external load balancer or DNS to route traffic to the node IP addresses and NodePorts, effectively giving the service an external IP address. **In AKS Hybrid, we do not recommend deploying NodePort Services to avoid being affected by upgrades, node auto-healing, and the inherent node auto-scaling features.**

When you deploy a LoadBalancer type service in Kubernetes, a NodePort is opened by default as part of the process. This is because the LoadBalancer service is built on top of the NodePort service. The reason for this design choice is to provide a consistent way for traffic to be routed to the appropriate pods, regardless of whether the traffic originates from within the cluster or from an external source.

In a LoadBalancer type service, the external load balancer directs incoming traffic to the nodes in the cluster, which then forward the traffic to the appropriate pods via the NodePort. Essentially, the LoadBalancer acts as an entry point to the cluster, while the NodePort is responsible for routing the traffic within the cluster.

Let's go ahead and deploy a LoadBalancer type service in AKS Hybrid and take a closer look at its behavior.

```bash
kubectl apply -f https://raw.githubusercontent.com/Pamir/kubernetes-essentials/master/04-services/05-frontend-svc.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: guestbook
    tier: frontend
  name: frontend
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: guestbook
    tier: frontend
  sessionAffinity: None
  type: LoadBalancer
```

When you deploy this service, you can use the command below to see that our frontend service receives an IP address from the VIP Pool.
![kgsvc-output](./aks-loadbalancer/external-ip-kgsvc.png)

And the Ip Address is assigned to the HA Proxy VMs as well.
![active-loadbalancer-ips](./aks-loadbalancer/active-loadbalancer-ips.png)

So, what's really going on behind the scenes, and how does everything come together so smoothly. In the control plane of the AKS target cluster, there's a pod, as shown at the top of the diagram, which is responsible for monitoring any changes to LoadBalancer type service deployments. When the MOC Cloud Controller Manager detects any changes, it communicates them to the cloud agent. The cloud agent then reserves an IP address from the VIP Pool and sends a request to the lbagent running on every HAProxy server. The lbagent is responsible for updating the HAProxy service configuration file, and then it executes a reload command for HAProxy using systemctl reload-restart haproxy.

![ha-proxy-internals](./aks-loadbalancer/haproxy-internals.png)

So far, we've covered the happy path for reserving IP addresses for LoadBalancer type services in AKS Hybrid. It's important to note that, for security reasons, all communication between these components is encrypted using certificates. If one of the certificates expires, the load balancer may not function as expected. As stated in Microsoft's official documentation on AKS Hybrid Cluster Certificates, it's necessary to periodically renew the internal components of AKS Hybrid certificates.

Additionally, there's one more parameter to consider: updating the lbagent certificates when they expire. This step is crucial to ensure that the entire system continues to function securely and effectively.That's great news! In the latest release, the certificate rotation process has been automated, so you no longer need to manually rotate the certificates. This improvement not only saves time and effort but also ensures that the security and functionality of the system are maintained without the risk of overlooking expired certificates. The automation of certificate rotation makes managing your AKS Hybrid cluster even more seamless and efficient. 

**Any way but if you need to execute Update-AksHciClusterCertificates  do not forget -patchLoadBalancer** Indeed, it might take some time to realize that something isn't working correctly, especially if the issue is related to expired certificates. You may only notice the problem when scaling your cluster or deploying a new LoadBalancer type service, as these operations require proper communication between components. If you deploy a service that receives an IP address from the VIP Pool and you still cannot access your application, it's possible that the issue is related to executing the Update-AksHciClusterCertificates command without the **patchLoadBalancer** parameter.

```bash
Update-AksHciClusterCertificates -Name holidays -fixCloudCredentials -patchLoadBalancer
```

When everything is functioning smoothly, there's usually no need to troubleshoot your environment. However, you might wonder how to determine if your cluster is partially functioning in terms of load balancers. To check this, connect to your active LoadBalancer VM using SSH, ensure that every daemon is working properly, and verify that every VIP address associated with the LoadBalancer VM is present in the haproxy.cfg file. If one of your VIPs or the latest one is missing, it's likely that you forgot to use the -patchLoadBalancer flag while updating your certificates in your target cluster.

```bash
root [ /etc/lbagent/pki ]# systemctl status lbagent
* lbagent.service - AzEdge lbagent service
     Loaded: loaded (/usr/lib/systemd/system/lbagent.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2023-04-19 15:33:06 UTC; 24h ago
   Main PID: 974 (lbagent)
      Tasks: 8 (limit: 6792)
     Memory: 35.7M
     CGroup: /system.slice/lbagent.service
             `-974 /usr/bin/lbagent

Apr 20 12:29:32 moc-l6g08md6vs4 lbagent[974]: [SPAN_END: 04-20 12:29:0000032 TraceID: 276590dc32184e17063935d312abacd5] Name: Received gRPC call for CheckHealth in healthAgentServer  Duration: 3600.00s
Apr 20 13:29:32 moc-l6g08md6vs4 lbagent[974]: [SPAN_START: 04-20 12:29:0000032 TraceID: cc80ffdc3e3f156f5dbac108cc5acb48] Name: Received gRPC call for CheckHealth in healthAgentServer  SpanID: 63663863363662633730373033373061  ParentSpanID: 30303030303030303030303030303030  Duration: 3600.00s
Apr 20 13:29:32 moc-l6g08md6vs4 lbagent[974]: [LOG: 04-20 12:29:0000032 TraceID: health.go:48  cc80ffdc3e3f156f5dbac108cc5acb48] [HealthAgent] [CheckHealth] - [timeoutSeconds:3600 ] []
Apr 20 13:29:32 moc-l6g08md6vs4 lbagent[974]: [SPAN_END: 04-20 13:29:0000032 TraceID: cc80ffdc3e3f156f5dbac108cc5acb48] Name: Received gRPC call for CheckHealth in healthAgentServer  Duration: 3600.00s
Apr 20 14:29:32 moc-l6g08md6vs4 lbagent[974]: [SPAN_START: 04-20 13:29:0000032 TraceID: c053345094b2081b879836aa77c5b870] Name: Received gRPC call for CheckHealth in healthAgentServer  SpanID: 38343838373433613332316533623638  ParentSpanID: 30303030303030303030303030303030  Duration: 3600.00s
Apr 20 14:29:32 moc-l6g08md6vs4 lbagent[974]: [LOG: 04-20 13:29:0000032 TraceID: health.go:48  c053345094b2081b879836aa77c5b870] [HealthAgent] [CheckHealth] - [timeoutSeconds:3600 ] []
Apr 20 14:29:32 moc-l6g08md6vs4 lbagent[974]: [SPAN_END: 04-20 14:29:0000032 TraceID: c053345094b2081b879836aa77c5b870] Name: Received gRPC call for CheckHealth in healthAgentServer  Duration: 3600.00s
Apr 20 15:29:32 moc-l6g08md6vs4 lbagent[974]: [SPAN_START: 04-20 14:29:0000032 TraceID: 990cd30b2956d802eef70a8e6db2791e] Name: Received gRPC call for CheckHealth in healthAgentServer  SpanID: 33393834383262386633636233656336  ParentSpanID: 30303030303030303030303030303030  Duration: 3600.00s
Apr 20 15:29:32 moc-l6g08md6vs4 lbagent[974]: [LOG: 04-20 14:29:0000032 TraceID: health.go:48  990cd30b2956d802eef70a8e6db2791e] [HealthAgent] [CheckHealth] - [timeoutSeconds:3600 ] []
Apr 20 15:29:32 moc-l6g08md6vs4 lbagent[974]: [SPAN_END: 04-20 15:29:0000032 TraceID: 990cd30b2956d802eef70a8e6db2791e] Name: Received gRPC call for CheckHealth in healthAgentServer  Duration: 3600.00s
root [ /etc/lbagent/pki ]# systemctl status haproxy
* haproxy.service - HAProxy Load Balancer
     Loaded: loaded (/usr/lib/systemd/system/haproxy.service; disabled; vendor preset: enabled)
     Active: active (running) since Wed 2023-04-19 15:33:22 UTC; 24h ago
    Process: 1010 ExecStartPre=/usr/sbin/haproxy -Ws -f $CONFIG -c -q $EXTRAOPTS (code=exited, status=0/SUCCESS)
    Process: 169283 ExecReload=/usr/sbin/haproxy -Ws -f $CONFIG -c -q $EXTRAOPTS (code=exited, status=0/SUCCESS)
    Process: 169285 ExecReload=/bin/kill -USR2 $MAINPID (code=exited, status=0/SUCCESS)
   Main PID: 1013 (haproxy)
      Tasks: 5 (limit: 6792)
     Memory: 17.8M
     CGroup: /system.slice/haproxy.service
             |-  1013 /usr/sbin/haproxy -sf 169274 -Ws -f /etc/haproxy/haproxy.cfg -p /var/run/haproxy.pid -S /var/run/haproxy-master.sock
             `-169287 /usr/sbin/haproxy -sf 169274 -Ws -f /etc/haproxy/haproxy.cfg -p /var/run/haproxy.pid -S /var/run/haproxy-master.sock

Apr 20 15:37:53 moc-l6g08md6vs4 haproxy[169287]: 192.168.0.3:21923 [20/Apr/2023:15:37:53.217] frontend_192.168.0.156_6443 backend_192.168.0.156_6443/tcp0 1/0/162 4909 -- 12/12/11/11/0 0/0
Apr 20 15:37:53 moc-l6g08md6vs4 haproxy[169287]: 192.168.0.3:18682 [20/Apr/2023:15:37:53.070] frontend_192.168.0.156_6443 backend_192.168.0.156_6443/tcp0 1/0/325 5190 -- 11/11/10/10/0 0/0
Apr 20 15:37:55 moc-l6g08md6vs4 haproxy[169287]: 192.168.0.3:26730 [20/Apr/2023:15:37:55.385] frontend_192.168.0.156_6443 backend_192.168.0.156_6443/tcp0 1/0/119 4822 -- 12/12/11/11/0 0/0
Apr 20 15:37:55 moc-l6g08md6vs4 haproxy[169287]: 192.168.0.3:55497 [20/Apr/2023:15:37:55.274] frontend_192.168.0.156_6443 backend_192.168.0.156_6443/tcp0 1/1/240 5309 -- 11/11/10/10/0 0/0
Apr 20 15:39:24 moc-l6g08md6vs4 haproxy[169287]: 192.168.0.3:42949 [20/Apr/2023:15:37:50.593] frontend_192.168.0.156_6443 backend_192.168.0.156_6443/tcp0 1/0/93539 120606 -- 10/10/9/9/0 0/0
Apr 20 15:44:01 moc-l6g08md6vs4 haproxy[169287]: 192.168.0.3:43624 [20/Apr/2023:15:44:00.934] frontend_192.168.0.156_6443 backend_192.168.0.156_6443/tcp0 1/0/829 4879 -- 12/12/11/11/0 0/0
Apr 20 15:44:01 moc-l6g08md6vs4 haproxy[169287]: 192.168.0.3:3424 [20/Apr/2023:15:44:00.717] frontend_192.168.0.156_6443 backend_192.168.0.156_6443/tcp0 1/0/1060 5242 -- 11/11/10/10/0 0/0
Apr 20 15:44:04 moc-l6g08md6vs4 haproxy[169287]: 192.168.0.3:48683 [20/Apr/2023:15:44:03.951] frontend_192.168.0.156_6443 backend_192.168.0.156_6443/tcp0 1/0/90 4844 -- 12/12/11/11/0 0/0
Apr 20 15:44:04 moc-l6g08md6vs4 haproxy[169287]: 192.168.0.3:43131 [20/Apr/2023:15:44:03.826] frontend_192.168.0.156_6443 backend_192.168.0.156_6443/tcp0 1/0/220 5226 -- 11/11/10/10/0 0/0
Apr 20 15:46:30 moc-l6g08md6vs4 haproxy[169287]: 192.168.0.3:5277 [20/Apr/2023:15:40:41.000] frontend_192.168.0.156_6443 backend_192.168.0.156_6443/tcp0 1/1/349241 8867405 -- 10/10/9/9/0 0/0
root [ /etc/lbagent/pki ]# systemctl status keepalived
* keepalived.service - LVS and VRRP High Availability Monitor
     Loaded: loaded (/usr/lib/systemd/system/keepalived.service; disabled; vendor preset: enabled)
     Active: active (running) since Thu 2023-04-20 15:26:38 UTC; 21min ago
    Process: 170981 ExecStart=/usr/sbin/keepalived $KEEPALIVED_OPTIONS (code=exited, status=0/SUCCESS)
   Main PID: 170982 (keepalived)
      Tasks: 2 (limit: 6792)
     Memory: 1.2M
     CGroup: /system.slice/keepalived.service
             |-170982 /usr/sbin/keepalived -D
             `-170983 /usr/sbin/keepalived -D

Apr 20 15:26:46 moc-l6g08md6vs4 Keepalived_vrrp[170983]: (VI_1) Sending/queueing gratuitous ARPs on eth0 for 192.168.0.157
Apr 20 15:26:46 moc-l6g08md6vs4 Keepalived_vrrp[170983]: Sending gratuitous ARP on eth0 for 192.168.0.157
Apr 20 15:26:46 moc-l6g08md6vs4 Keepalived_vrrp[170983]: Sending gratuitous ARP on eth0 for 192.168.0.156
Apr 20 15:26:46 moc-l6g08md6vs4 Keepalived_vrrp[170983]: Sending gratuitous ARP on eth0 for 192.168.0.157
Apr 20 15:26:46 moc-l6g08md6vs4 Keepalived_vrrp[170983]: Sending gratuitous ARP on eth0 for 192.168.0.156
Apr 20 15:26:46 moc-l6g08md6vs4 Keepalived_vrrp[170983]: Sending gratuitous ARP on eth0 for 192.168.0.157
Apr 20 15:26:46 moc-l6g08md6vs4 Keepalived_vrrp[170983]: Sending gratuitous ARP on eth0 for 192.168.0.156
Apr 20 15:26:46 moc-l6g08md6vs4 Keepalived_vrrp[170983]: Sending gratuitous ARP on eth0 for 192.168.0.157
Apr 20 15:26:46 moc-l6g08md6vs4 Keepalived_vrrp[170983]: Sending gratuitous ARP on eth0 for 192.168.0.156
Apr 20 15:26:46 moc-l6g08md6vs4 Keepalived_vrrp[170983]: Sending gratuitous ARP on eth0 for 192.168.0.157

root [ /etc/lbagent/pki ]# cat /etc/haproxy/haproxy.cfg
global
    log /dev/log local0 info
    stats socket /var/run/haproxy.sock mode 666 level admin
    stats timeout 2m

defaults
    timeout client 30s
    timeout connect 10s
    timeout server 30s
    timeout tunnel 24d
    timeout client-fin 30s
    log global
    option tcplog
    option log-separate-errors
    option log-health-checks
    maxconn 10000


frontend frontend_192.168.0.156_6443
    bind 192.168.0.156:6443
    mode tcp
    default_backend backend_192.168.0.156_6443

backend backend_192.168.0.156_6443
    mode tcp
    balance roundrobin
    server tcp0 192.168.0.18:6443 check

frontend frontend_192.168.0.157_80
    bind 192.168.0.157:80
    mode tcp
    default_backend backend_192.168.0.157_80

backend backend_192.168.0.157_80
    mode tcp
    balance roundrobin
    server tcp0 192.168.0.16:30942 check
    server tcp1 192.168.0.21:30942 check
    server tcp2 192.168.0.18:30942 check
```

To check the validity of your load balancer certificates located in the /etc/lbagent/pki directory.
```bash
root [ /etc/lbagent/pki ]# openssl x509 -enddate -noout -in cloudagent.crt
notAfter=Feb  5 21:19:44 2024 GMT
```

If everything is working fine do not forget to sniff your network :)

!!  Happy troubleshooting !!!

