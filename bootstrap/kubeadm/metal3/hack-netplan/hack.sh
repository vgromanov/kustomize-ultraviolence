#!/bin/bash

mount -L config-2 /mnt

JSON_FILE="/mnt/openstack/latest/network_data.json"

if [[ ! -f "$JSON_FILE" ]]; then
  echo "File $JSON_FILE not found!"
  exit 1
fi

netmask_to_cidr() {
  local netmask=$1
  local cidr=0
  local octets=($${netmask//./ })
  for octet in "$${octets[@]}"; do
    while [ $octet -gt 0 ]; do
      ((cidr++))
      octet=$((octet & (octet - 1)))
    done
  done
  echo $cidr
}

bond_links=($(jq -c '.links[] | select(.id | test("^bond")) | {id: .id, mac: .ethernet_mac_address, bond_links: .bond_links, bond_mode: .bond_mode, bond_type: .type}' "$JSON_FILE"))
en_links=($(jq -c '.links[] | select(.id | test("^eno|^enp|^ens")) | {id: .id, mac: .ethernet_mac_address}' "$JSON_FILE"))
networks=($(jq -c '.networks[] | {id: .id, link: .link, ip: .ip_address, netmask: .netmask, gateway: .routes[0].gateway, dns: [.routes[0].services[] | select(.type == "dns") | .address]}' "$JSON_FILE"))

if [ $${#bond_links[@]} -gt 0 ]; then
  for link in "$${bond_links[@]}"; do
    link_id=$(echo "$link" | jq -r '.id')
    link_mac=$(echo "$link" | jq -r '.mac')
    bond_links_members=$(echo "$link" | jq -r '.bond_links[]')
    bond_mode=$(echo "$link" | jq -r '.bond_mode')
    bond_type=$(echo "$link" | jq -r '.bond_type')

    for network in "$${networks[@]}"; do
      network_id=$(echo "$network" | jq -r '.id')
      network_link=$(echo "$network" | jq -r '.link')
      network_ip=$(echo "$network" | jq -r '.ip')
      network_netmask=$(echo "$network" | jq -r '.netmask')
      network_gateway=$(echo "$network" | jq -r '.gateway')
      network_dns=($(echo "$network" | jq -r '.dns[]'))

      if [[ "$link_id" == "$network_link" ]]; then
        cidr=$(netmask_to_cidr "$network_netmask")

        OUTPUT_FILE="/etc/systemd/network/10-$${link_id}.network"

        cat > "$OUTPUT_FILE" << EOF
[Match]
Name=$${link_id}
[Network]
DHCP=no
$(for dns in "$${network_dns[@]}"; do echo "DNS=$dns"; done)
Address=$network_ip/$cidr
Gateway=$network_gateway
EOF
        echo "File $OUTPUT_FILE created."

        OUTPUT_FILE_BOND_NETDEV="/etc/systemd/network/$${link_id}.netdev"

        cat > "$OUTPUT_FILE_BOND_NETDEV" << EOF
[NetDev]
Name=$${link_id}
Kind=$${bond_type}

[Bond]
Mode=$${bond_mode}
LACPTransmitRate=fast
MIIMonitorSec=1s
EOF
        echo "File $OUTPUT_FILE_BOND_NETDEV created."

        for bond_links_member in $bond_links_members; do
          OUTPUT_FILE_EN_NETWORK="/etc/systemd/network/$${bond_links_member}.network"
          cat > "$OUTPUT_FILE_EN_NETWORK" << EOF
[Match]
Name=$${bond_links_member}

[Network]
Bond=$${link_id}
EOF
          echo "File $OUTPUT_FILE_EN_NETWORK created."
        done
      fi
    done
  done
fi

for network in "$${networks[@]}"; do
  network_id=$(echo "$network" | jq -r '.id')
  network_link=$(echo "$network" | jq -r '.link')
  network_ip=$(echo "$network" | jq -r '.ip')
  network_netmask=$(echo "$network" | jq -r '.netmask')
  network_gateway=$(echo "$network" | jq -r '.gateway')
  network_dns=($(echo "$network" | jq -r '.dns[]'))

  is_bond_interface=false
  for bond_link in "$${bond_links[@]}"; do
    bond_id=$(echo "$bond_link" | jq -r '.id')
    if [[ "$bond_id" == "$network_link" ]]; then
      is_bond_interface=true
      break
    fi
  done

  if [[ "$is_bond_interface" == false ]]; then
    cidr=$(netmask_to_cidr "$network_netmask")

    OUTPUT_FILE="/etc/systemd/network/10-$${network_id}.network"

    cat > "$OUTPUT_FILE" << EOF
[Match]
Name=$${network_id}
[Network]
DHCP=no
$(for dns in "$${network_dns[@]}"; do echo "DNS=$dns"; done)
Address=$network_ip/$cidr
$(if [ $${#network_gateway} -gt 0 ] && [ "$network_gateway" != "null" ]; then echo "Gateway=$network_gateway"; fi)
EOF
    echo "File $OUTPUT_FILE created."
  fi
done

/bin/systemctl restart systemd-networkd
umount /mnt
