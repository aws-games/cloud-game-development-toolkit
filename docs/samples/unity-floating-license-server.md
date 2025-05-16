---
title: Unity Floating License Server Sample
description: Unity Floating License Server Deployment
---

# Unity Floating License Server

The Unity Floating License server is software that needs to be running to support either floating licenses for the Unity Editor or build machines for building Unity projects.
## Predeployment

You will need to take your Unity Floating License Server and place it in the packer module with the relative path and file name from the script you are running. You will then need to run the packer script which should take 10-15 minutes.

## Deployment

Once you've completed the prerequisites you can deploy the solution by running:

``` bash
terraform apply
```

## Postdeployment

After the sample is set up, you will need to connect to the Unity Floating License Server via EC2 connect and run some commands. To properly set up the Unity Floating License Server you will need to run:
```bash
sudo su ubuntu
cd /opt/UnityLicenseServer
sudo ./Unity.License.Server setup
```
Go through the prompts and the server will generate two documents. In a production deployment you would need to upload the file 'server-registration-request.xml' through Unity's portal and place 'services-config.json' in the file path according to their client [configuration documentation] (https://docs.unity.com/licensing/en-us/manual/ClientConfig). In this sample we will just be creating a service to see the client being able to interact with the Unity Floating License Server.

Once set up please continue by running the following command on the Unity Floating License server:
```bash
sudo ./Unity.License.Server create-service
```
To see if the server is running you can construct a curl command to access Unity Floating License Server's port:
```bash
curl http://<IP-OF-THE-FLOATING-LICENSE-SERVER>:<PORT>/v1/status
```
If you dont know the IP of the machine you can run this command:
```bash
aws_metadata_token=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
curl -H "X-aws-ec2-metadata-token: $aws_metadata_token" http://169.254.169.254/latest/meta-data/local-ipv4
```
You can then curl the service on either the Floating License Server or the Client to receive a response like the following:
```bash
{"serverStatus":"Unhealthy","serverUpTime":"0 days 0 hours 17 minutes 30 seconds","serverUpTimeMs":1050770,"version":"2.1.0+e3f6bc2","serverId":"ip-192-168-0-7"}
```
Due to this not being a production server we have not loaded any licenses into the service which is causing it to be unhealthy but this is showing internode communication successfully working.
