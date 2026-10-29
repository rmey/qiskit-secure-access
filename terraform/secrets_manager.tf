####################################
# IAM account settings (for auth policy)
####################################

data "ibm_iam_account_settings" "main" {}

####################################
# Lookup existing Secrets Manager
# (active when existing_secrets_manager_name is non-empty)
####################################

data "ibm_resource_instance" "existing_sm" {
  count    = var.existing_secrets_manager_name != "" ? 1 : 0
  name     = var.existing_secrets_manager_name
  service  = "secrets-manager"
  location = var.region
}

####################################
# Create new Secrets Manager
# (active when existing_secrets_manager_name is empty)
####################################

resource "ibm_resource_instance" "new_sm" {
  count             = var.existing_secrets_manager_name == "" ? 1 : 0
  name              = "${var.prefix}-secrets-manager"
  service           = "secrets-manager"
  plan              = var.secrets_manager_plan
  location          = var.region
  resource_group_id = data.ibm_resource_group.rg.id

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

####################################
# Unified Secrets Manager instance ID
####################################

locals {
  sm_instance_id = var.existing_secrets_manager_name != "" ? (
    data.ibm_resource_instance.existing_sm[0].guid
    ) : (
    ibm_resource_instance.new_sm[0].guid
  )
}

####################################
# Secret Group for VPN PKI certs
####################################

resource "ibm_sm_secret_group" "pki_group" {
  instance_id = local.sm_instance_id
  region      = var.region
  name        = "${var.prefix}-vpn-certs"
  description = "Secret group holding VPN server and client certificates."
}

####################################
# IAM Service-to-Service Authorization
# VPN for VPC (is/vpn-server) -> Secrets Manager secret-group (SecretsReader)
# Required so the VPN server can read the certificate from Secrets Manager.
####################################

resource "ibm_iam_authorization_policy" "vpn_to_sm" {
  subject_attributes {
    name  = "accountId"
    value = data.ibm_iam_account_settings.main.account_id
  }
  subject_attributes {
    name  = "serviceName"
    value = "is"
  }
  subject_attributes {
    name  = "resourceType"
    value = "vpn-server"
  }

  roles = ["SecretsReader"]

  resource_attributes {
    name  = "accountId"
    value = data.ibm_iam_account_settings.main.account_id
  }
  resource_attributes {
    name  = "serviceName"
    value = "secrets-manager"
  }
  resource_attributes {
    name  = "resourceType"
    value = "secret-group"
  }
  resource_attributes {
    name  = "resource"
    value = ibm_sm_secret_group.pki_group.secret_group_id
  }
}
