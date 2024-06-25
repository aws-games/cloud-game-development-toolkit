# Packer CI

This README provides steps for running basic CI on Packer templates contained in the project.

## Configuration

In the root of the `./packer` directory is a configuration yaml file (`.config.yml`) that contains the location of each of the Packer templates in the project. When new Packer templates are added, the config file should be updated as well.


### `.config.yml`

``` title=".confi.yml"
--8<-- "assets/packer/.config.yml"
```

```bash
docker build -t packer-ci -f .ci/Dockerfile . \             
--build-arg AWS_REGION=us-east-1 \
--build-arg AWS_VPC_ID=vpc-086839c0e28ad1f29 \
--build-arg AWS_SUBNET_ID=subnet-0e6bb0e5c155610c0 \
--build-arg AWS_PROFILE=default \
--build-arg PUBLIC_KEY=Key_Pair_Linux
```


## Packer Directory

```
.
├── build-agents
│   ├── linux
│   │   ├── amazon-linux-2023-arm64.pkr.hcl
│   │   ├── amazon-linux-2023-x86_64.pkr.hcl
│   │   ├── create_swap.service
│   │   ├── create_swap.sh
│   │   ├── example.pkrvars.hcl
│   │   ├── fsx_automounter.py
│   │   ├── fsx_automounter.service
│   │   ├── install_common.al2023.sh
│   │   ├── install_common.ubuntu.sh
│   │   ├── install_mold.sh
│   │   ├── install_octobuild.al2023.x86_64.sh
│   │   ├── install_octobuild.ubuntu.x86_64.sh
│   │   ├── install_sccache.sh
│   │   ├── mount_ephemeral.service
│   │   ├── mount_ephemeral.sh
│   │   ├── octobuild.conf
│   │   ├── README.md
│   │   ├── sccache.service
│   │   ├── ubuntu-jammy-22.04-amd64-server.pkr.hcl
│   │   └── ubuntu-jammy-22.04-arm64-server.pkr.hcl
│   ├── README.md
│   └── windows
│       ├── base_setup.ps1
│       ├── example.pkrvars.hcl
│       ├── install_vs_tools.ps1
│       ├── setup_jenkins_agent.ps1
│       ├── userdata.ps1
│       └── windows.pkr.hcl
├── .ci
│   ├── Dockerfile
│   ├── packer-ci.md
│   ├── packer-validate.sh
│   ├── README.md
│   └── setup.sh
├── .config.yml
└── perforce
    └── helix-core
        ├── example.pkrvars.hcl
        ├── p4_configure.sh
        ├── p4_setup.sh
        ├── perforce.pkr.hcl
        └── README.md
```
