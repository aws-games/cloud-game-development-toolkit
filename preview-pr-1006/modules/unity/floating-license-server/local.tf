locals {

  # Boolean determining if the ENI was provided by the user (true) or created through the script (false)
  eni_provided = var.existing_eni_id != null

  # Gets the ENI ID whether it's new or existing
  eni_id = local.eni_provided ? data.aws_network_interface.existing_eni[0].id : aws_network_interface.unity_license_server_eni[0].id

  # Unity License Server dashboard
  # Will hold the ARN of the Secrets Manager secrets containing the password, whether it was provided by user or created through the flow
  admin_password_arn = var.unity_license_server_admin_password_arn == null ? awscc_secretsmanager_secret.admin_password_arn[0].secret_id : var.unity_license_server_admin_password_arn
}
