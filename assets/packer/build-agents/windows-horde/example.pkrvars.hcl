/*****************************
* Networking Configuration
*
* If vpc_id and subnet_id are null Packer will attempt to use the default vpc
* and subnet for the region. For the Horde iSCSI build agent we recommend
* building in a PRIVATE (or ingress-limited) subnet so the temporary build
* instance is never world-open.
*
* SECURITY: this template defaults associate_public_ip_address = false and
* ssh_interface = "private_ip". Keep it that way and run Packer from inside the
* VPC (e.g. a CodeBuild project or bastion in the same network). If you MUST
* build over the public internet, set associate_public_ip_address = true AND
* supply a security_group_id whose WinRM (5986) ingress is scoped to your own
* CIDR. NEVER open 5986 to 0.0.0.0/0.
*****************************/
region    = "us-east-1"   # set to your build region
vpc_id    = "PLACEHOLDER" # e.g. vpc-xxxxxxxx (a private/limited-ingress VPC)
subnet_id = "PLACEHOLDER" # e.g. subnet-xxxxxxxx (private subnet)

# Private-by-default build (recommended). Run Packer from inside the VPC.
associate_public_ip_address = false
ssh_interface               = "private_ip"

# Optional pre-created, CIDR-scoped security group for the temporary build
# instance. REQUIRED if you flip associate_public_ip_address to true.
# security_group_id = "sg-xxxxxxxx"

/*****************************
* Instance Configuration
*
* Unreal from-source builds need a large root volume for the Visual Studio
* Build Tools + toolchain. 256 GB is a sensible default; the workspace itself
* lives on the iSCSI LUN at job time.
*****************************/
instance_type    = "c6a.4xlarge" # DEFAULT
root_volume_size = 256           # DEFAULT

/*****************************
* Software Configuration
*
* This template always bakes: choco, git, OpenSSH, Python, the VS2022 C++ Build
* Tools + VC 14.38 + WDK/PDBCOPY, the .NET 6 runtime (matches the Horde module's
* agent_dotnet_runtime_version default), the .NET 8 SDK (UE 5.5 UAT), p4, awscli,
* and the MSiSCSI initiator + MPIO for the iSCSI/NTFS thin-clone pipeline.
*
* The provided public key is added to the AMI's authorized SSH keys so the
* Horde orchestration service can reach the agent.
*****************************/
public_key = "<include public key here>"
