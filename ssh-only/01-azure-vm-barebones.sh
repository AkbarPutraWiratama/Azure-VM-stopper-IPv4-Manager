#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Azure VM Barebones - SSH Only
# ============================================================
# Public inbound ports managed by this script: 22
#
# This script manages only:
# - Azure VM
# - Public IPv4
# - NSG rules
#
# It does NOT manage TigerVNC or 9Router.
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
    echo "Ensuring inbound SSH NSG rule..."
    ensure_rule "$RULE_SSH" "$SSH_PRIORITY" "22" "$SSH_SOURCE"

    # Remove only web rules created by this script family.
    remove_managed_rule "$RULE_HTTP"
    remove_managed_rule "$RULE_HTTPS"
}


case "${1:-}" in
    start)
        echo "======================================"
        echo "Starting Azure VM"
        echo "======================================"

        ensure_managed_rules
        create_public_ip
        attach_public_ip

        echo "Starting VM..."
        az vm start             --resource-group "$RG"             --name "$VM"             --output none

        sleep 5
        IP="$(get_public_ip)"

        echo
        echo "VM started successfully."
        echo "Power state : $(get_power_state)"
        echo "Public IP   : $IP"
        echo
        echo "SSH:"
        echo "ssh ${SSH_USER}@${IP}"

        ;;

    stop)
        echo "======================================"
        echo "Stopping Azure VM"
        echo "======================================"

        echo "Deallocating VM..."
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

        echo "Power state: $(get_power_state)"
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
        ;;

    *)
        echo "Usage:"
        echo "  $0 start"
        echo "  $0 stop"
        echo "  $0 status"
        exit 1
        ;;
esac
