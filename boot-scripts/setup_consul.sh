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

my_ipaddress=""
region=""
joinArr=""

is_leader="false"
is_server="true"
if [ -z ${CONSUL_SERVER} ]; then is_server=false; fi

group_size_min="${CONSUL_GROUP_SIZE_MIN:-1}"

if [ "$CONSUL_JOIIN_SERVERS" ] && [ -z "$CONSUL_AUTODISCOVER" ]; then
    # Dev
    my_ipaddress="$(ip addr show eth0 | grep 'inet ' | cut -d/ -f1 | awk '{ print $2}')"
    joinArr="$(echo ${CONSUL_JOIIN_SERVERS} | sed 's/\(\[\|\]\)//g' )"
    is_leader="true"
    region="Dev"
elif [ -z "$CONSUL_JOIN_SERVERS" ] && [ "$CONSUL_AUTODISCOVER" ]; then
    # Do AWS discovery
    region="$(curl -sL 169.254.169.254/latest/meta-data/placement/availability-zone | sed '$s/.$//')"
    addresses="$(python ./lib/tag_addresses.py --component consul-server)"

    ## lets wait until the minimum actually exists
    while [ "$(wc -l < <(echo $addresses | perl -pe 's{\s}{\n}g'))" -lt "$group_size_min" ]; do
        sleep 1
        addresses="$(python ./lib/tag_addresses.py --component consul-server)"
    done

    leader_ip="$(echo $addresses | perl -pe 's{\s}{\n}g' | head -1)"
    my_ipaddress="$(curl -sL 169.254.169.254/latest/meta-data/local-ipv4)"
    is_leader="false"
    if [ "$my_ipaddress" = "$leader_ip" ]; then
        is_leader="true"
    fi

    for ip in $addresses; do
    ## do doing join myself
    if [ "$ip" != "$my_ipaddress" ]; then
	if [ -n "$joinArr" ]; then
	    joinArr="$joinArr ,"
	fi
	joinArr="$joinArr \"$ip\""
    fi
done
else
    echo "Either consul join servers or Autodiscover must be enabled"
    echo CONSUL_JOIIN_SERVER=["\"<ip>\""] OR
    echo CONSUL_AUTOJOIN=true
    exit 1
fi


join_or_bootstrap=""
if [ "true" = "$is_leader" ] && [ "true" = "$is_server" ]; then
    join_or_bootstrap="\"bootstrap_expect\":$group_size_min,"
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
echo "$consul_config_dir/consul.json"
EOF
