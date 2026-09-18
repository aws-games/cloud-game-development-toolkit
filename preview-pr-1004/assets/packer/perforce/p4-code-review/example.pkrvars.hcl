# Region where the Packer builder instance will run
region = "us-east-1"

# VPC for the Packer builder instance (leave commented out to use default VPC)
vpc_id = "vpc-xxxxx"

# Public subnet for the Packer builder instance (must have internet access for package downloads)
subnet_id = "subnet-xxxxx"

# Optional: Associate public IP to builder instance (required if subnet doesn't auto-assign public IPs)
# associate_public_ip_address = true

# Optional: SSH interface for Packer to connect (use "public_ip" for public subnets)
# ssh_interface = "public_ip"

# Optional: Install helix-swarm-optional package (LibreOffice, ImageMagick for previews, adds ~500MB to AMI)
# install_swarm_optional = true
