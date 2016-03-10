# consul-cluster
Dockerized version of self-healing and scaling consul cluster

This image runs scripts based on the bootscripts from the project: https://github.com/CloudCoreo/consul-cluster/tree/master/boot-scripts

This image is meant to run in AWS ElasticBeanstalk using ebs-deploy (https://github.com/briandilley/ebs-deploy) or by uploading the Dockerrun.aws.json file in the AWS GUI during beanstalk creation.

Note: When the instances come up, they will query the AWS API to find other consul members. The EBS application should be launched with an IAM role that has the policy "AmazonEC2ReadOnlyAccess"

#### Example environment variables for running server in an AWS Beanstalk environment called "consul-cluster-prod":
- $CONSUL_AUTODISCOVER=true
- $CONSUL_SERVER=true
- $CONSUL_CLUSTER_TAG_KEY: "elasticbeanstalk:environment-name"
- $CONSUL_CLUSTER_TAG_VALUE: "consul-cluster-prod"

#### Environment variables for running manual join:
- $CONSUL_JOIIN_SERVERS=["1.2.3.4", "5.6.7.8"]
- $CONSUL_SERVER=true

##### Environment variables definitions:
- $CONSUL_CLUSTER_REGION: Used with autodiscovery in AWS, this is which region to check for other consul nodes. 
  Defaults to image's current region
- $CONSUL_CLUSTER_TAG_KEY: What tag key to look for to find other consul nodes to connect to "Defaults to `component`"
- $CONSUL_CLUSTER_TAG_VALUE: What tag value to look for other consul nodes with. Defaults to find nodes with `"$CONSUL_CLUSTER_TAG_KEY: consul-server"`
- $CONSUL_AUTODISCOVER: Tells the image that it should go look for nodes in $CONSUL_CLUSTER_REGION that are tagged with "$CONSUL_CLUSTER_TAG_KEY: $CONSUL_CLUSTER_TAG_VALUE"
- $CONSUL_JOIIN_SERVERS: Used to manually join a list of nodes
- $CONSUL_SERVER: Determines if consul starts in server mode. Defaults to true

#### The scripts:
  * lib/tag_addresses.py
    * Queries AWS for EC2 instances to join. It looks for specific **"$CONSUL_CLUSTER_TAG_KEY"** instance tag
  * setup_consul.sh
    * Determines if node should be the bootstrapper or a joiner. If it's a joiner, it uses lib/tag_addresses.py to figure
        out which nodes to join
    * Actually builds the config file consul uses to launch
  * remove_failed.sh
    * Periodically checkes consul member list for failed nodes. It will call a force_leave on every failed nodes for proper cleanup
