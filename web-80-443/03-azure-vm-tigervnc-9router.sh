#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Azure VM + TigerVNC + 9Router - Web 80/443
# ============================================================
# Public inbound ports managed by this script: 22, 80, 443
#
# TigerVNC port 5901 is NOT exposed publicly.
# 9Router port 20128 is NOT exposed publicly.
# ============================================================

RG="SERVER"
VM="Server-ID"
NIC="Server-ID-nic"
NSG="Server-ID-nsg"
PIP="Server-ID-pip"

LOCATION="indonesiacentral"
ZONE="1"

SSH_USER="Akbar"

RULE_SSH="Managed-Allow-SSH"
RULE_HTTP="Managed-Allow-HTTP"
RULE_HTTPS="Managed-Allow-HTTPS"

SSH_PRIORITY="1000"
HTTP_PRIORITY="1010"
HTTPS_PRIORITY="1020"

# For better security, replace "*" with your public IP/CIDR.
# Example: SSH_SOURCE="203.0.113.10/32"
SSH_SOURCE="*"


VNC_SERVICE="tigervnc"
VNC_PORT="5901"

ROUTER_SERVICE="9router"
ROUTER_PORT="20128"

get_ipconfig() {
    az network nic ip-config list \
        --resource-group "$RG" \
        --nic-name "$NIC" \
        --query "[0].name" \
        --output tsv
}

get_power_state() {
    az vm get-instance-view \
        --resource-group "$RG" \
        --name "$VM" \
        --query "instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus" \
        --output tsv
}

public_ip_exists() {
    az network public-ip show \
        --resource-group "$RG" \
        --name "$PIP" \
        >/dev/null 2>&1
}

get_public_ip() {
    az network public-ip show \
        --resource-group "$RG" \
        --name "$PIP" \
        --query ipAddress \
        --output tsv
}

nsg_rule_exists() {
    local rule_name="$1"
    az network nsg rule show \
        --resource-group "$RG" \
        --nsg-name "$NSG" \
        --name "$rule_name" \
        >/dev/null 2>&1
}

ensure_rule() {
    local name="$1"
    local priority="$2"
    local port="$3"
    local source="$4"

    az network nsg rule create \
        --resource-group "$RG" \
        --nsg-name "$NSG" \
        --name "$name" \
        --priority "$priority" \
        --direction Inbound \
        --access Allow \
        --protocol Tcp \
        --source-address-prefixes "$source" \
        --source-port-ranges "*" \
        --destination-address-prefixes "*" \
        --destination-port-ranges "$port" \
        --output none
}

remove_managed_rule() {
    local rule_name="$1"

    if nsg_rule_exists "$rule_name"; then
        az network nsg rule delete \
            --resource-group "$RG" \
            --nsg-name "$NSG" \
            --name "$rule_name"
    fi
}

create_public_ip() {
    if public_ip_exists; then
        echo "Public IP resource already exists."
        return
    fi

    echo "Creating Standard Public IPv4 address..."

    az network public-ip create \
        --resource-group "$RG" \
        --name "$PIP" \
        --location "$LOCATION" \
        --sku Standard \
        --allocation-method Static \
        --version IPv4 \
        --zone "$ZONE" \
        --output none
}

attach_public_ip() {
    local ipconfig
    ipconfig="$(get_ipconfig)"

    echo "Attaching Public IP to NIC..."

    az network nic ip-config update \
        --resource-group "$RG" \
        --nic-name "$NIC" \
        --name "$ipconfig" \
        --public-ip-address "$PIP" \
        --output none
}

detach_public_ip() {
    local ipconfig
    ipconfig="$(get_ipconfig)"

    echo "Detaching Public IP from NIC..."

    az network nic ip-config update \
        --resource-group "$RG" \
        --nic-name "$NIC" \
        --name "$ipconfig" \
        --public-ip-address null \
        --output none
}

delete_public_ip() {
    if public_ip_exists; then
        echo "Deleting Public IPv4 resource..."

        az network public-ip delete \
            --resource-group "$RG" \
            --name "$PIP"
    else
        echo "No Public IP resource exists."
    fi
}

show_nsg_rules() {
    az network nsg rule list \
        --resource-group "$RG" \
        --nsg-name "$NSG" \
        --query "[?direction=='Inbound'].{Name:name,Priority:priority,Access:access,Protocol:protocol,Port:destinationPortRange,Ports:destinationPortRanges,Source:sourceAddressPrefix}" \
        --output table
}


ensure_managed_rules() {
    echo "Ensuring inbound SSH/HTTP/HTTPS NSG rules..."
    ensure_rule "$RULE_SSH" "$SSH_PRIORITY" "22" "$SSH_SOURCE"
    ensure_rule "$RULE_HTTP" "$HTTP_PRIORITY" "80" "*"
    ensure_rule "$RULE_HTTPS" "$HTTPS_PRIORITY" "443" "*"
}


check_services() {
    echo
    echo "Checking TigerVNC and 9Router..."

    az vm run-command invoke         --resource-group "$RG"         --name "$VM"         --command-id RunShellScript         --scripts "
echo '=== TigerVNC ==='
systemctl is-active ${VNC_SERVICE} || true

echo
echo '=== 9Router ==='
systemctl is-active ${ROUTER_SERVICE} || true

echo
echo '=== Listening Ports ==='
ss -lnt | grep -E ':${VNC_PORT} |:${ROUTER_PORT} ' || true

echo
echo '=== 9Router Health ==='
curl -sS --max-time 5 http://127.0.0.1:${ROUTER_PORT}/api/health     || echo '9Router health check failed.'
"         --query "value[0].message"         --output tsv
}

case "${1:-}" in
    start)
        echo "======================================"
        echo "Starting Azure VM + TigerVNC + 9Router"
        echo "======================================"

        ensure_managed_rules
        create_public_ip
        attach_public_ip

        echo "Starting VM..."
        az vm start             --resource-group "$RG"             --name "$VM"             --output none

        echo "Waiting for VM services..."
        sleep 10

        IP="$(get_public_ip)"
        check_services

        echo
        echo "VM started successfully."
        echo "Power state : $(get_power_state)"
        echo "Public IP   : $IP"

        echo
        echo "SSH:"
        echo "ssh ${SSH_USER}@${IP}"

        echo
        echo "HTTP : http://${IP}"
        echo "HTTPS: https://${IP}"
        echo
        echo "9Router port ${ROUTER_PORT} remains private."
        echo "Use Nginx/Caddy on ports 80/443 to proxy to 127.0.0.1:${ROUTER_PORT}."

        echo
        echo "TigerVNC tunnel:"
        echo "ssh -L ${VNC_PORT}:127.0.0.1:${VNC_PORT} ${SSH_USER}@${IP}"

        echo
        echo "Optional direct 9Router tunnel:"
        echo "ssh -L ${ROUTER_PORT}:127.0.0.1:${ROUTER_PORT} ${SSH_USER}@${IP}"

        ;;

    stop)
        echo "======================================"
        echo "Stopping Azure VM"
        echo "======================================"

        az vm deallocate             --resource-group "$RG"             --name "$VM"             --output none

        detach_public_ip
        delete_public_ip

        echo
        echo "VM has been deallocated."
        echo "Public IPv4 has been removed."
        ;;

    status)
        echo "======================================"
        echo "Azure VM Status"
        echo "======================================"

        STATE="$(get_power_state)"
        echo "Power state: $STATE"

        echo
        echo "Public IP:"
        if public_ip_exists; then
            get_public_ip
        else
            echo "None"
        fi

        echo
        echo "Inbound NSG rules:"
        show_nsg_rules

        if [[ "$STATE" == "VM running" ]]; then
            check_services
        fi
        ;;

    *)
        echo "Usage:"
        echo "  $0 start"
        echo "  $0 stop"
        echo "  $0 status"
        exit 1
        ;;
esac
