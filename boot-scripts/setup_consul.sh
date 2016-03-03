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

consul_config_dir=${HOME}/consul
consul_data_dir=${HOME}/consul/data
consul_ui_dir=${HOME}/consul/ui

mkdir -p "$consul_config_dir"
mkdir -p "$consul_data_dir"
mkdir -p "$consul_ui_dir"

GROUP_SIZE_MIN="${CONSUL_GROUP_SIZE_MIN:-1}"
region="$(curl -sL 169.254.169.254/latest/meta-data/placement/availability-zone | sed '$s/.$//')"

addresses="$(python ./lib/tag_addresses.py --component consul-server)"
## lets wait until the minimum actually exists
while [ "$(wc -l < <(echo $addresses | perl -pe 's{\s}{\n}g'))" -lt "$GROUP_SIZE_MIN" ]; do
    sleep 1
    addresses="$(python ./lib/tag_addresses.py --component consul-server)"
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

is_server=true
if [ -z ${CONSUL_SERVER} ]; then is_server=false; fi

join_or_bootstrap=""
if [ "true" = "$is_leader" ] && [ "true" = "$is_server" ]; then
    join_or_bootstrap="\"bootstrap_expect\":$GROUP_SIZE_MIN,"
else
  join_or_bootstrap="\"start_join\": [$joinArr],"
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
    "server": $is_server,
    "rejoin_after_leave": true,
    "data_dir": "$consul_data_dir",
    "ui_dir": "$consul_ui_dir",
    "datacenter": "${CONSUL_DATACENTER_NAME:-$region}"
}
EOF
