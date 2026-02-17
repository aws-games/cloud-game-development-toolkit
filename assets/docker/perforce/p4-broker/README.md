# P4 Broker Container Image

This directory contains the Dockerfile for building a Perforce Helix Broker (`p4broker`) container image.

## Building the Image

```bash
docker build -t p4-broker .
```

## Pushing to Amazon ECR

```bash
# Authenticate with ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

# Tag the image
docker tag p4-broker:latest <account-id>.dkr.ecr.<region>.amazonaws.com/p4-broker:latest

# Push the image
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/p4-broker:latest
```

## Pushing to Another Container Registry

```bash
# Tag the image for your registry
docker tag p4-broker:latest <registry-url>/p4-broker:latest

# Push the image
docker push <registry-url>/p4-broker:latest
```

## Local Testing

```bash
# Create a local broker config file
cat > p4broker.conf <<EOF
target = ssl:your-p4-server:1666;
listen = 1666;
directory = /tmp;
logfile = /tmp/p4broker.log;

command: *
{
    action = pass;
}
EOF

# Run the container
docker run -p 1666:1666 -v $(pwd)/p4broker.conf:/config/p4broker.conf p4-broker
```

## Configuration

The container expects a broker configuration file at `/config/p4broker.conf`. When deployed via the Terraform module, this file is downloaded from S3 by an init container and mounted into the broker container via a shared volume.
