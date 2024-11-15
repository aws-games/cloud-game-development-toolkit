variable "s3_bucket_name" {
  description = "S3 bucket where playbook is stored"
  type        = string

  
}

variable "playbook_file_name" {
  description = "The name of the playbook yaml on s3"
  type = string
}

resource "aws_ssm_document" "ansible_playbook" {
  name          = "Toolkit-AnsiblePlaybook"
  document_type = "Command"
  target_type = "/AWS::EC2::Instance"
  content       = jsonencode({
    schemaVersion = "2.2"
    description   = "Use this document to run Ansible Playbooks on Systems Manager managed instances. For more information, see https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-state-manager-ansible.html."
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
        description    = "(Optional) Additional variables to pass to Ansible at runtime. Enter key/value pairs separated by a space. For example: color=red flavor=cherry"
        default        = "SSM=True"
        displayType    = "textarea"
        allowedPattern = "^$|^\\w+\\=(([^\\s|:();&]+)|('[^|:();&]+'))(\\s+\\w+\\=(([^\\s|:();&]+)|('[^|:();&]+')))*$"
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
            "  echo \"Installing and/or updating required tools: Ansible, wget, unzip ...\" >&2",
            "  if [ -f \"/etc/system-release\" ] ; then",
            "    if grep -q 'Amazon Linux release 2023' /etc/system-release ; then",
            "      sudo dnf install -y ansible wget unzip",
            "    elif grep -q 'Amazon Linux release 2' /etc/system-release ; then",
            "      sudo yum install -y ansible wget unzip",
            "    elif grep -q 'Red Hat Enterprise Linux' /etc/system-release ; then",
            "      sudo dnf install -y ansible wget unzip",
            "    else",
            "      echo \"Unsupported Amazon Linux or RHEL version. Please install Ansible, wget, and unzip manually.\" >&2",
            "      exit 1",
            "    fi",
            "  elif grep -qi ubuntu /etc/issue ; then",
            "    sudo apt-get update",
            "    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ansible wget unzip",
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

resource "aws_ssm_association" "configure_perforce_helix_core" {
  name = aws_ssm_document.ansible_playbook.name
  association_name = "Toolkit-AnsibleAssociation"

  targets {
    key    = "tag:Project"
    values = ["PerforceHelixCore"]
  }
  parameters = {
    SourceType = "S3"
    SourceInfo = jsonencode({
      "path" = "https://s3.amazonaws.com/${var.s3_bucket_name}/${var.playbook_file_name}"
    })
    PlaybookFile = "${var.playbook_file_name}"
  }
}
