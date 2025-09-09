# // This is a template file for a basic deployment.
# // Modify the parameters below with actual values

# module "aws-iam-identity-center" {
#   source = "aws-ia/iam-identity-center/aws"

#   // Create desired GROUPS in IAM Identity Center
#   sso_groups = {
#     Admin : {
#       group_name        = "Admin"
#       group_description = "Admin IAM Identity Center Group"
#     },
#     Dev : {
#       group_name        = "Dev"
#       group_description = "Dev IAM Identity Center Group"
#     },
#     QA : {
#       group_name        = "QA"
#       group_description = "QA IAM Identity Center Group"
#     },
#     Audit : {
#       group_name        = "Audit"
#       group_description = "Audit IAM Identity Center Group"
#     },
#   }

#   // Create desired USERS in IAM Identity Center
#   sso_users = {
#     nuzumaki : {
#       group_membership = ["Admin", "Dev", "QA", "Audit"]
#       user_name        = "nuzumaki"
#       given_name       = "Naruto"
#       family_name      = "Uzumaki"
#       email            = "nuzumaki@hiddenleaf.village"
#     },
#     suchiha : {
#       group_membership = ["QA", "Audit"]
#       user_name        = "suchiha"
#       given_name       = "Sasuke"
#       family_name      = "Uchiha"
#       email            = "suchiha@hiddenleaf.village"
#     },
#   }

#   // Create permissions sets backed by AWS managed policies
#   permission_sets = {
#     AdministratorAccess = {
#       description          = "Provides AWS full access permissions.",
#       session_duration     = "PT4H", // how long until session expires - this means 4 hours. max is 12 hours
#       aws_managed_policies = ["arn:aws:iam::aws:policy/AdministratorAccess"]
#       tags                 = { ManagedBy = "Terraform" }
#     },
#     ViewOnlyAccess = {
#       description          = "Provides AWS view only permissions.",
#       session_duration     = "PT3H", // how long until session expires - this means 3 hours. max is 12 hours
#       aws_managed_policies = ["arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"]
#       tags                 = { ManagedBy = "Terraform" }
#     },
#     CustomPermissionAccess = {
#       description          = "Provides CustomPoweruser permissions.",
#       session_duration     = "PT3H", // how long until session expires - this means 3 hours. max is 12 hours
#       aws_managed_policies = [
#         "arn:aws:iam::aws:policy/ReadOnlyAccess",
#         "arn:aws:iam::aws:policy/AmazonS3FullAccess",
#       ]
#       inline_policy        = data.aws_iam_policy_document.CustomPermissionInlinePolicy.json

#       // Only either managed_policy_arn or customer_managed_policy_reference can be specified.
#       // Before using customer_managed_policy_reference, first deploy the policy to the account.
#       // Don't in-place managed_policy_arn to/from customer_managed_policy_reference, delete it once.
#       permissions_boundary = {
#         // managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"

#         customer_managed_policy_reference = {
#           name = "ExamplePermissionsBoundaryPolicy"
#           // path = "/"
#         }
#       }
#       tags                 = { ManagedBy = "Terraform" }
#     },
#   }

#   // Assign users/groups access to accounts with the specified permissions
#   account_assignments = {
#     Admin : {
#       principal_name  = "Admin"                                   # name of the user or group you wish to have access to the account(s)
#       principal_type  = "GROUP"                                   # principal type (user or group) you wish to have access to the account(s)
#       principal_idp   = "INTERNAL"                                # type of Identity Provider you are using. Valid values are "INTERNAL" (using Identity Store) or "EXTERNAL" (using external IdP such as EntraID, Okta, Google, etc.)
#       permission_sets = ["AdministratorAccess", "ViewOnlyAccess"] # permissions the user/group will have in the account(s)
#       account_ids = [                                             # account(s) the group will have access to. Permissions they will have in account are above line
#       "111111111111", // replace with your desired account id
#       "222222222222", // replace with your desired account id
#       ]
#     },
#     Audit : {
#       principal_name  = "Audit"
#       principal_type  = "GROUP"
#       principal_idp   = "INTERNAL"
#       permission_sets = ["ViewOnlyAccess"]
#       account_ids = [
#       "111111111111",
#       "222222222222",
#       ]
#     },
#   }

# }
