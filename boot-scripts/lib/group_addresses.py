#!/usr/bin/python

from operator import itemgetter
import boto
import boto.ec2
import boto.ec2.autoscale
from boto.exception import EC2ResponseError
import datetime
import os
import sys
from optparse import OptionParser
from boto.vpc import VPCConnection
import subprocess
import socket
import time

MY_AZ = None
INSTANCE_ID = None

def cmd_output(args, **kwds):
    ## this function will run a command on the OS and return the result
    kwds.setdefault("stdout", subprocess.PIPE)
    kwds.setdefault("stderr", subprocess.STDOUT)
    proc = subprocess.Popen(args, **kwds)
    return proc.communicate()[0]

def metaData(dataPath):
    ## using 169.254.169.254 instead of 'instance-data' because some people
    ## like to modify their dhcp tables...
    return cmd_output(["curl", "-sL", "169.254.169.254/latest/meta-data/" + dataPath])

def getAvailabilityZone():
    ## cached
    global MY_AZ
    if MY_AZ is None:
        MY_AZ = metaData("placement/availability-zone")
    return MY_AZ

def getRegion():
  return getAvailabilityZone()[:-1]

def getInstanceId():
    ## cached
    global INSTANCE_ID
    if INSTANCE_ID == None:
        INSTANCE_ID = metaData("instance-id")
    return INSTANCE_ID

def getMe():
    ## don't cache this as our instance attributes can change
    return EC2.get_only_instances(instance_ids=[getInstanceId()])[0]

def getMyAsgName():
    allTags = getMe().tags
    for tag in allTags:
        if 'aws:autoscaling:groupName' in tag:
            return allTags[tag]

def getAsgInstances(asg_name):
    group = AUTOSCALE.get_all_groups([asg_name])[0]
    instance_ids = [i.instance_id for i in group.instances]
    reservations = EC2.get_all_instances(instance_ids)
    instances = [i for r in reservations for i in r.instances]
    return instances

region = getRegion()
EC2 = boto.ec2.connect_to_region(region)
AUTOSCALE = boto.ec2.autoscale.connect_to_region(region)

reservations = EC2.get_all_instances()
instances = [i for r in reservations for i in r.instances]
my_asg_name = getMyAsgName()
oldest_instance = None
if my_asg_name  != None:
    instances = getAsgInstances(my_asg_name)
    times = []
    for instance in range(0, len(instances)):
        times.append({'id':instances[instance].id, 'launch_time':instances[instance].launch_time, 'private_ip_address': instances[instance].private_ip_address })
    sor = sorted(times, key=lambda k: k['launch_time'])
    for ins in range(0, len(sor)):
        print sor[ins]['private_ip_address']
else:
    print getMe().private_ip_address
