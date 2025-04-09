# WireGuard Verification Guide on Managed Cilium on AKS

This guide outlines how to verify that WireGuard is properly enabled and functioning on an AKS-managed Cilium cluster.

---

## ✅ Items to Verify

### 1. Provision Managed Cilium Cluster

Using the Azure Portal, create a Cilium-enabled AKS cluster with **two nodes**.  
Ensure you check the **"Enable Cilium dataplane and network policy"** box on the **Networking** page.  
You can stick with the default settings for most other options.

> ✅ The Cilium WireGuard feature should work on **all AKS versions**.

---

Ensure kubectl works on your machine after the cluster is finishing provisioning. 

```bash

az login

az account set --subscription {SUBSCRIPTION ID GOES HERE}

az aks get-credentials --resource-group {RG NAME GOES HERE} --name {CLUSTER NAME GOES HERE} --overwrite-existing

kubectl get pods -n kube-system -l k8s-app=cilium

```

> ✅ You should see some Cilium pods running

```
NAME           READY   STATUS    RESTARTS   AGE
cilium-47csf   1/1     Running   0          6h32m
cilium-jkjh8   1/1     Running   0          6h32m
```

### 2. Enable WireGuard

- Confirm that you can enable the WireGuard feature using the provided script.

First, run the following:

```bash
az feature register --name AdvancedNetworkingWireGuardPreview --namespace Microsoft.ContainerService
```

#### Linux

Edit the following variables in the script:

```bash
ACCESS_TOKEN=$(az account get-access-token --query accessToken -o tsv) # No need to edit this
SUBSCRIPTION_ID="SUB ID GOES HERE"         # <YOU NEED TO EDIT THIS!!!!!!>
RESOURCE_GROUP="RG NAME GOES HERE"         # <YOU NEED TO EDIT THIS!!!!!!>
CLUSTER_NAME="CLUSTER NAME GOES HERE"      # <YOU NEED TO EDIT THIS!!!!!!>
API_VERSION="2025-02-02-preview"           # No need to edit this
LOCATION="LOCATION CODE GOES HERE"         # <YOU NEED TO EDIT THIS!!!!!!> 
```

#### Windows

```powershell
$accessToken = (az account get-access-token --query accessToken -o tsv) # No need to edit this
$subscriptionId = "SUB ID GOES HERE"        # <YOU NEED TO EDIT THIS!!!!!!>
$resourceGroup = "RG NAME GOES HERE"        # <YOU NEED TO EDIT THIS!!!!!!>
$clusterName = "CLUSTER NAME GOES HERE"     # <YOU NEED TO EDIT THIS!!!!!!>
$apiVersion = "2025-02-02-preview"          # No need to edit this
$location = "LOCATION CODE GOES HERE"       # <YOU NEED TO EDIT THIS!!!!!!>
```

Run the appropriate script:

- **Windows**:

  ```powershell
  ./enable-wireguard.ps1
  ```

- **Linux**:

  ```bash
  chmod +x ./enable-wireguard.sh
  ./enable-wireguard.sh
  ```

> ✅ The operation should complete **without any errors**.

---

### 3. Verify WireGuard Interface on Node

1. Open a shell on one of your AKS nodes:

   ```bash
   kubectl node-shell -x <node-name>
   ```

2. Enter the host filesystem:

   ```bash
   chroot /host/
   ```

3. Check for the `cilium_wg0` interface:

   ```bash
   ip l show cilium_wg0
   ```

Expected output:

```
4: cilium_wg0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/none
```

---

### 4. Install `tshark` for Packet Inspection

While in the node shell, run:

```bash
echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt update && apt-get install -y tshark

tshark -i eth0 -f "udp port 51871"
```

Expected output:

```
Running as user "root" and group "root". This could be dangerous.
    Capturing on 'eth0'
    ** (tshark:11747) 17:31:52.445266 [Main MESSAGE] -- Capture started.
    ** (tshark:11747) 17:31:52.445364 [Main MESSAGE] -- File: "/tmp/wireshark_eth0834H42.pcapng"
    1 0.000000000   10.224.0.5 ? 10.224.0.6   WireGuard 74 Keepalive, receiver=0xA61B38C9, counter=249
    2 1.024052601   10.224.0.5 ? 10.224.0.6   WireGuard 138 Transport Data, receiver=0xA61B38C9, counter=250, datalen=64
    3 1.024234509   10.224.0.6 ? 10.224.0.5   WireGuard 138 Transport Data, receiver=0xAC2716C5, counter=239, datalen=64
    4 1.024410455   10.224.0.6 ? 10.224.0.5   WireGuard 190 Handshake Initiation, sender=0xDEEE9493
    5 1.025171038   10.224.0.5 ? 10.224.0.6   WireGuard 134 Handshake Response, sender=0xCC5ECE6A, receiver=0xDEEE9493
```

---

### 5. Install WireGuard Tools and Inspect Connection

Still in the shell:

```bash
apt install wireguard -y
```

Then:

```bash
wg show
```

Example output:

```
interface: cilium_wg0
  public key: <key>
  private key: (hidden)
  listening port: 51871
  fwmark: 0x1e00

peer: <peer-key>
  endpoint: 10.224.0.4:51871
  allowed ips: 10.224.0.4/32, ...
  latest handshake: 1 minute, 45 seconds ago
  transfer: 964.27 KiB received, 11.96 MiB sent
```

You can exit the shell for now. Typing exit and hitting enter should suffice. 

---

### 6. Verify Pod Connectivity

Apply test pods:

```bash
kubectl apply -f ./pod.yaml
```

Check pod placement:

```bash
kubectl get pods -o wide -l wg=true
```

> If both pods are on the same node, delete one and allow it to reschedule.

Then test east-west connectivity:

```bash
kubectl exec -it busybox -- curl nginx
```

> You should see HTML output and **no errors**.

Now test north-south connectivity:

```bash
kubectl exec -it busybox -- curl example.com
```

> Again, expect HTML output and no errors.

---

### 7. My traffic is being redirected to the WireGuard interface right??

Open up two terminals.

Terminal #1

1. Get the pod IP address and node for the busybox pod

  ```bash
  kubectl get pod busybox -o wide
  ```

  Example:

  ```bash
  NAME      READY   STATUS    RESTARTS       AGE   IP             NODE                                NOMINATED NODE   READINESS GATES
  busybox   1/1     Running   1 (38m ago)   28h   10.244.0.162   aks-agentpool-24001599-vmss000001   <none>           <none>
  ```

2. Open a shell running the busybox pod:

  ```bash
  kubectl node-shell -x <node-name>
  ```

3. Enter the host filesystem:

  ```bash
  chroot /host/
  ```

4. install tshark (again sorry)

```bash
echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt update && apt-get install -y tshark

tshark -i cilium_wg0 -f "host {busybox pod ip address goes here. You don't need the {} }"

#example: tshark -i cilium_wg0 -f "host 10.244.0.162"
```


Terminal #2

```bash
kubectl exec -it busybox -- curl nginx
```


In Terminal #1 you should see clear text HTTP traffic. 

Example:

```
root@aks-agentpool-24001599-vmss000001:/# tshark -i cilium_wg0 -f "host 10.244.0.162"
Running as user "root" and group "root". This could be dangerous.
Capturing on 'cilium_wg0'
 ** (tshark:1955714) 20:08:44.720454 [Main MESSAGE] -- Capture started.
 ** (tshark:1955714) 20:08:44.720563 [Main MESSAGE] -- File: "/tmp/wireshark_cilium_wg0PWKL42.pcapng"
    1 0.000000000 10.244.0.162 ? 10.244.1.119 TCP 60 57834 ? 80 [SYN] Seq=0 Win=64860 Len=0 MSS=1380 SACK_PERM=1 TSval=1653976557 TSecr=0 WS=128
    2 0.001154474 10.244.1.119 ? 10.244.0.162 TCP 60 80 ? 57834 [SYN, ACK] Seq=0 Ack=1 Win=64296 Len=0 MSS=1380 SACK_PERM=1 TSval=3718507938 TSecr=1653976557 WS=128
    3 0.001232339 10.244.0.162 ? 10.244.1.119 TCP 52 57834 ? 80 [ACK] Seq=1 Ack=1 Win=64896 Len=0 TSval=1653976558 TSecr=3718507938
    4 0.001301413 10.244.0.162 ? 10.244.1.119 HTTP 121 GET / HTTP/1.1 
    5 0.001559004 10.244.1.119 ? 10.244.0.162 TCP 52 80 ? 57834 [ACK] Seq=1 Ack=70 Win=64256 Len=0 TSval=3718507939 TSecr=1653976558
    6 0.002021264 10.244.1.119 ? 10.244.0.162 TCP 290 HTTP/1.1 200 OK  [TCP segment of a reassembled PDU]
    7 0.002067661 10.244.0.162 ? 10.244.1.119 TCP 52 57834 ? 80 [ACK] Seq=70 Ack=239 Win=64768 Len=0 TSval=1653976559 TSecr=3718507939
    8 0.002125256 10.244.1.119 ? 10.244.0.162 HTTP 667 HTTP/1.1 200 OK  (text/html)
```

### 8. Its getting encrypted right??

For this step you will do exactly what you did in step 7. You will have two terminals. Instead we are going to use this tshark filter.

```
tshark -i eth0 -f "udp port 51871"

#example: tshark -i eth0 -f "udp port 51871"
```

Example Output: 

```
root@aks-agentpool-24001599-vmss000001:/# tshark -i eth0 -f "udp port 51871"
Running as user "root" and group "root". This could be dangerous.
Capturing on 'eth0'
 ** (tshark:2056545) 21:32:34.704431 [Main MESSAGE] -- Capture started.
 ** (tshark:2056545) 21:32:34.704547 [Main MESSAGE] -- File: "/tmp/wireshark_eth08X4K42.pcapng"
    1 0.000000000   10.224.0.5 ? 10.224.0.4   WireGuard 190 Handshake Initiation, sender=0x32A681B1
    2 0.000368343   10.224.0.4 ? 10.224.0.5   WireGuard 134 Handshake Response, sender=0xDD778759, receiver=0x32A681B1
    3 0.000550582   10.224.0.5 ? 10.224.0.4   WireGuard 138 Transport Data, receiver=0xDD778759, counter=0, datalen=64
    4 0.000906684   10.224.0.4 ? 10.224.0.5   WireGuard 138 Transport Data, receiver=0x32A681B1, counter=0, datalen=64
    5 0.001004036   10.224.0.5 ? 10.224.0.4   WireGuard 138 Transport Data, receiver=0xDD778759, counter=1, datalen=64
    6 0.001154816   10.224.0.5 ? 10.224.0.4   WireGuard 202 Transport Data, receiver=0xDD778759, counter=2, datalen=128
    7 0.001570730   10.224.0.4 ? 10.224.0.5   WireGuard 138 Transport Data, receiver=0x32A681B1, counter=1, datalen=64
    8 0.001724666   10.224.0.4 ? 10.224.0.5   WireGuard 378 Transport Data, receiver=0x32A681B1, counter=2, datalen=304
    9 0.001797493   10.224.0.4 ? 10.224.0.5   WireGuard 746 Transport Data, receiver=0x32A681B1, counter=3, datalen=672
   10 0.001826237   10.224.0.5 ? 10.224.0.4   WireGuard 138 Transport Data, receiver=0xDD778759, counter=3, datalen=64
   11 0.001906516   10.224.0.5 ? 10.224.0.4   WireGuard 138 Transport Data, receiver=0xDD778759, counter=4, datalen=64
   12 0.002102731   10.224.0.5 ? 10.224.0.4   WireGuard 138 Transport Data, receiver=0xDD778759, counter=5, datalen=64
   13 0.002403080   10.224.0.4 ? 10.224.0.5   WireGuard 138 Transport Data, receiver=0x32A681B1, counter=4, datalen=64
   14 0.002533613   10.224.0.5 ? 10.224.0.4   WireGuard 138 Transport Data, receiver=0xDD778759, counter=6, datalen=64
```

You should not see the Pod IP of Busybox or nginx here, only the Src and Dst Node IP addresses. 

### 9. Node Reboot

1. Open a shell on one of your AKS nodes:

   ```bash
   kubectl node-shell -x <node-name>
   ```

2. Enter the host filesystem:

   ```bash
   chroot /host/
   ```

3. Reboot the node:

   ```bash
    reboot
   ```

   Running this command may require you to exit the terminal. 

   Note: the reboot could take 5-8 minutes. You can run the following to check when the node has recovered.

   ```bash
    kubectl get nodes
   ```

   Expected Output:

   ```
    NAME                                STATUS   ROLES    AGE   VERSION
    aks-agentpool-24001599-vmss000000   Ready    <none>   8h    v1.31.6
    aks-agentpool-24001599-vmss000001   Ready    <none>   8h    v1.31.6
   ```

   Note: All the nodes should report 'Ready'

4. Rinse and Repeat
   
   Please repeat steps 3, 4, 5, and 6

### 10. Set `cilium_wg0` down

1. Open a shell on the node running the busybox pod:

```bash
kubectl node-shell -x <node-name>
```

2. Enter the host filesystem:

```bash
chroot /host/
```

3. Set cilium_wg0 down

```bash
ip link set cilium_wg0 down
```

4. In another terminal run

```bash
kubectl exec -it busybox -- curl nginx
```

This should fail/hang. This indicates that traffic is not leaving the node unencrypted.

You can tshark to verify as well. 

```bash
tshark -i eth0 -f "host {insert the pod ip of busybox here}"
```

5. Set cilium_wg0 back to up using steps 1, 2 and 3. 

```bash
ip link set cilium_wg0 up
```

### 11. Time to block traffic!

1. Open a shell on the node running the busybox pod:

```bash
kubectl node-shell -x <node-name>
```

2. Enter the host filesystem:

```bash
chroot /host/
```

3. Lets insert an IPtables rule to block the traffic. 

```bash
iptables -A INPUT -p udp --dport 51871 -j DROP
iptables -A OUTPUT -p udp --dport 51871 -j DROP
```

4. In another terminal. Repeat steps 1, 2 and 3. 

Lets install wireguard again (unless you have been using the same terminal. Good on you)

```bash
apt install wireguard -y
```

5. Verify Handshake is failing

```bash
wg show

peer: p9COKMvb/aOEdGNnZO+zYVPZQmo4U0rIKNgs8XpWJDY=
  endpoint: 10.224.0.5:51871
  allowed ips: 10.244.0.160/32, 10.244.0.162/32, 10.244.0.31/32, 10.244.0.153/32, 10.224.0.5/32, 10.244.0.240/32, 10.244.0.36/32, 10.244.0.222/32, 10.244.0.229/32, 10.244.0.10/32, 10.244.0.253/32, 10.244.0.45/32
  latest handshake: 2 minutes, 42 seconds ago
  transfer: 693.15 MiB received, 40.50 MiB sent
```

The handshake occurs every 120 seconds. Anything greater will indicate a problem. If the field is missing, that means its failing. 

You can tshark on eth0 to verify you don't see any busybox/nginx traffic leaving. 

```bash
tshark -i eth0 -f "host {busybox pod ip}"
```

You will see this output when sniffing for the WireGuard control plane traffic:

```
root@aks-agentpool-24001599-vmss000000:/# tshark -i eth0 -f "udp port 51871"
Running as user "root" and group "root". This could be dangerous.
Capturing on 'eth0'
 ** (tshark:3374843) 15:02:01.144857 [Main MESSAGE] -- Capture started.
 ** (tshark:3374843) 15:02:01.144953 [Main MESSAGE] -- File: "/tmp/wireshark_eth0KO6W42.pcapng"
    1 0.000000000   10.224.0.5 ? 10.224.0.4   WireGuard 190 Handshake Initiation, sender=0x345F3AD6
    2 5.120071112   10.224.0.5 ? 10.224.0.4   WireGuard 190 Handshake Initiation, sender=0x002C2FAA
    3 10.495972681   10.224.0.5 ? 10.224.0.4   WireGuard 190 Handshake Initiation, sender=0xE6CC272B
    4 15.615933197   10.224.0.5 ? 10.224.0.4   WireGuard 190 Handshake Initiation, sender=0xC031A172
    5 20.736050189   10.224.0.5 ? 10.224.0.4   WireGuard 190 Handshake Initiation, sender=0x01064ACB
```

6. Delete the IPtables rules (Make sure you do this. I forgot and it confused me for a bit.)

```bash
iptables -D INPUT -p udp --dport 51871 -j DROP
iptables -D OUTPUT -p udp --dport 51871 -j DROP
```

## 📦 How to Install `node-shell`

- **Install `kubectl-node-shell`**:  
  [https://github.com/kvaps/kubectl-node-shell](https://github.com/kvaps/kubectl-node-shell)

---

## 📦 How to Install `kubectl`

Refer to the official Kubernetes documentation based on your platform:

- 🐧 **Linux**: [Install kubectl on Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- 🪟 **Windows**: [Install kubectl on Windows](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)
- 🍎 **macOS**: [Install kubectl on macOS](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)

> `kubectl` is required to interact with your AKS cluster from your local machine.

## Helpful Links

- [Cilium WireGuard Documentation](https://docs.cilium.io/en/latest/security/network/encryption-wireguard/)
- [WireGuard](https://www.wireguard.com)
- [WireGuard GitHub](https://github.com/wireguard)

## 📝 Notes

- The WireGuard interface is named `cilium_wg0`.
- `tshark` and `wireguard` are useful for advanced diagnostics but **not required** for normal Cilium operation.
