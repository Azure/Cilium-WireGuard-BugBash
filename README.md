# WireGuard Verification Guide on Managed Cilium on AKS

This guide outlines how to verify that WireGuard is properly enabled and functioning on an AKS-managed Cilium cluster.

---

## ✅ Items to Verify

### 1. Provision Managed Cilium Cluster

Using the Azure Portal, create a Cilium-enabled AKS cluster with a minimum of **two nodes** (three max is sufficient).  
Ensure you check the **"Enable Cilium dataplane and network policy"** box on the **Networking** page.  
You can stick with the default settings for most other options.

> ✅ The Cilium WireGuard feature should work on **all AKS versions**.

---

### 2. Enable WireGuard

- Confirm that you can enable the WireGuard feature using the provided script.

First, run the following:

```bash
az login
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
DEBIAN_FRONTEND=noninteractive apt-get install -y tshark
```

Expected output:

```
Running as user "root" and group "root". This could be dangerous.
Capturing on 'eth0'
** (tshark:11747) ... -- Capture started.
** (tshark:11747) ... -- File: "/tmp/wireshark_eth0834H42.pcapng"
1  0.000000000   10.224.0.5 → 10.224.0.6   WireGuard 74 Keepalive...
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

## 🧰 Additional Resources

- **Install `kubectl-node-shell`**:  
  [https://github.com/kvaps/kubectl-node-shell](https://github.com/kvaps/kubectl-node-shell)

---

## 📝 Notes

- The WireGuard interface is named `cilium_wg0`.
- `tshark` and `wireguard` are useful for advanced diagnostics but **not required** for normal Cilium operation.
