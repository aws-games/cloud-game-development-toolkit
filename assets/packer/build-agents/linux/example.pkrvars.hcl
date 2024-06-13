region = "PLACEHOLDER" # AWS Region code to deploy the AMI into. i.e. "us-west-2"
vpc_id = "PLACEHOLDER" # VPC id to create the AMI in
subnet_id = "PLACEHOLDER" # Subnet to create the AMI in
profile = "default" # AWS CLI profile to use
public_key = "PLACEHOLDER" # the public key that will be added to ~/.ssh/authorized_keys for the default user. Set this to the public key of a keypair which your build orchestrator has access to.
