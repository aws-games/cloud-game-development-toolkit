# Packer ci

> `/packer` dir is build context

```
docker build -t packer-ci -f .ci/Dockerfile . \
--build-arg AWS_REGION=us-east-1 \
--build-arg AWS_VPC_ID=vpc-086839c0e28ad1f29 \
--build-arg AWS_SUBNET_ID=subnet-0e6bb0e5c155610c0 \
--build-arg AWS_PROFILE=default \
--build-arg PUBLIC_KEY=Key_Pair_Linux
```