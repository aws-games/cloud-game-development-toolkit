terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.6.0"
    }
    # Required (and configured in providers.tf) because the perforce module uses
    # awscc-native resources. Version matches the lock file already present.
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.98.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
    # Required because the perforce module declares netapp-ontap as a required
    # provider (for its FSxN storage path). This sample does NOT use the
    # netapp-ontap provider directly: the source FSxN volume is created with the
    # AWS-native aws_fsx_ontap_volume resource, and all FlexClone / snapshot
    # operations happen at runtime via the ONTAP REST API from BuildGraph tasks.
    # The provider is configured as a placeholder block in netapp.tf.
    netapp-ontap = {
      source  = "NetApp/netapp-ontap"
      version = "2.3.0"
    }
  }
}
