# consul-cluster
Dockerized version of self-healing and scaling consul cluster

This image runs scripts based on the bootscripts from the project: https://github.com/CloudCoreo/consul-cluster/tree/master/boot-scripts

#### Environment variables for running server in AWS using autodiscovery:
- $CONSUL_AUTODISCOVER=true
- $CONSUL_SERVER=true
- $AWS_ACCESS_KEY_ID
- $AWS_SECRET_ACCESS_KEY

#### Environment variables for running manual join:
- $CONSUL_JOIIN_SERVERS=["1.2.3.4", "5.6.7.8"]
- $CONSUL_SERVER=true

#### Environment variables for running dev server:
- $CONSUL_JOIIN_SERVERS=["ip1", "ip2"]
- $CONSUL_SERVER=true

##### Optional variables for running server in AWS:
- $CONSUL_CLUSTER_REGION: Used with autodiscovery in AWS, this is which region to check for other consul nodes. 
  Defaults to image's current region
- $CONSUL_CLUSTER_TAG_KEY: What tag key to look for to find other consul nodes to connect to "Defaults to `component`"
- $CONSUL_CLUSTER_TAG_VALUE: What tag value to look for other consul nodes with. Defaults to find nodes with `"component: consul-server"`

#### The scripts:
  * lib/tag_addresses.py
    * Queries AWS for EC2 instances to join. It looks for specific **"component"** instance tag
  * setup_consul.sh
    * Determines if node should be the bootstrapper or a joiner. If it's a joiner, it uses lib/tag_addresses.py to figure
        out which nodes to join
    * Actually builds the config file consul uses to launch
  * remove_failed.sh
    * Periodically checkes consul member list for failed nodes. It will call a force_leave on every failed nodes for proper cleanup
