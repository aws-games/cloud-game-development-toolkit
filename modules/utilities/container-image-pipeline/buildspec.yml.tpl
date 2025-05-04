version: 0.2

env:
  variables:
    AWS_ACCOUNT_ID: ${aws_account_id}
    TARGET_IMAGE_REPO: ${target_repo}

phases:
  pre_build:
    commands:
%{ if source_image.provider == "ghcr" ~}
      - echo "Logging in to GitHub Container Registry..."
      - SECRET=$(aws secretsmanager get-secret-value --secret-id ${source_image.auth.secret_arn} --query 'SecretString' --output text)
      - echo $SECRET | jq -r '.password' | docker login ghcr.io -u $(echo $SECRET | jq -r '.username') --password-stdin 2>/dev/null
%{ endif ~}
%{ if source_image.provider == "dockerhub" ~}
      - echo "Logging in to Docker Hub..."
      - SECRET=$(aws secretsmanager get-secret-value --secret-id ${source_image.auth.secret_arn} --query 'SecretString' --output text)
      - echo $SECRET | jq -r '.password' | docker login -u $(echo $SECRET | jq -r '.username') --password-stdin
%{ endif ~}
%{ if source_image.provider == "amazon_ecr" ~}
      - echo "Setting up ECR authentication..."
%{ if source_image.auth.role_arn != null ~}
      - CREDENTIALS=$(aws sts assume-role --role-arn ${source_image.auth.role_arn} --role-session-name "ECRPullAccess" --duration-seconds 900)
      - export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.Credentials.AccessKeyId')
      - export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.Credentials.SecretAccessKey')
      - export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.Credentials.SessionToken')
%{ endif ~}
      - aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com
%{ endif ~}
      - echo "Pulling source image..."
      - docker pull ${source_image.image}:${source_image.tag}

  build:
    commands:
      - echo Build started on `date`
      - |
        echo Creating Dockerfile...
        echo "${dockerfile_base64}" | base64 -d > Dockerfile
      - cat Dockerfile
      - echo Building the Docker image...
      - docker build %{ for tag in image_tags } -t $TARGET_IMAGE_REPO:${tag}%{ endfor } .

  post_build:
    commands:
      - echo Build completed on `date`
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com 2>/dev/null
      - echo Pushing the Docker image...
      - docker push --all-tags $TARGET_IMAGE_REPO
