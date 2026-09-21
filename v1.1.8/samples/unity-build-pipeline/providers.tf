##########################################
# Providers
##########################################

# Placeholder provider required by Perforce module for FSxN support
# Not used when storage_type = "EBS" (the default)
provider "netapp-ontap" {
  connection_profiles = [
    {
      name     = "null"
      hostname = "null"
      username = "null"
      password = "null"
    }
  ]
}
