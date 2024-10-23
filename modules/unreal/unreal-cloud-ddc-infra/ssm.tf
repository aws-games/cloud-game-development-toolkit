################################################################################
# SSM
################################################################################

resource "aws_ssm_document" "config_scylla" {
  name            = "${var.name}-scylla-run-command"
  document_type   = "Command"
  document_format = "YAML"

  content = yamlencode({
    "schemaVersion" : "2.2",
    "description" : "Config Scylla",
    "mainSteps" : [
      {
        "action" : "aws:runShellScript",
        "name" : "ConfigScylla",
        "inputs" : {
          "runCommand" : [
            "sudo apt-get update && sudo apt-get -y upgrade",
            "sudo sed -i 's/- seeds: test-ip.*$/- seeds: ${aws_instance.scylla_ec2_instance[0].private_ip} /g' /etc/scylla/scylla.yaml",
            "echo \"Config of /etc/scylla/scylla.yaml Done\"",
            "sudo reboot now"
          ]
        }
      }
    ]
    }
  )
}

resource "aws_ssm_association" "scylla_config_association" {
  name = aws_ssm_document.config_scylla.name

  targets {
    key    = "tag:Name"
    values = ["${var.name}-scylla-db"]
  }
}
