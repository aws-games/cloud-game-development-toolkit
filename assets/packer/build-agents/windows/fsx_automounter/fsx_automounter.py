#!/usr/bin/env python3
from botocore.utils import IMDSFetcher
from botocore.exceptions import ClientError
import boto3
import subprocess
import os
import platform
import sys
import argparse

# get this EC2 instance's "name" tag via EC2 instance metadata. NOTE: this won't work if the EC2 instance doesn't have access to tags through metadata
def get_instance_name():
    return IMDSFetcher()._get_request("/latest/meta-data/tags/instance/Name", None, token=IMDSFetcher()._fetch_metadata_token()).text.strip()

# get this EC2 instance's region via EC2 instance metadata
def get_instance_region():
    return IMDSFetcher()._get_request("/latest/meta-data/placement/region", None, token=IMDSFetcher()._fetch_metadata_token()).text.strip()

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
        mount_driveletter_tag = [t for t in tags if t['Key'] == 'automount-fsx-volume-driveletter']
        if mount_on_tag and (mount_name_tag or mount_driveletter_tag):
            if instance_name in mount_on_tag[0]['Value'].split(' '):
                if volume['VolumeType'] == 'OPENZFS':
                    returninfo.append({
                        'Volume': volume,
                        'Name': mount_name_tag[0]['Value'] if mount_name_tag else None,
                        'DriveLetter': mount_driveletter_tag[0]['Value'] if mount_driveletter_tag else None,
                        'DNS': '%s.fsx.%s.amazonaws.com' % (volume['FileSystemId'], client.meta.region_name),
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
                if platform.system() == 'Windows':
                    if not volumeInfo['DriveLetter']:
                        raise Exception("No drive letter specified for volume '%s'" % volumeInfo['Name'])
                    volPath = volumeInfo['VolumePath'].replace('/', '\\')[1:] # replace slashes with backslashes in path and remove first character
                    driveLetter = volumeInfo['DriveLetter'].upper()
                    
                    # run command example: mount \\fs-xxxxxxxxx.fsx.REGION.amazonaws.com\fsx Z:
                    #runCmd = ["mount", "\\\\%s\\%s" % (volumeInfo['DNS'], volPath), "%s:" % volumeInfo['Name'][0].upper()]
                    # run runCmd using cmd.exe
                    #runCmd = ["cmd.exe", "/C", " ".join(runCmd)]
                    
                    # run command example: New-PSDrive -Name "Z" -PSProvider "FileSystem" -Root "\\fs-xxxxxxx.fsx.REGION.amazonaws.com\fsx"
                    runCmd = ["New-PSDrive", "-Persist", "-Name", driveLetter, "-PSProvider", "FileSystem", "-Root", "\\\\%s\\%s" % (volumeInfo['DNS'], volPath)]
                    # run runCmd using PowerShell
                    runCmd = ["powershell.exe", "-Command", " ".join(runCmd)]
                    
                    procinfo = subprocess.run(runCmd)
                    # throw an exception if the mount command failed
                    if procinfo.returncode != 0:
                        raise Exception("Exit code (%s) of mount process is nonzero when mounting '%s'. Runcmd: %s" % (procinfo.returncode, volumeInfo['Name'], runCmd))
            except Exception as e:
                print("Failed to mount volume '%s'" % volumeInfo['Name'])
                print(e)
        else:
            print("Currently not supported: volumeType %s" % volumeInfo['VolumeType'])
       
       
def main(region=None):
    if region is None:
        region = get_instance_region()
    client = boto3.client('fsx', region_name=region)      
    mount_fsx_volumes(client)
    return 0

if __name__ == '__main__':
    # get region from cli '--region' parameter, using argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--region', help='AWS region to use. Will be determined automatically from EC2 instance metadata if not provided.')
    args = parser.parse_args()
    region = args.region
    sys.exit(main(region=region))
