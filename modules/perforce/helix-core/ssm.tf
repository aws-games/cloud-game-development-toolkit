# Keep the original variable for backward compatibility
variable "playbook_file_name" {
  description = "The name of the playbook yaml on s3 (legacy variable)"
  type        = string
  default     = "p4_configure_playbook.yml"
}

# Updated to have separate variables for each server type playbook
variable "playbook_file_names" {
  description = "The names of the playbook yaml files for each server type"
  type        = map(string)
  default     = {
    commit  = "p4_configure_commit_playbook.yml"
    replica = "p4_configure_replica_playbook.yml"
    edge    = "p4_configure_edge_playbook.yml"
  }
}

# Updated to include local paths for each playbook - using the correct base path
locals {
  # Use the same base directory as the original playbook_path
  playbook_base_dir = "${path.module}/../../../assets/ansible-playbooks/perforce/helix-core"
  
  playbook_paths = {
    commit  = "${local.playbook_base_dir}/${var.playbook_file_names.commit}"
    replica = "${local.playbook_base_dir}/${var.playbook_file_names.replica}"
    edge    = "${local.playbook_base_dir}/${var.playbook_file_names.edge}"
  }
}

resource "aws_s3_bucket" "ansible_bucket" {
  bucket        = local.bucket_name
  force_destroy = true
}

# Updated to create S3 objects for each playbook
resource "aws_s3_object" "playbooks" {
  for_each = var.playbook_file_names

  bucket = aws_s3_bucket.ansible_bucket.id
  key    = each.value
  source = local.playbook_paths[each.key]
  etag   = filemd5(local.playbook_paths[each.key])
}

resource "aws_ssm_document" "ansible_playbook" {
  name          = "Toolkit-AnsiblePlaybook"
  document_type = "Command"
  target_type   = "/AWS::EC2::Instance"
  content       = jsonencode({
    schemaVersion = "2.2"
    description   = "Use this document to run Ansible Playbooks on Systems Manager managed instances. For more information, see https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-state-manager-ansible.html however this document is modified updated version of the original AWS document."
    parameters = {
      SourceType = {
        description   = "(Optional) Specify the source type."
        type          = "String"
        allowedValues = ["GitHub", "S3"]
      }
      SourceInfo = {
        description  = "(Optional) Specify the information required to access the resource from the specified source type. If source type is GitHub, then you can specify any of the following: 'owner', 'repository', 'path', 'getOptions', 'tokenInfo'. Example GitHub parameters: {\"owner\":\"awslabs\",\"repository\":\"amazon-ssm\",\"path\":\"Compliance/InSpec/PortCheck\",\"getOptions\":\"branch:master\"}. If source type is S3, then you can specify 'path'. Important: If you specify S3, then the IAM instance profile on your managed instances must be configured with read access to Amazon S3."
        type         = "StringMap"
        displayType  = "textarea"
        default      = {}
      }
      InstallDependencies = {
        type          = "String"
        description   = "(Required) If set to True, Systems Manager installs Ansible and its dependencies, including Python, from the PyPI repo. If set to False, then verify that Ansible and its dependencies are installed on the target instances. If they aren't, the SSM document fails to run."
        allowedValues = ["True", "False"]
        default       = "True"
      }
      PlaybookFile = {
        type           = "String"
        description    = "(Optional) The Playbook file to run (including relative path). If the main Playbook file is located in the ./automation directory, then specify automation/playbook.yml."
        default        = "hello-world-playbook.yml"
        allowedPattern = "[(a-z_A-Z0-9\\-\\.)/]+(.yml|.yaml)$"
      }
      ExtraVariables = {
        type           = "String"
        description    = "(Optional) Additional variables to pass to Ansible at runtime. Enter key/value pairs separated by a space. For example: color=red flavor=cherry arn='arn:aws:service:region:account:resource'"
        default        = "SSM=True"
        displayType    = "textarea"
        allowedPattern = "^$|^\\w+\\=(([^\\s;&]+)|('[^;&]+'))(\\s+\\w+\\=(([^\\s;&]+)|('[^;&]+')))*$"
      }
      Check = {
        type          = "String"
        description   = "(Optional) Use this parameter to run a check of the Ansible execution. The system doesn't make any changes to your systems. Instead, any module that supports check mode reports the changes it would make rather than making them. Modules that don't support check mode take no action and don't report changes that would be made."
        allowedValues = ["True", "False"]
        default       = "False"
      }
      Verbose = {
        type          = "String"
        description   = "(Optional) Set the verbosity level for logging Playbook executions. Specify -v for low verbosity, -vv or –vvv for medium verbosity, and -vvvv for debug level."
        allowedValues = ["-v", "-vv", "-vvv", "-vvvv"]
        default       = "-v"
      }
      TimeoutSeconds = {
        type        = "String"
        description = "(Optional) The time in seconds for a command to be completed before it is considered to have failed."
        default     = "3600"
      }
    }
    mainSteps = [
      {
        action = "aws:downloadContent"
        name   = "downloadContent"
        inputs = {
          SourceType = "{{ SourceType }}"
          SourceInfo = "{{ SourceInfo }}"
        }
      },
      {
        action = "aws:runShellScript"
        name   = "runShellScript"
        inputs = {
          timeoutSeconds = "{{ TimeoutSeconds }}"
          runCommand     = [
            "#!/bin/bash",
            "if [[ \"{{InstallDependencies}}\" == True ]] ; then",
            "  echo \"Installing and/or updating required tools: Ansible, wget, unzip, python libraries boto3 and sendmail ...\" >&2",
            "  if [ -f \"/etc/system-release\" ] ; then",
            "    if grep -q 'Amazon Linux release 2023' /etc/system-release ; then",
            "      sudo dnf install -y ansible wget unzip python3-pip cronie sendmail s-nail && pip3 install --user boto3",
            "    elif grep -q 'Amazon Linux release 2' /etc/system-release ; then",
            "      sudo yum install -y ansible wget unzip python3-pip && pip3 install --user boto3",
            "    elif grep -q 'Red Hat Enterprise Linux' /etc/system-release ; then",
            "      sudo dnf install -y ansible wget unzip python3-pip && pip3 install --user boto3",
            "    else",
            "      echo \"Unsupported Amazon Linux or RHEL version. Please install Ansible, wget, and unzip manually.\" >&2",
            "      exit 1",
            "    fi",
            "  elif grep -qi ubuntu /etc/issue ; then",
            "    sudo apt-get update",
            "    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ansible wget unzip python3-pip",
            "    pip3 install --user boto3",
            "  else",
            "    echo \"Unsupported operating system. Please install Ansible, wget, and unzip manually.\" >&2",
            "    exit 1",
            "  fi",
            "fi",
            "echo \"Running Ansible in $(pwd)\"",
            "for zip in $(find -iname '*.zip'); do",
            "  unzip -o $zip",
            "done",
            "PlaybookFile=\"{{PlaybookFile}}\"",
            "if [ ! -f \"$${PlaybookFile}\" ] ; then",
            "  echo \"The specified Playbook file doesn't exist in the downloaded bundle. Please review the relative path and file name.\" >&2",
            "  exit 2",
            "fi",
            "PYTHON_INTERPRETER=$(which python3)",
            "if [[ \"{{Check}}\" == True ]] ; then",
            "  ansible-playbook -i \"localhost,\" --check -c local -e \"ansible_python_interpreter=$${PYTHON_INTERPRETER}\" -e \"{{ExtraVariables}}\" \"{{Verbose}}\" \"$${PlaybookFile}\"",
            "else",
            "  ansible-playbook -i \"localhost,\" -c local -e \"ansible_python_interpreter=$${PYTHON_INTERPRETER}\" -e \"{{ExtraVariables}}\" \"{{Verbose}}\" \"$${PlaybookFile}\"",
            "fi"
          ]
        }
      }
    ]
  })
}

# Updated to create separate associations for each server type
resource "aws_ssm_association" "playbook_associations" {
  for_each = var.playbook_file_names

  name             = aws_ssm_document.ansible_playbook.name
  association_name = "Toolkit-AnsibleAssociation-${each.key}"

  targets {
    key    = "tag:ServerType"
    values = [local.p4_server_type_tags[each.key].ServerType]  # Properly capitalized ServerType values
  }

  parameters = {
    SourceType = "S3"
    SourceInfo = jsonencode({
      "path" = "https://s3.amazonaws.com/${aws_s3_bucket.ansible_bucket.id}/${each.value}"
    })
    PlaybookFile    = each.value
    ExtraVariables  = "PROJECT_PREFIX=${var.project_prefix} ENVIRONMENT=${var.environment} p4d_admin_username_secret_id='${local.helix_core_super_user_username_secret_arn}' p4d_admin_pass_secret_id='${local.helix_core_super_user_password_secret_arn}'"
  }

  depends_on = [aws_s3_object.playbooks]

  output_location {
    s3_bucket_name = aws_s3_bucket.ansible_bucket.id
    s3_key_prefix  = "ssm-output/${each.key}/"
  }
}