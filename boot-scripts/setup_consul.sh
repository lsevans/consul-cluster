#!/bin/bash
######################################################################
##
## Required Variables:
##  Either CONSUL_JOIN_SERVERS=["1.2.3.4",".5.6.7.8"] OR 
##    CONSUL_AUTODISCOVER=true with proper AWS credentials
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

bind_address="$(ip addr show eth0 | grep 'inet ' | cut -d/ -f1 | awk '{ print $2}')"
advertise_address=bind_address
joinArr="$(echo ${CONSUL_JOIN_SERVERS} | sed 's/\(\[\|\]\)//g' )"
is_leader="false"
group_size_min="${CONSUL_GROUP_SIZE_MIN:-1}"
is_server="true"

if [ -z "${CONSUL_SERVER}" ]; then is_server=false; fi

if [ -z "$CONSUL_JOIN_SERVERS" ] && [ "$CONSUL_AUTODISCOVER" ]; then
    # Do AWS discovery
    addresses="$(python ./lib/tag_addresses.py --component consul-server)"

    ## lets wait until the minimum actually exists
    while [ "$(wc -l < <(echo $addresses | perl -pe 's{\s}{\n}g'))" -lt "$group_size_min" ]; do
        sleep 1
        addresses="$(python ./lib/tag_addresses.py --component consul-server)"
    done

    leader_ip="$(echo $addresses | perl -pe 's{\s}{\n}g' | head -1)"
    advertise_address="$(curl -sL 169.254.169.254/latest/meta-data/local-ipv4)"
    is_leader="false"
    if [ "$advertise_address" = "$leader_ip" ]; then
        is_leader="true"
    fi

    for ip in $addresses; do
      ## do doing join myself
      if [ "$ip" != "$advertise_address" ]; then
          if [ -n "$joinArr" ]; then
              joinArr="$joinArr ,"
          fi
          joinArr="$joinArr \"$ip\""
      fi
    done
fi

# If we still don't have anyone to join to, we better bootstrap
if [ -z "$joinArr" ]; then
  is_leader=true
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
        "http": "$bind_address"
    },
    "bind_addr": "$bind_address",
    "node_name": "$advertise_address",
    "advertise_addr": "$advertise_address",
    "log_level": "INFO",
    "server": $is_server,
    "rejoin_after_leave": true,
    "data_dir": "$consul_data_dir",
    "ui_dir": "$consul_ui_dir",
    "datacenter": "${CONSUL_DATACENTER_NAME:-vpc}"
}
EOF
