# Unity + TeamCity Build Agent Docker Image

This directory contains a Docker image that combines Unity Editor with TeamCity Build Agent for automated Unity builds.

The image uses official Unity Hub and Unity Editor installations.

## What's Included

- **Unity Editor** (default: Unity 6 LTS) with Linux build support (IL2CPP)
- **TeamCity Build Agent** runtime
- **Perforce P4 CLI** for source control integration
- **Git + Git LFS** for additional VCS support
- **AWS CLI v2** for artifact management to S3
- **Java 17** for TeamCity agent runtime

All components are installed from official sources using standard package managers and installers.

## Building the Image

### Prerequisites

- Docker Desktop or Docker Engine
- AWS CLI v2 configured with credentials
- AWS account with ECR access

### Quick Start

```bash
cd teamcity-unity-build-agent/
./build-and-push.sh
```

This will:
1. Create an ECR repository (if needed)
2. Build the Docker image (15-30 minutes)
3. Push to Amazon ECR

### Customizing Unity Version

You can specify a custom Unity version and changeset:

```bash
UNITY_VERSION=2022.3.50f1 \
UNITY_CHANGESET=cc9fd8c8b302 \
./build-and-push.sh
```

#### Finding Unity Version and Changeset

To find the changeset for a specific Unity version:

1. Visit [Unity Download Archive](https://unity.com/releases/editor/archive)
2. Select your version and platform
3. The download URL contains the changeset hash

Example URL: `https://download.unity3d.com/download_unity/bd20d88e54b8/...`
- Version: `6000.0.23f1`
- Changeset: `bd20d88e54b8`

### Build Configuration

Customize the build with environment variables:

```bash
# Unity configuration
UNITY_VERSION=6000.0.23f1                  # Unity Editor version
UNITY_CHANGESET=bd20d88e54b8               # Unity changeset hash
UNITY_HUB_VERSION=3.9.1                    # Unity Hub version

# AWS configuration
AWS_REGION=us-east-1                       # Target AWS region
ECR_REPOSITORY_NAME=unity-teamcity-agent   # ECR repository name
IMAGE_TAG=latest                           # Docker image tag

# Example: Build Unity 2022 LTS
UNITY_VERSION=2022.3.50f1 \
UNITY_CHANGESET=cc9fd8c8b302 \
IMAGE_TAG=unity-2022-lts \
./build-and-push.sh
```

## Using the Image in Terraform

After building and pushing your image, update `../../main.tf` with your ECR image URI:

```hcl
module "teamcity" {
  source = "../../modules/teamcity"

  # ... other configuration ...

  build_farm_config = {
    "unity-builder" = {
      image         = "<YOUR_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/unity-teamcity-agent:latest"
      cpu           = 4096   # 4 vCPU recommended for Unity builds
      memory        = 8192   # 8 GB RAM recommended
      desired_count = 2
      environment = {
        UNITY_LICENSE_SERVER_URL = "http://<license-server-ip>:8080"
      }
    }
  }
}
```

Then apply with Terraform:

```bash
cd ../../  # Back to unity-build-pipeline root
terraform apply
```

## TeamCity Agent Behavior

The agents automatically:
1. Download TeamCity agent binaries from your TeamCity server on first startup
2. Register with the TeamCity server
3. Start accepting build jobs

Configuration is handled via environment variables in the ECS task definition.

## Testing Locally

To test the image locally before deploying:

```bash
# Pull your image from ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

docker pull <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/unity-teamcity-agent:latest

# Run locally (requires TeamCity server URL)
docker run -e SERVER_URL=https://teamcity.yourdomain.com \
  -e AGENT_NAME=local-test \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/unity-teamcity-agent:latest
```

## Advanced Customization

### Adding Additional Unity Modules

Edit `teamcity-unity-build-agent/Dockerfile` to add more modules to the Unity Editor installation:

```dockerfile
RUN xvfb-run --auto-servernum --server-args='-screen 0 640x480x24' \
    unityhub --headless install \
    --version ${UNITY_VERSION} \
    --changeset ${UNITY_CHANGESET} \
    --module linux-il2cpp \
    --module android \
    --module webgl \
    --module ios
```

Available modules: `linux-il2cpp`, `windows-mono`, `mac-mono`, `android`, `ios`, `webgl`, `linux-server`

### Building Multiple Unity Versions

Build and tag images for different Unity versions to support multiple projects:

```bash
# Unity 2022 LTS
UNITY_VERSION=2022.3.50f1 \
UNITY_CHANGESET=cc9fd8c8b302 \
IMAGE_TAG=unity-2022-lts \
./build-and-push.sh

# Unity 6 LTS
UNITY_VERSION=6000.0.23f1 \
UNITY_CHANGESET=bd20d88e54b8 \
IMAGE_TAG=unity-6-lts \
./build-and-push.sh
```

Then reference specific tags in your TeamCity agent configurations.

## Troubleshooting

### Build fails during Unity installation

**Issue:** Unity Hub installation fails or Unity Editor download times out

**Solution:**
- Check your internet connection
- Verify the Unity version and changeset are correct
- Try a different Unity version (some versions may have download issues)
- Check Unity Download Archive for version availability

### ECR push fails

**Issue:** Cannot push image to ECR

**Solution:**
- Verify AWS credentials: `aws sts get-caller-identity`
- Check ECR permissions in your IAM policy
- Ensure you're logged into ECR: `aws ecr get-login-password | docker login ...`

### Unity license activation issues

**Issue:** Unity requires activation in container

**Solution:**
- Unity builds use the Unity License Server for license management
- Ensure `UNITY_LICENSE_SERVER_URL` environment variable is set in TeamCity agent config
- Verify the license server is accessible from agent containers
- Check license server logs for connection issues

### Image size concerns

**Note:** The image is large (~10-15GB) due to Unity Editor installation. This is expected and normal for Unity containerized builds.

## Alternative Approaches

If build time is a critical concern, consider the community-maintained [GameCI project](https://game.ci/) which provides pre-built Unity Docker images. Note that you would still need to add TeamCity agent integration on top of the GameCI Unity images.

## Support

- **Unity Hub Documentation**: https://docs.unity3d.com/hub/manual/index.html
- **TeamCity Agent Documentation**: https://www.jetbrains.com/help/teamcity/build-agent.html
- **CGD Toolkit Issues**: https://github.com/aws-games/cloud-game-development-toolkit/issues
