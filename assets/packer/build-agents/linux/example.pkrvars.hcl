region = "us-west-2"
vpc_id = "PLACEHOLDER" # VPC id to create the AMI in
subnet_id = "PLACEHOLDER" # Subnet to create the AMI in
profile = "DEFAULT" # AWS CLI profile to use
public_key = "ssh-rsa EXAMPLE" # the public key that will be added to ~/.ssh/authorized_keys for the default user. Set this to the public key of a keypair which your build orchestrator has access to.
