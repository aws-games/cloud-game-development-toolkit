# Packer templates for Unreal Engine Linux build agents

The following templates provide Unreal Engine Linux build agents:

| Operating system | CPU architecture | file location
|-|-|-|
|Ubuntu Jammy 22.04 | x86_64 (a.k.a. amd64)  | [`x86_64/ubuntu-jammy-22.04-amd64-server.pkr.hcl`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/assets/packer/build-agents/linux/ubuntu-jammy-22.04-amd64-server.pkr.hcl)
|Ubuntu Jammy 22.04 | aarch64 (a.k.a. arm64) | [`aarch64/ubuntu-jammy-22.04-arm64-server.pkr.hcl`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/assets/packer/build-agents/linux/ubuntu-jammy-22.04-arm64-server.pkr.hcl)
|Amazon Linux 2023  | x86_64 (a.k.a. amd64)  | [`x86_64/amazon-linux-2023-x86_64.pkr.hcl`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/assets/packer/build-agents/linux/amazon-linux-2023-x86_64.pkr.hcl)
|Amazon Linux 2023  | aarch64 (a.k.a. arm64) | [`aarch64/amazon-linux-2023-arm64.pkr.hcl`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/assets/packer/build-agents/linux/amazon-linux-2023-arm64.pkr.hcl)

##### Usage

1. Make a copy of `example.pkrvars.hcl` and adjust the input variables as needed
2. Ensure you have active AWS credentials
3. Invoke `packer build --var-file=<your .pkrvars.hcl file> <path to .pkr.hcl file>`, then wait for the build to complete.

##### Software packages included

The templates install various software packages:

**common tools**

Some common tools are installed to enable installing other software, performing maintenance tasks, and compile some C++ software:

* git
* curl
* jq
* unzip
* dos2unix
* [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html)
* [AWS Systems Manager Agent](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html)
* [Amazon Corretto](https://aws.amazon.com/corretto/)
* mount.nfs, to be able to mount FSx volumes over NFS
* python3
* python3 packages: 'pip', 'requests', 'boto3' and 'botocore'
* clang
* cmake3
* scons
* Development libraries for compiling the [Amazon GameLift Server SDK for C++](https://aws.amazon.com/gamelift/)
* Development libraries for compiling the Godot 4 game engine (if available in the OS's package manager)

**mold**

The '[mold](https://github.com/rui314/mold)' linker is installed to enable faster linking.

**FSx automounter service**

The FSx automounter systemd service is a service written in Python that automatically mounts FSx for OpenZFS volumes on instance bootup. The service uses resource tags on FSx volumes to determine if and where to mount volumes on.

You can use the following tags on FSx volumes:
* '_automount-fsx-volume-name_' tag: specifies the name of the local mount point. The mount point specified will be prefixed with 'fsx_' by the service.
* '_automount-fsx-volume-on_' tag: This tag contains a space-delimited list of EC2 instance names on which the volume will be automatically mounted by this service (if it is running on that instance).

For example, if the FSx automounter service is running on an EC2 instance with Name tag 'ubuntu-builder', and an FSx volume has tag `automount-fsx-volume-on`=`al2023-builder ubuntu-builder` and tag `automount-fsx-volume-name`=`workspace`, then the automounter will automatically mount that volume on `/mnt/fsx_workspace`.

Note that the automounter service makes use of the [ListTagsForResource](https://docs.aws.amazon.com/fsx/latest/APIReference/API_ListTagsForResource.html) FSx API call, which is rate-limited. If you intend to scale up hundreds of EC2 instances that are running this service, then we recommend [automatically mounting FSx volumes using `/etc/fstab`](https://docs.aws.amazon.com/fsx/latest/OpenZFSGuide/attach-linux-client.html).

**mount_ephemeral service**

The mount_ephemeral service is a systemd service written as a simple bash script that mounts NVMe attached instance storage volume automatically as temporary storage. It does this by formatting `/dev/nvme1n1` as xfs and then mounting it on `/tmp`. This service runs on instance bootup.

**create_swap service**

The create_swap service is a systemd service written as a simple bash script that creates a 1GB swap file on `/swapfile`. This service runs on instance bootup.

**sccache**

'[sccache](https://github.com/mozilla/sccache)' is installed to cache c/c++ compilation artefacts, which can speed up builds by avoiding unneeded work.

sccache is installed as a _systemd service_, and configured to use `/mnt/fsx_cache/sccache` as its cache folder. The service expects this folder to be available or set up by another service.

**octobuild**

'[Octobuild](https://github.com/octobuild/octobuild)' is installed to act as a compilation cache for Unreal Engine.

Octobuild is configured in [octobuild.conf](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/assets/packer/build-agents/linux/octobuild.conf) to use `/mnt/fsx_cache/octobuild_cache` as its cache folder, and expects this folder to be available or set up by another service.

NOTE: Octobuild is not supported on aarch64, and therefore not installed there.

##### Processor architectures and naming conventions

Within this folder, the processor architecture naming conventions as reported by `uname -m` are used, hence why there are scripts here with names containing "x86_64" or "aarch64". The packer template `.hcl` files are named following the naming conventions of the operating system that they are based on. Unfortunately, because some operating systems don't use the same terminology in their naming conventions throughout, this means that you'll see this lack of consistency here has well.
