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
* Instance Configuration

The instance_type and root_volume_size allow you to configure
the defaults for your AMI. If you are installing a significant
amount of software and tooling onto your instance we recommend
expanding the root_volume_size accordingly.

For reference, when building Unreal Engine 5.4, we expand the
root_volume_size to 256 to accomodate the Visual Studio Build
Tools. We then mount an external volume or filesystem to instances
to store the Unreal Engine content.
*****************************/
instance_type = "c6a.4xlarge" # DEFAULT
root_volume_size = 256 # DEFAULT

/*****************************
* Software Configuration

The install_vs_tools variable will provison the AMI with
the Visual Studio Build Tools, workloads and components required
for Unreal Engine 5.4 builds.

The setup_jenkins_agent variable will create a Jenkins user on the
AMI, and install the latest version of Java for usage with Jenkins.

The provided public key will be added to the authorized SSH keys.
Jenkins can then use the associated private key to access instances
provisioned off of this AMI.
*****************************/
setup_jenkins_agent = true
install_vs_tools = true
public_key = "<include public key here>"
