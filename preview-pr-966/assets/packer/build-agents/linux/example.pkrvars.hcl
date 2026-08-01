/*****************************
* Networking Configuration

If vpc_id and subnet_id are null Packer will attempt to use
the default vpc and subnet for the region. If you do not have
a default VPC in the target region, you'll need to provide a
VPC and a subnet.
*****************************/
region = "us-west-2" # DEFAULT
vpc_id = "PLACEHOLDER"
subnet_id = "PLACEHOLDER"
associate_public_ip_address = true # DEFAULT
ssh_interface = "public_ip" # DEFAULT

/*****************************
* Software Configuration
The provided public key will be added to the authorized SSH keys.
Jenkins can then use the associated private key to access instances
provisioned off of this AMI.
*****************************/
public_key = "<include public key here>"
