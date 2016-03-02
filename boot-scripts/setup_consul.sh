#!/bin/bash
######################################################################
##
## Required Variables:
##   CONSUL_GROUP_SIZE_MIN
##   CONSUL_DATACENTER_NAME
##   CONSUL_UPSTREAM_DNS
##
######################################################################
##
## Required Packages
##   aws-cli in pip
##
######################################################################

consul_config_dir='/etc'
consul_data_dir='/var/consul/data'
consul_ui_dir='/var/consul/ui'

mkdir -p "$consul_config_dir"
mkdir -p "$consul_data_dir"
mkdir -p "$consul_ui_dir"

region="$(curl -sL 169.254.169.254/latest/meta-data/placement/availability-zone | sed '$s/.$//')"

addresses="$(python ./lib/group_addresses.py)"
## lets wait until the minimum actually exists
while [ "$(wc -l < <(echo $addresses | perl -pe 's{\s}{\n}g'))" -lt "${CONSUL_GROUP_SIZE_MIN:-0}" ]; do
    sleep 1
    addresses="$(python ./lib/group_addresses.py)"
done

leader_ip="$(echo $addresses | perl -pe 's{\s}{\n}g' | head -1)"
my_ipaddress="$(curl -sL 169.254.169.254/latest/meta-data/local-ipv4)"
is_leader="false"
if [ "$my_ipaddress" = "$leader_ip" ]; then
    is_leader="true"
fi

joinArr=""
for ip in $addresses; do
    ## do doing join myself
    if [ "$ip" != "$my_ipaddress" ]; then
	if [ -n "$joinArr" ]; then
	    joinArr="$joinArr ,"
	fi
	joinArr="$joinArr \"$ip\""
    fi
done

join_or_bootstrap=""
if [ "true" = "$is_leader" ]; then
    join_or_bootstrap="\"bootstrap_expect\":$CONSUL_GROUP_SIZE_MIN,"
else
    join_or_bootstrap="\"join\": [$joinArr],"
fi

cat <<EOF > "$consul_config_dir/consul.json"
{
    $join_or_bootstrap
    "addresses" : {
        "http": "$my_ipaddress"
    },
    "bind_addr": "$my_ipaddress",
    "node_name": "$my_ipaddress",
    "log_level": "INFO",
    "server": true,
    "rejoin_after_leave": true,
    "enable_syslog": true,
    "data_dir": "$consul_data_dir",
    "ui_dir": "$consul_ui_dir",
    "datacenter": "${CONSUL_DATACENTER_NAME:-$region}"
}
EOF
