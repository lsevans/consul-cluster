#!/bin/bash

script="/opt/remove_failed.sh"

cat <<"EOF" > "$script"
#!/bin/bash

region="$(curl -sL 169.254.169.254/latest/meta-data/placement/availability-zone | sed '$s/.$//')"
my_ipaddress="$(curl -sL 169.254.169.254/latest/meta-data/local-ipv4)"

failed_consul_nodes="$(/consul/consul members | grep failed | awk '{print $1}')"

EOF

## evaluate these variables
cat <<EOF >> "$script"
## lets give it some time
sleep "${CONSUL_FAILURE_GRACE_PERIOD_IN_SECONDS:-60}"
EOF

cat <<"EOF" >> "$script"
for node in $failed_consul_nodes; do
    ## if they are still failed, kill them
    failed_node_name="$(/consul/consul members | grep $node | grep failed | awk '{print $1}')"
    if [ -n "$failed_node_name" ]; then
        /consul/consul force-leave "$failed_node_name"
    fi
done
EOF

#write out current crontab if necessary
if ! crontab -l | grep -q "$script"; then
    crontab -l > mycron
    #echo new cron into cron file
    #echo "* * * * * /bin/bash $script" >> mycron

    #install new cron file
    crontab mycron
    rm mycron
fi
