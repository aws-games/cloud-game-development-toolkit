#!/usr/bin/env python3
from botocore.utils import IMDSFetcher
from botocore.exceptions import ClientError
import boto3
import subprocess
import os

# get this EC2 instance's "name" tag via EC2 instance metadata. NOTE: this won't work if the EC2 instance doesn't have access to tags through metadata
def get_instance_name():
    return IMDSFetcher()._get_request("/latest/meta-data/tags/instance/Name", None, token=IMDSFetcher()._fetch_metadata_token()).text.strip()

# get this EC2 instance's region via EC2 instance metadata
def get_instance_region():
    return IMDSFetcher()._get_request("/latest/meta-data/placement/region", None, token=IMDSFetcher()._fetch_metadata_token()).text.strip()

REGION = get_instance_region()

client = boto3.client('fsx', region_name=REGION)

# Retrieve the volumes to mount to this EC2 instance, as well as some relevant data to be able to mount them
def get_volumes_with_automount_tags(client):
    instance_name = get_instance_name()
    volumes = client.describe_volumes()['Volumes']
    returninfo = []
    for volume in volumes:
        try:
            tags = client.list_tags_for_resource(ResourceARN=volume['ResourceARN'])['Tags']
        except ClientError as error:
            print("WARN: Could not list tags for resource %s; reason: %s" % (volume['ResourceARN'], error.response['Error']['Code']))
            print("Detailed info:")
            print(error)
            print("ignoring volume and continuing!")
            continue
        mount_on_tag = [t for t in tags if t['Key'] == 'automount-fsx-volume-on']
        mount_name_tag = [t for t in tags if t['Key'] == 'automount-fsx-volume-name']
        if mount_on_tag and mount_name_tag:
            if instance_name in mount_on_tag[0]['Value'].split(' '):
                if volume['VolumeType'] == 'OPENZFS':
                    returninfo.append({
                        'Volume': volume,
                        'Name': mount_name_tag[0]['Value'],
                        'DNS': '%s.fsx.%s.amazonaws.com' % (volume['FileSystemId'], REGION),
                        'VolumeType': volume['VolumeType'],
                        'VolumePath': volume['OpenZFSConfiguration']['VolumePath']
                    })
                else:
                    print("Currently not supported: volumeType %s" % volume['VolumeType'])
    return returninfo

# Mount FSx volumes to this EC2 instance, based on the "automount-fsx-volume-on" tag on the volume.
def mount_fsx_volumes(client):
    volumeInfos = get_volumes_with_automount_tags(client)
    for volumeInfo in volumeInfos:
        # mount -t nfs -o noatime,nfsvers=4.2,sync,nconnect=16,rsize=1048576,wsize=1048576 $FSX_WORKSPACE_DNS:/fsx/ /mnt/fsx_workspace
        if volumeInfo['VolumeType'] == 'OPENZFS':
            try:
                os.makedirs("/mnt/fsx_%s" % volumeInfo['Name'], exist_ok=True)
                runCmd = ["mount", "-t", "nfs", "-o", "noatime,nfsvers=4.2,sync,nconnect=16,rsize=1048576,wsize=1048576", "%s:%s/" % (volumeInfo['DNS'], volumeInfo['VolumePath']), "/mnt/fsx_%s" % volumeInfo['Name']]
                procinfo = subprocess.run(runCmd)
                # throw an exception if the mount command failed
                if procinfo.returncode != 0:
                    raise Exception("Exit code (%s) of mount process is nonzero when mounting '%s'. Runcmd: %s" % (procinfo.returncode, volumeInfo['Name'], runCmd))
            except Exception as e:
                print("Failed to mount volume '%s'" % volumeInfo['Name'])
                print(e)
        else:
            print("Currently not supported: volumeType %s" % volumeInfo['VolumeType'])

mount_fsx_volumes(client)
