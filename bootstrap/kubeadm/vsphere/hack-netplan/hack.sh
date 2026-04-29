#!/bin/bash
PATH=$PATH:/bin:/usr/share/oem/bin
function yaml_to_vars {
  # find input file
  for f in "$1" "$1.yay" "$1.yml"
  do
    [[ -f "$f" ]] && input="$f" && break
  done
  [[ -z "$input" ]] && exit 1

  # use given dataset prefix or imply from file name
  [[ -n "$2" ]] && local prefix="$2" || {
    local prefix=$(basename "$input"); prefix=$${prefix%.*}; prefix="$${prefix//-/_}_";
  }

  local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
  sed -ne "s|,$s\]$s\$|]|" \
       -e ":1;s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1\2: [\3]\n\1  - \4|;t1" \
       -e "s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s\]|\1\2:\n\1  - \3|;p" $1 | \
  sed -ne "s|,$s}$s\$|}|" \
       -e ":1;s|^\($s\)-$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1- {\2}\n\1  \3: \4|;t1" \
       -e    "s|^\($s\)-$s{$s\(.*\)$s}|\1-\n\1  \2|;p" | \
  sed -ne "s|^\($s\):|\1|" \
       -e "s|^\($s\)-$s[\"']\(.*\)[\"']$s\$|\1$fs$fs\2|p" \
       -e "s|^\($s\)-$s\(.*\)$s\$|\1$fs$fs\2|p" \
       -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
       -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" | \
  awk -F$fs '{
     indent = length($1)/2;
     vname[indent] = $2;
     for (i in vname) {if (i > indent) {delete vname[i]; idx[i]=0}}
     if(length($2)== 0){  vname[indent]= ++idx[indent] };
     if (length($3) > 0) {
        vn=""; for (i=0; i<indent; i++) { vn=(vn)(vname[i])("_")}
        printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, vname[indent], $3);
     }
  }'
}

vmtoolsd --cmd "info-get guestinfo.metadata" | /bin/base64 --decode > /tmp/netplan.yaml
cat /tmp/netplan.yaml
yaml_to_vars /tmp/netplan.yaml
eval $(yaml_to_vars /tmp/netplan.yaml)
/bin/cat > /etc/systemd/network/10-ipam.network << EOF
[Match]
MACAddress=$netplan_network_ethernets_id0_match_macaddress

[Network]
DHCP=no
DNS=$netplan_network_ethernets_id0_nameservers_1
DNS=$netplan_network_ethernets_id0_nameservers_2
DNS=$netplan_network_ethernets_id0_nameservers_3
Address=$netplan_network_ethernets_id0_1
Gateway=$netplan_network_ethernets_id0_gateway4
EOF
/bin/systemctl restart systemd-networkd
