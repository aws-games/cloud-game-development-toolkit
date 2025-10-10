# Unity + TeamCity Build Agent Docker Image

This Docker image combines GameCI Unity 6 Editor with TeamCity Build Agent for automated Unity builds.

## What's Included

- **Unity 6.0** (6000.0.31f1) via GameCI
- **TeamCity Build Agent** runtime
- **Perforce P4 CLI** for source control
- **Git + Git LFS** for additional VCS support
- **Java 17** for TeamCity agent

## Building the Image

```bash
cd docker/
./build-and-push.sh
```

This will:
1. Create an ECR repository (if needed)
2. Build the Docker image
3. Push to Amazon ECR

## Using in Terraform

After building, update `main.tf`:

```hcl
build_farm_config = {
  "unity-builder" = {
    image         = "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/unity-teamcity-agent:latest"
    cpu           = 4096   # 4 vCPU recommended for Unity
    memory        = 8192   # 8 GB RAM recommended
    desired_count = 2
  }
}
```

Then run `terraform apply`.

## Unity Accelerator

The Unity project is configured to use the Accelerator automatically via `EditorSettings.asset`.

## Next Steps

1. Build and push this image
2. Update `main.tf` with the ECR image URL
3. Run `terraform apply`
4. Configure TeamCity build in the UI
5. Create your first Unity build!
