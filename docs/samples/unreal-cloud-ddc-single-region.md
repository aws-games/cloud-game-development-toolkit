---
title: Unreal Cloud Derived Data Cache - Single Region
description: Unreal Cloud Derived Data Cache implementation on AWS
---

# Unreal Cloud DDC Single Region

The Unreal Cloud DDC Single Region is a comprehensive solution that leverages several AWS services to create a robust and efficient data caching system. It uses a well-designed Virtual Private Cloud (VPC) to ensure network isolation and security. The solution employs an Amazon Elastic Kubernetes Service (EKS) Cluster with Node Groups to manage and orchestrate containerized applications.

At the heart of the system is an instance of ScyllaDB, a high-performance NoSQL database, running on specially optimized Amazon EC2 instances. The Unreal Cloud Derived Data Cache Container is managed by Helm, a package manager for Kubernetes, and uses Amazon S3 for durable storage.

## Predeployment

There are a couple of important steps you need to complete before deploying this architecture:

### 1. Allowlist your IP

The [Unreal Cloud DDC Infrastructure Module](../modules/unreal-cloud-ddc-infra) requires you to place the IP of the machine interacting with the EKS Cluster within an allow list. You can hard code this in the ```var.eks_cluster_allow_list``` if you have more than 1 IP you want to allow list or utilize the data block within the sample.

### 2. Set Up Github Content Repository Credentials

The [Unreal Cloud DDC Inter Cluster module](../modules/unreal/unreal-cloud-ddc-intra-cluster) utilizes a pull through cache to access the [Unreal Cloud DDC image](https://github.com/orgs/EpicGames/packages/container/package/unreal-cloud-ddc). This requires a secret in [Secrets Manager](https://aws.amazon.com/secrets-manager/). The secret needs to be prefixed with ````ecr-pullthroughcache/````. Additionally, the secret is required to be in the following format:
```json
{
  "username":"GITHUB-USER-NAME-PLACEHOLDER",
  "accessToken":"GITHUB-ACCESS-TOKEN-PLACEHOLDER"
}
```

## Deployment

Once you've completed the prerequisites and set your variables, you can deploy the solution by running:

``` bash
terraform apply
```

The deployment can take close to 30 minutes. Creating the EKS Node Groups and EKS Cluster take around 20 minutes to fully deploy.
## Postdeployment
The sample also deploys a NLB as part of the Unreal Cloud DDC deployment. You will need to go to the EC2 Loadbalncing screen to get the NLB that is created and wait for it to finish provisioning.

To begin interacting with the Unreal Cloud DDC deployment you will need to go to secrets manager and access the secret that was created and used as the Service Account token to interact with the Unreal Cloud DDC deployment.

To validate you can put an object you can run:
```bash
curl http://<nlb-dns>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa -X PUT --data 'test' -H 'content-type: application/octet-stream' -H 'X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA' -i -H 'Authorization: ServiceAccount <secret-manager-token>'
```
After running this you should get a response that looks as the following:
```
HTTP/1.1 200 OK
Server: nginx
Date: Wed, 29 Jan 2025 19:15:05 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive
Server-Timing: blob.put.FileSystemStore;dur=0.1451;desc="PUT to store: 'FileSystemStore'",blob.put.AmazonS3Store;dur=267.0449;desc="PUT to store: 'AmazonS3Store'",blob.get-metadata.FileSystemStore;dur=0.0406;desc="Blob GET Metadata from: 'FileSystemStore'",ref.finalize;dur=7.1407;desc="Finalizing the ref",ref.put;dur=25.2064;desc="Inserting ref"

{"needs":[]}%
```

You can then access the same chunk with the following command:
```bash
curl http://<nlb-dns>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa.json -i -H 'Authorization: ServiceAccount <secret-manager-token>'
```

The response should look like the following:
```
HTTP/1.1 200 OK
Server: nginx
Date: Wed, 29 Jan 2025 19:16:46 GMT
Content-Type: application/json
Content-Length: 66
Connection: keep-alive
X-Jupiter-IoHash: 7D873DCC262F62FBAA871FE61B2B52D715A1171E
X-Jupiter-LastAccess: 01/29/2025 19:16:46
Server-Timing: ref.get;dur=0.0299;desc="Fetching Ref from DB"

{"RawHash":"4878ca0425c739fa427f7eda20fe845f6b2e46ba","RawSize":4}%
```
For a more comprehensive test of your deployment, we recommend using the [bench marking tools](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC/Benchmarks). To do so we used a x2idn.32xlarge as it matched Epic's benchmarking instance to test their configuration.

With the benchmarking tools we ran the following command after compiling the docker image:
```bash
docker run --network host jupiter_benchmark --seed --seed-remote --host http://<nlb-dns> --namespace ddc \
--header="Authorization: ServiceAccount <secrets-manager-token>" all
```
Just a note here, you will have to specify the namespace to be DDC as the token only has access to that namespace.

**It is recommended that if you are using this in a production capacity you change the authentication mode from Service Account to Bearer and use an IDP to authenticate and TLS termination.**
