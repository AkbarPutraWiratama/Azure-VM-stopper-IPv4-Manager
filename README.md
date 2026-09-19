# Azure-VM-stopper-IPv4-Manager
Azure CLI Bash toolkit for VM lifecycle automation and dynamic Public IPv4 provisioning, attachment, removal, and recreation to help reduce costs.

A small collection of Bash scripts for Azure Cloud Shell.

There are **six scripts in total**, split into two network exposure modes:

```text
azure-vm-power-scripts/
├── ssh-only/
│   ├── 01-azure-vm-barebones.sh
│   ├── 02-azure-vm-tigervnc.sh
│   └── 03-azure-vm-tigervnc-9router.sh
│
└── web-80-443/
    ├── 01-azure-vm-barebones.sh
    ├── 02-azure-vm-tigervnc.sh
    └── 03-azure-vm-tigervnc-9router.sh
```

## Variants

### SSH-only

Only TCP port `22` is exposed publicly.

| Script | VM | TigerVNC | 9Router |
|---|---:|---:|---:|
| `01-azure-vm-barebones.sh` | Yes | No | No |
| `02-azure-vm-tigervnc.sh` | Yes | Yes | No |
| `03-azure-vm-tigervnc-9router.sh` | Yes | Yes | Yes |

TigerVNC and 9Router are accessed through SSH tunnels.

### Web 80/443

TCP ports `22`, `80`, and `443` are exposed publicly.

| Script | VM | TigerVNC | 9Router |
|---|---:|---:|---:|
| `01-azure-vm-barebones.sh` | Yes | No | No |
| `02-azure-vm-tigervnc.sh` | Yes | Yes | No |
| `03-azure-vm-tigervnc-9router.sh` | Yes | Yes | Yes |

Ports `5901` and `20128` are still not opened publicly.

For the 9Router web variant, the intended topology is:

```text
Internet
   |
   | 80 / 443
   v
Nginx / Caddy
   |
   v
127.0.0.1:20128
   |
   v
9Router
```

---

# What the scripts do

When starting:

```text
Create Standard Public IPv4
        ↓
Attach it to the VM NIC
        ↓
Ensure required NSG rules exist
        ↓
Start the Azure VM
        ↓
Optionally verify TigerVNC / 9Router
```

When stopping:

```text
Deallocate the Azure VM
        ↓
Detach Public IPv4 from the NIC
        ↓
Delete the Public IPv4 resource
```

Deleting the Public IP means the address can change the next time the VM is started.

The OS disk and VM data remain intact.

---

# Requirements

- Azure subscription
- Existing Azure Linux VM
- Azure CLI
- Bash
- Existing NIC
- Existing NSG
- Existing VNet/subnet

For the TigerVNC scripts:

```text
tigervnc.service
```

should exist inside the VM.

For the full TigerVNC + 9Router scripts:

```text
tigervnc.service
9router.service
```

should exist inside the VM.

Enable them once:

```bash
sudo systemctl enable tigervnc
sudo systemctl enable 9router
```

Check them:

```bash
systemctl status tigervnc
systemctl status 9router
```

9Router health check:

```bash
curl http://127.0.0.1:20128/api/health
```

Expected response:

```json
{"ok":true}
```

---

# Install in Azure Cloud Shell

## 1. Open Azure Cloud Shell

Open the Azure Portal:

```text
https://portal.azure.com
```

Click **Cloud Shell** and select:

```text
Bash
```

Check the active subscription:

```bash
az account show -o table
```

If necessary:

```bash
az account set --subscription "Azure for Students"
```

---

## 2. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
```

Enter the repository:

```bash
cd YOUR_REPOSITORY
```

Make all scripts executable:

```bash
chmod +x ssh-only/*.sh
chmod +x web-80-443/*.sh
```

---

# Configuration

Every script has the same Azure configuration block near the top:

```bash
RG="SERVER"
VM="Server-ID"
NIC="Server-ID-nic"
NSG="Server-ID-nsg"
PIP="Server-ID-pip"

LOCATION="indonesiacentral"
ZONE="1"

SSH_USER="Akbar"
```

Change these values to match your Azure environment.

Useful Azure CLI commands:

```bash
az vm list -o table
```

```bash
az network nic list -g YOUR_RESOURCE_GROUP -o table
```

```bash
az network nsg list -g YOUR_RESOURCE_GROUP -o table
```

```bash
az network vnet list -g YOUR_RESOURCE_GROUP -o table
```

---

# SSH-only versions

## 1. Barebones

```bash
cd ssh-only
./01-azure-vm-barebones.sh start
```

Status:

```bash
./01-azure-vm-barebones.sh status
```

Stop:

```bash
./01-azure-vm-barebones.sh stop
```

This version only manages the Azure VM, Public IP, and SSH NSG rule.

## 2. TigerVNC

```bash
./02-azure-vm-tigervnc.sh start
```

The script prints a tunnel similar to:

```bash
ssh -L 5901:127.0.0.1:5901 USER@PUBLIC_IP
```

Then connect TigerVNC Viewer to:

```text
127.0.0.1:5901
```

## 3. TigerVNC + 9Router

```bash
./03-azure-vm-tigervnc-9router.sh start
```

Combined tunnel:

```bash
ssh \
  -L 5901:127.0.0.1:5901 \
  -L 20128:127.0.0.1:20128 \
  USER@PUBLIC_IP
```

TigerVNC:

```text
127.0.0.1:5901
```

9Router:

```text
http://127.0.0.1:20128
```

OpenAI-compatible API:

```text
http://127.0.0.1:20128/v1
```

---

# Web 80/443 versions

Enter:

```bash
cd web-80-443
```

## 1. Barebones

```bash
./01-azure-vm-barebones.sh start
```

The script ensures the following inbound NSG ports:

```text
22
80
443
```

It does not manage TigerVNC or 9Router.

## 2. TigerVNC

```bash
./02-azure-vm-tigervnc.sh start
```

Public ports:

```text
22
80
443
```

TigerVNC remains private and is accessed through SSH:

```bash
ssh -L 5901:127.0.0.1:5901 USER@PUBLIC_IP
```

## 3. TigerVNC + 9Router

```bash
./03-azure-vm-tigervnc-9router.sh start
```

Public ports:

```text
22
80
443
```

Private ports:

```text
5901
20128
```

The recommended 9Router deployment is through Nginx or Caddy.

---

# Nginx example for 9Router

Install Nginx inside the VM:

```bash
sudo apt update
sudo apt install -y nginx
```

Create:

```bash
sudo nano /etc/nginx/sites-available/9router
```

Example configuration:

```nginx
server {
    listen 80;
    server_name router.example.com;

    location / {
        proxy_pass http://127.0.0.1:20128;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable it:

```bash
sudo ln -s /etc/nginx/sites-available/9router /etc/nginx/sites-enabled/9router
sudo nginx -t
sudo systemctl reload nginx
```

Set your DNS `A` record to the current Azure Public IP.

Example:

```text
Type: A
Name: router
Value: CURRENT_AZURE_PUBLIC_IP
```

---

# HTTPS with Certbot

Install:

```bash
sudo apt install -y certbot python3-certbot-nginx
```

Then:

```bash
sudo certbot --nginx -d router.example.com
```

After successful setup:

```text
https://router.example.com
```

can proxy to:

```text
127.0.0.1:20128
```

---

# NSG rule names

The scripts only manage rules named:

```text
Managed-Allow-SSH
Managed-Allow-HTTP
Managed-Allow-HTTPS
```

They do not intentionally delete unrelated NSG rules.

The SSH-only variants remove only the managed HTTP/HTTPS rules above.

Inspect current NSG rules with:

```bash
az network nsg rule list \
  -g YOUR_RESOURCE_GROUP \
  --nsg-name YOUR_NSG \
  -o table
```

---

# SSH security

By default:

```bash
SSH_SOURCE="*"
```

allows SSH from any source.

For better security, replace it with your own public IP:

```bash
SSH_SOURCE="203.0.113.10/32"
```

---

# Public IP behavior

The scripts delete the Standard Public IPv4 resource when stopping.

Therefore the next start may return a different IP.

Example:

```text
First start : 70.x.x.x
Stop        : Public IP deleted
Next start  : 20.x.x.x
```

If you use a domain, update the DNS record when the IP changes or automate DNS updates.

If you require a fixed address, do not delete the Public IP resource, but keeping it can continue to incur Azure Public IP charges.

---

# Azure Cloud Shell persistence

Cloud Shell can use persistent or ephemeral storage.

If your Cloud Shell is ephemeral, files may disappear after the session ends.

Keeping the scripts in GitHub makes recovery easy:

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
```

---

# Cost notes

`stop` uses:

```bash
az vm deallocate
```

and then removes the Public IPv4 resource.

Other Azure resources can still generate charges, including:

- Managed disks
- Snapshots
- Bandwidth
- NAT Gateway
- Load Balancer
- Other paid services

Check actual usage in:

```text
Azure Portal
→ Cost Management
→ Cost Analysis
```

---

# License

MIT
