# Terraform Actions ignore depends_on between action-triggered resources

## Title
Terraform Actions ignore depends_on between action-triggered resources, causing parallel execution instead of sequential

Thank you for opening an issue.
The hashicorp/terraform issue tracker is reserved for bug reports relating to the core Terraform CLI application and configuration language.

## Terraform Version
```
Terraform v1.10.3
on darwin_arm64
+ provider registry.terraform.io/hashicorp/aws v5.82.2
```

## Terraform Configuration Files

```terraform
# This configuration demonstrates the bug where two terraform_data resources
# with actions run in parallel despite depends_on relationship

resource "terraform_data" "first_action" {
  input = {
    timestamp = timestamp()
  }

  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.first]
    }
  }
}

resource "terraform_data" "second_action" {
  input = {
    timestamp = timestamp()
  }

  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.second]
    }
  }

  # This depends_on is IGNORED - both actions start simultaneously
  depends_on = [terraform_data.first_action]
}

action "aws_codebuild_start_build" "first" {
  config {
    project_name = "first-project"
  }
}

action "aws_codebuild_start_build" "second" {
  config {
    project_name = "second-project"
  }
}
```

## Debug Output
Debug output shows both actions starting simultaneously despite depends_on:
```
Action started: terraform_data.second_action (triggered by terraform_data.second_action)
Action started: terraform_data.first_action (triggered by terraform_data.first_action)
```

## Expected Behavior
The second terraform_data resource should wait for the first terraform_data resource to complete (including its action) before starting its own action, due to the `depends_on = [terraform_data.first_action]` declaration.

Expected sequence:
1. first_action starts and completes
2. second_action starts after first_action completes

## Actual Behavior
Both terraform_data resources with actions start simultaneously, completely ignoring the `depends_on` relationship. The actions execute in parallel rather than sequentially.

Actual behavior:
1. first_action and second_action start simultaneously
2. Both actions run in parallel

## Steps to Reproduce
1. `terraform init`
2. `terraform apply`
3. Observe that both actions start at the same time in the output

## Additional Context

**Key Discovery:** This bug only affects terraform_data resources that both have actions. When a regular resource depends on a terraform_data with an action, the dependency works correctly:

```terraform
# THIS WORKS - regular resource waits for action to complete
resource "terraform_data" "build_trigger" {
  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.build]
    }
  }
}

resource "aws_s3_object" "artifact" {
  # This correctly waits for build_trigger action to complete
  depends_on = [terraform_data.build_trigger]
}
```

**But this DOESN'T work:**
```terraform
# THIS FAILS - both actions run in parallel
resource "terraform_data" "first" {
  lifecycle { action_trigger { ... } }
}

resource "terraform_data" "second" {
  depends_on = [terraform_data.first]  # IGNORED!
  lifecycle { action_trigger { ... } }
}
```

The dependency graph appears to work correctly for regular resources but breaks down when both resources have action triggers.

## References
This appears to be a fundamental issue with how Terraform Actions handle dependencies between action-triggered resources during the same apply operation.

## Generative AI / LLM assisted development?
Amazon Q Developer was used to help analyze and document this issue.