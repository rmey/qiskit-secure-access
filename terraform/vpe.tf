####################################
# Locals — Qiskit VPE endpoint CRN
# (region-specific, documented at:
# https://qiskit.qotlabs.org/docs/security/virtual-private-endpoints)
####################################

locals {
  qiskit_endpoint_crns = {
    "us-east" = "crn:v1:bluemix:public:quantum-computing:us-east:::endpoint:private.us-east.quantum.cloud.ibm.com"
    "eu-de"   = "crn:v1:bluemix:public:quantum-computing:eu-de:::endpoint:private.eu-de.quantum.cloud.ibm.com"
  }

  qiskit_endpoint_crn = local.qiskit_endpoint_crns[var.region]
}

####################################
# VPE: IBM Quantum Platform (Qiskit Runtime)
# Binds a reserved IP in each subnet for HA.
####################################

resource "ibm_is_virtual_endpoint_gateway" "qiskit" {
  name           = "${var.prefix}-vpe-qiskit"
  vpc            = ibm_is_vpc.main.id
  resource_group = data.ibm_resource_group.rg.id

  target {
    crn           = local.qiskit_endpoint_crn
    resource_type = "provider_cloud_service"
  }

  ips {
    name   = "${var.prefix}-vpe-qiskit-ip-z1"
    subnet = ibm_is_subnet.zone1.id
  }

  ips {
    name   = "${var.prefix}-vpe-qiskit-ip-z2"
    subnet = ibm_is_subnet.zone2.id
  }

  ips {
    name   = "${var.prefix}-vpe-qiskit-ip-z3"
    subnet = ibm_is_subnet.zone3.id
  }

  depends_on = [ibm_resource_instance.qiskit]
}

####################################
# VPE: IBM Cloud IAM
# Enables private connectivity to the
# IAM token endpoint from within the VPC.
####################################

resource "ibm_is_virtual_endpoint_gateway" "iam" {
  name           = "${var.prefix}-vpe-iam"
  vpc            = ibm_is_vpc.main.id
  resource_group = data.ibm_resource_group.rg.id

  target {
    crn           = "crn:v1:bluemix:public:iam-svcs:global:::endpoint:private.iam.cloud.ibm.com"
    resource_type = "provider_cloud_service"
  }

  ips {
    name   = "${var.prefix}-vpe-iam-ip-z1"
    subnet = ibm_is_subnet.zone1.id
  }

  ips {
    name   = "${var.prefix}-vpe-iam-ip-z2"
    subnet = ibm_is_subnet.zone2.id
  }

  ips {
    name   = "${var.prefix}-vpe-iam-ip-z3"
    subnet = ibm_is_subnet.zone3.id
  }
}
