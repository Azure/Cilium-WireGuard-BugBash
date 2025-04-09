# WireGuard Verification Guide on managed Cilium on AKS

This guide outlines how to verify that WireGuard is properly enabled and functioning on an AKS-managed Cilium cluster.

---

## ✅ Items to Verify

### 1. Provision Managed Cilium Cluster

Using the Azure Portal, create a Cilium-enabled AKS cluster with a minimum of **two nodes** (three max is sufficient).  
Ensure you check the **"Enable Cilium dataplane and network policy"** box on the **Networking** page.  
You can stick with the default settings for most other options.

The Cilium WireGuard feature should work on ALL AKS versions!

---

### 2. Enable WireGuard

- Confirm that you can enable the WireGuard feature using the provided script.

First run:
```
az login
az feature register --name AdvancedNetworkingWireGuardPreview --namespace Microsoft.ContainerService
```

Depending on your operating system, you'll need to edit a few variables in the script:

Linux:
```bash
ACCESS_TOKEN=$(az account get-access-token --query accessToken -o tsv) # No need to edit this
SUBSCRIPTION_ID="SUB ID DOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>
RESOURCE_GROUP="RG NAME GOES HERE" # <YOU NEED TO EDIT THIS!!!!!!> 
CLUSTER_NAME="CLUSTER NAME GOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>
API_VERSION="2025-02-02-preview" # No need to edit this
LOCATION="LOCATION CODE GOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>
```

Windows:
```powershell
$accessToken = (az account get-access-token --query accessToken -o tsv) # No need to edit this
$subscriptionId = "9b8218f9-902a-4d20-a65c-e98acec5362f" # <YOU NEED TO EDIT THIS!!!!!!>
$resourceGroup = "RG NAME GOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>
$clusterName = "CLUSTER NAME GOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>
$apiVersion = "2025-02-02-preview" # No need to edit this
$location = "LOCATION CODE GOES HERE" # <YOU NEED TO EDIT THIS!!!!!!>
```

Run the appropriate script for your OS:

- **Windows**:

  ```powershell
  ./enable-wireguard.ps1
  ```

- **Linux**:

  ```bash
  chmod +x ./enable-wireguard.sh
  ./enable-wireguard.sh
  ```

> The operation should complete **without any errors**.

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

  ```
  4: cilium_wg0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
      link/none
  ```

You should see an output showing the WireGuard interface created by the Cilium agent.

---

### 4. Install `tshark` for Packet Inspection

While still in the node-shell, run the following to install `tshark` **without prompts**:

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
1  0.000000000   10.224.0.5 → 10.224.0.6   WireGuard 74 Keepalive, receiver=0xA61B38C9, counter=249
2  1.024052601   10.224.0.5 → 10.224.0.6   WireGuard 138 Transport Data, ...
...
```

---

### 5. Install WireGuard Tools and Inspect Connection

Still in the shell:

```bash
apt install wireguard -y
```

run this command:

```bash
wg show
```
```
root@aks-agentpool-24001599-vmss000001:/# wg show
interface: cilium_wg0
  public key: p9COKMvb/aOEdGNnZO+zYVPZQmo4U0rIKNgs8XpWJDY=
  private key: (hidden)
  listening port: 51871
  fwmark: 0x1e00

peer: mT1z1d4UVX8qYwAtRz4ddiBZ5AqiqBuC2DmD3LhgrVg=
  endpoint: 10.224.0.4:51871
  allowed ips: 10.224.0.4/32, 10.244.1.203/32, 10.244.1.155/32, 10.244.1.248/32, 10.244.1.47/32, 10.244.1.89/32, 10.244.1.208/32, 10.244.1.90/32, 10.244.1.177/32, 10.244.1.95/32, 10.244.1.25/32, 10.244.1.2/32, 10.244.1.206/32
  latest handshake: 1 minute, 45 seconds ago
  transfer: 964.27 KiB received, 11.96 MiB sent

  ```

You should see active peers and handshake data.

---

## 🧰 Additional Resources

- **Install `kubectl-node-shell`**:  
  [https://github.com/kvaps/kubectl-node-shell](https://github.com/kvaps/kubectl-node-shell)

---

## 📝 Notes

- The WireGuard interface is named `cilium_wg0`.
- `tshark` and `wireguard` are helpful for deeper diagnostics but are **not required** for standard Cilium operation.
