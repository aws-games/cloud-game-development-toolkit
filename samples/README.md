# Cloud Game Development Samples


The Terraform configurations contained in this directory demonstrate the use of the modules contained in the **Toolkit**, and integrations with other common AWS workloads and services. Each sample architecture will provide its own documentation and instructions that follows the template below:

#### 1) Predeployment

In the **predeployment** phase the user is instructed to provision or take note of any necessary pre-existing resources. Creating SSL certificates or keypairs, provisioning Amazon Machine Images (AMIs) with Packer, or documenting existing resource IDs and names all fall into this phase.

#### 2) Deployment

In the **deployment** phase the user is instructed to run `terraform apply` on one or more Terraform configurations with the appropriate variables.

#### 3) Postdeployment

Finally, the **postdeployment** phase includes any Ansible playbooks or remote execution instructions for configuring the applications that have been deployed. These may be automated or manual steps.
