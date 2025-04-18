version: 0.2

env:
  variables:
    AWS_ACCOUNT_ID: ${aws_account_id}
    SOURCE_IMAGE_URL: ${source_image}
    GITHUB_TOKEN_SECRET_ARN: ${github_token_secret_arn}
    TARGET_IMAGE_REPO: ${target_repo}

phases:
  pre_build:
    commands:
      - echo Logging in to GHCR...
      - SECRET=$(aws secretsmanager get-secret-value --secret-id $GITHUB_TOKEN_SECRET_ARN --query 'SecretString' --output text)
      - echo $SECRET | jq -r '.password' | docker login ghcr.io -u $(echo $SECRET | jq -r '.username') --password-stdin 2>/dev/null
      - echo Pulling the base image from GHCR...
      - docker pull $SOURCE_IMAGE_URL

  build:
    commands:
      - echo Build started on `date`
      - echo Creating Dockerfile...
      - |
        cat <<DOCKERFILE > Dockerfile
        FROM $SOURCE_IMAGE_URL
        ENV MY_TEST_VAR=HelloWorld
        RUN echo $MY_TEST_VAR
        DOCKERFILE
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
