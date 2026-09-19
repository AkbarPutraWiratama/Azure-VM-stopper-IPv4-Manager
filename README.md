# Azure VM Stopper & IPv4 Manager

**Azure CLI Bash toolkit for VM lifecycle automation and dynamic Public IPv4 provisioning, attachment, removal, and recreation to help reduce costs.**

This repository contains a small collection of Bash scripts designed for **Azure Cloud Shell**. The scripts can start and deallocate an Azure VM while automatically creating, attaching, detaching, and deleting a Standard Public IPv4 resource.

There are **six scripts in total**, split into two network exposure modes:

```text
Azure-VM-stopper-IPv4-Manager/
├── ssh-only/
│   ├── 01-azure-vm-barebones.sh
│   ├── 02-azure-vm-tigervnc.sh
│   └── 03-azure-vm-tigervnc-9router.sh
│
├── web-80-443/
│   ├── 01-azure-vm-barebones.sh
│   ├── 02-azure-vm-tigervnc.sh
│   └── 03-azure-vm-tigervnc-9router.sh
│
├── LICENSE
└── README.md
```

---

## Features

- Start an existing Azure Linux VM
- Deallocate the VM when it is not in use
- Create a Standard Public IPv4 resource automatically
- Attach the Public IPv4 resource to the VM NIC
- Detach the Public IPv4 resource during shutdown
- Delete the Public IPv4 resource after deallocation
- Recreate a new Public IPv4 resource on the next start
- Manage Azure NSG rules for SSH-only or web-ready deployments
- Optional TigerVNC service verification
- Optional 9Router service and health verification
- Keep TigerVNC port `5901` private
- Keep 9Router port `20128` private
- Support SSH tunneling for TigerVNC and 9Router
- Support Nginx/Caddy reverse proxy deployments on ports `80` and `443`

---

## Variants

### SSH-only

Only TCP port `22` is exposed publicly.

| Script | Azure VM | TigerVNC | 9Router | Public Ports |
|---|---:|---:|---:|---|
| `01-azure-vm-barebones.sh` | Yes | No | No | `22` |
| `02-azure-vm-tigervnc.sh` | Yes | Yes | No | `22` |
| `03-azure-vm-tigervnc-9router.sh` | Yes | Yes | Yes | `22` |

TigerVNC and 9Router are accessed through SSH tunnels.

Ports `5901` and `20128` are **not exposed publicly**.

### Web 80/443

TCP ports `22`, `80`, and `443` are exposed publicly.

| Script | Azure VM | TigerVNC | 9Router | Public Ports |
|---|---:|---:|---:|---|
| `01-azure-vm-barebones.sh` | Yes | No | No | `22`, `80`, `443` |
| `02-azure-vm-tigervnc.sh` | Yes | Yes | No | `22`, `80`, `443` |
| `03-azure-vm-tigervnc-9router.sh` | Yes | Yes | Yes | `22`, `80`, `443` |

Ports `5901` and `20128` remain private.

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

## Command Pattern

All six scripts support the same three actions:

```bash
./SCRIPT_NAME.sh start
./SCRIPT_NAME.sh status
./SCRIPT_NAME.sh stop
```

### `start`

The script will:

```text
Create Standard Public IPv4
        ↓
Attach Public IPv4 to the VM NIC
        ↓
Ensure required NSG rules exist
        ↓
Start the Azure VM
        ↓
Optionally verify TigerVNC / 9Router
```

### `status`

The script will show:

```text
VM power state
Public IPv4 information
Inbound NSG rules
TigerVNC status (when applicable)
9Router status (when applicable)
9Router health check (when applicable)
```

### `stop`

The script will:

```text
Deallocate the Azure VM
        ↓
Detach Public IPv4 from the NIC
        ↓
Delete the Public IPv4 resource
```

The VM operating system, managed disk, applications, and files remain intact.

Because the Public IPv4 resource is deleted when the VM is stopped, Azure may assign a different Public IPv4 address the next time the VM is started.

---

## Requirements

- Azure subscription
- Existing Azure Linux VM
- Azure CLI
- Bash
- Existing Network Interface
- Existing Network Security Group
- Existing Virtual Network and subnet

For TigerVNC variants, the VM should already have:

```text
tigervnc.service
```

For TigerVNC + 9Router variants, the VM should already have:

```text
tigervnc.service
9router.service
```

Enable them once inside the VM:

```bash
sudo systemctl enable tigervnc
sudo systemctl enable 9router
```

Check their status:

```bash
systemctl status tigervnc
systemctl status 9router
```

Check the 9Router health endpoint:

```bash
curl http://127.0.0.1:20128/api/health
```

Expected response:

```json
{"ok":true}
```

---

# Installation in Azure Cloud Shell

## 1. Open Azure Cloud Shell

Open the Azure Portal:

```text
https://portal.azure.com
```

Launch **Cloud Shell** and select:

```text
Bash
```

Check the active subscription:

```bash
az account show -o table
```

If necessary, select the correct subscription:

```bash
az account set --subscription "Azure for Students"
```

---

## 2. Clone the Repository

```bash
git clone https://github.com/AkbarPutraWiratama/Azure-VM-stopper-IPv4-Manager.git
```

Enter the repository:

```bash
cd Azure-VM-stopper-IPv4-Manager
```

---

## 3. Make All Scripts Executable

```bash
chmod +x ssh-only/*.sh
chmod +x web-80-443/*.sh
```

Verify:

```bash
ls -l ssh-only
ls -l web-80-443
```

Executable scripts should show permissions similar to:

```text
-rwxr-xr-x
```

---

## 4. Configure Azure Resource Names

Every script contains the same Azure configuration block near the top:

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

```bash
az network public-ip list -g YOUR_RESOURCE_GROUP -o table
```

---

# SSH-only Versions

Enter the directory:

```bash
cd ~/Azure-VM-stopper-IPv4-Manager/ssh-only
```

## 1. Barebones

This version manages only:

- Azure VM start/deallocate
- Standard Public IPv4 create/attach/detach/delete
- SSH NSG rule

### Start

```bash
./01-azure-vm-barebones.sh start
```

### Status

```bash
./01-azure-vm-barebones.sh status
```

### Stop

```bash
./01-azure-vm-barebones.sh stop
```

---

## 2. TigerVNC

This version adds TigerVNC service verification.

TigerVNC port `5901` remains private.

### Start

```bash
./02-azure-vm-tigervnc.sh start
```

### Status

```bash
./02-azure-vm-tigervnc.sh status
```

### Stop

```bash
./02-azure-vm-tigervnc.sh stop
```

The script prints an SSH tunnel similar to:

```bash
ssh -L 5901:127.0.0.1:5901 USER@PUBLIC_IP
```

Keep the SSH session running.

Connect TigerVNC Viewer to:

```text
127.0.0.1:5901
```

---

## 3. TigerVNC + 9Router

This version verifies both TigerVNC and 9Router.

Ports `5901` and `20128` remain private.

### Start

```bash
./03-azure-vm-tigervnc-9router.sh start
```

### Status

```bash
./03-azure-vm-tigervnc-9router.sh status
```

### Stop

```bash
./03-azure-vm-tigervnc-9router.sh stop
```

The script prints a combined SSH tunnel:

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

9Router Web UI:

```text
http://127.0.0.1:20128
```

OpenAI-compatible API endpoint:

```text
http://127.0.0.1:20128/v1
```

---

# Web 80/443 Versions

Enter the directory:

```bash
cd ~/Azure-VM-stopper-IPv4-Manager/web-80-443
```

## 1. Barebones

This version manages the Azure VM, Public IPv4 lifecycle, and NSG rules for:

```text
22
80
443
```

It does not manage TigerVNC or 9Router.

### Start

```bash
./01-azure-vm-barebones.sh start
```

### Status

```bash
./01-azure-vm-barebones.sh status
```

### Stop

```bash
./01-azure-vm-barebones.sh stop
```

---

## 2. TigerVNC

This version exposes:

```text
22
80
443
```

TigerVNC port `5901` remains private.

### Start

```bash
./02-azure-vm-tigervnc.sh start
```

### Status

```bash
./02-azure-vm-tigervnc.sh status
```

### Stop

```bash
./02-azure-vm-tigervnc.sh stop
```

Connect through an SSH tunnel:

```bash
ssh -L 5901:127.0.0.1:5901 USER@PUBLIC_IP
```

Then connect TigerVNC Viewer to:

```text
127.0.0.1:5901
```

---

## 3. TigerVNC + 9Router

This version exposes:

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

### Start

```bash
./03-azure-vm-tigervnc-9router.sh start
```

### Status

```bash
./03-azure-vm-tigervnc-9router.sh status
```

### Stop

```bash
./03-azure-vm-tigervnc-9router.sh stop
```

The recommended deployment is to publish 9Router through Nginx or Caddy while keeping port `20128` private.

TigerVNC still uses an SSH tunnel:

```bash
ssh -L 5901:127.0.0.1:5901 USER@PUBLIC_IP
```

If needed, 9Router can also be accessed directly through an SSH tunnel:

```bash
ssh -L 20128:127.0.0.1:20128 USER@PUBLIC_IP
```

---

# Nginx Example for 9Router

Install Nginx:

```bash
sudo apt update
sudo apt install -y nginx
```

Create a site configuration:

```bash
sudo nano /etc/nginx/sites-available/9router
```

Example:

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

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/9router /etc/nginx/sites-enabled/9router
```

Test the Nginx configuration:

```bash
sudo nginx -t
```

Reload Nginx:

```bash
sudo systemctl reload nginx
```

Set your DNS `A` record to the current Azure Public IPv4 address.

Example:

```text
Type: A
Name: router
Value: CURRENT_AZURE_PUBLIC_IP
```

---

# HTTPS with Certbot

Install Certbot:

```bash
sudo apt install -y certbot python3-certbot-nginx
```

Request and configure the certificate:

```bash
sudo certbot --nginx -d router.example.com
```

After successful configuration:

```text
https://router.example.com
```

can proxy requests to:

```text
127.0.0.1:20128
```

---

# NSG Rule Names

The scripts manage only the following NSG rule names:

```text
Managed-Allow-SSH
Managed-Allow-HTTP
Managed-Allow-HTTPS
```

They do not intentionally delete unrelated NSG rules.

The SSH-only variants remove only the managed HTTP/HTTPS rules listed above.

Inspect current NSG rules:

```bash
az network nsg rule list \
  -g YOUR_RESOURCE_GROUP \
  --nsg-name YOUR_NSG \
  -o table
```

---

# SSH Security

By default:

```bash
SSH_SOURCE="*"
```

allows SSH connections from any source.

For better security, replace it with your own public IPv4 address in CIDR notation:

```bash
SSH_SOURCE="203.0.113.10/32"
```

Do not expose TigerVNC port `5901` directly to the Internet.

Do not expose 9Router port `20128` directly when an SSH tunnel or reverse proxy is available.

Recommended public ports:

### SSH-only mode

```text
22
```

### Web mode

```text
22
80
443
```

---

# Public IPv4 Behavior

The scripts intentionally delete the Standard Public IPv4 resource when the VM is stopped.

Example:

```text
First start : 70.x.x.x
Stop        : Public IP deleted
Next start  : 20.x.x.x
```

Always use the Public IPv4 address printed by the script after starting the VM.

## Domain Users

If a domain points directly to the Azure Public IPv4 address, its DNS record can become outdated after the VM receives a new IP.

You must either:

- update the DNS record after every IP change,
- automate DNS updates using your DNS provider's API, or
- keep a fixed Azure Public IP resource instead of deleting it.

Keeping a Public IP resource allocated may continue to incur Azure charges.

---

# Azure Cloud Shell Persistence

Azure Cloud Shell can use persistent or ephemeral storage.

If your session uses ephemeral storage, local files can disappear after the Cloud Shell session ends.

Because this project is hosted on GitHub, it can be restored quickly:

```bash
git clone https://github.com/AkbarPutraWiratama/Azure-VM-stopper-IPv4-Manager.git
```

Then:

```bash
cd Azure-VM-stopper-IPv4-Manager
chmod +x ssh-only/*.sh
chmod +x web-80-443/*.sh
```

---

# Updating the Local Repository

If the repository was already cloned previously:

```bash
cd ~/Azure-VM-stopper-IPv4-Manager
git pull
```

Then make sure the scripts remain executable:

```bash
chmod +x ssh-only/*.sh
chmod +x web-80-443/*.sh
```

---

# Cost Notes

The `stop` action uses:

```bash
az vm deallocate
```

and then detaches and deletes the Standard Public IPv4 resource.

This can help avoid keeping VM compute allocation and a Public IPv4 resource active when they are not needed.

Other Azure resources can still generate charges, including:

- Managed disks
- Snapshots
- Bandwidth
- NAT Gateway
- Load Balancer
- Other paid Azure services

Always verify actual usage and charges in:

```text
Azure Portal
→ Cost Management
→ Cost Analysis
```

---

# Troubleshooting

## `chmod: cannot access 'ssh-only/*.sh'`

Make sure you are inside the cloned repository:

```bash
cd ~/Azure-VM-stopper-IPv4-Manager
```

Then run:

```bash
chmod +x ssh-only/*.sh
chmod +x web-80-443/*.sh
```

## Check Script Syntax

```bash
bash -n ssh-only/01-azure-vm-barebones.sh
bash -n ssh-only/02-azure-vm-tigervnc.sh
bash -n ssh-only/03-azure-vm-tigervnc-9router.sh

bash -n web-80-443/01-azure-vm-barebones.sh
bash -n web-80-443/02-azure-vm-tigervnc.sh
bash -n web-80-443/03-azure-vm-tigervnc-9router.sh
```

No output means the Bash syntax check passed.

## Check VM Status Directly

```bash
az vm get-instance-view \
  -g YOUR_RESOURCE_GROUP \
  -n YOUR_VM_NAME \
  --query "instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus" \
  -o tsv
```

## Check Public IPv4

```bash
az network public-ip list \
  -g YOUR_RESOURCE_GROUP \
  -o table
```

## Check TigerVNC

Inside the VM:

```bash
systemctl status tigervnc
```

## Check 9Router

Inside the VM:

```bash
systemctl status 9router
```

Health check:

```bash
curl http://127.0.0.1:20128/api/health
```

---

# Quick Reference

## SSH-only Barebones

```bash
cd ~/Azure-VM-stopper-IPv4-Manager/ssh-only

./01-azure-vm-barebones.sh start
./01-azure-vm-barebones.sh status
./01-azure-vm-barebones.sh stop
```

## SSH-only TigerVNC

```bash
cd ~/Azure-VM-stopper-IPv4-Manager/ssh-only

./02-azure-vm-tigervnc.sh start
./02-azure-vm-tigervnc.sh status
./02-azure-vm-tigervnc.sh stop
```

## SSH-only TigerVNC + 9Router

```bash
cd ~/Azure-VM-stopper-IPv4-Manager/ssh-only

./03-azure-vm-tigervnc-9router.sh start
./03-azure-vm-tigervnc-9router.sh status
./03-azure-vm-tigervnc-9router.sh stop
```

## Web Barebones

```bash
cd ~/Azure-VM-stopper-IPv4-Manager/web-80-443

./01-azure-vm-barebones.sh start
./01-azure-vm-barebones.sh status
./01-azure-vm-barebones.sh stop
```

## Web TigerVNC

```bash
cd ~/Azure-VM-stopper-IPv4-Manager/web-80-443

./02-azure-vm-tigervnc.sh start
./02-azure-vm-tigervnc.sh status
./02-azure-vm-tigervnc.sh stop
```

## Web TigerVNC + 9Router

```bash
cd ~/Azure-VM-stopper-IPv4-Manager/web-80-443

./03-azure-vm-tigervnc-9router.sh start
./03-azure-vm-tigervnc-9router.sh status
./03-azure-vm-tigervnc-9router.sh stop
```

---

# License

This project is licensed under the [MIT License](LICENSE).

Copyright © 2026 Akbar Putra Wiratama
