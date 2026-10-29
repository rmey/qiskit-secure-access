####################################
# IBM Quantum Platform — Qiskit Runtime
#
# Plan:    paygo-standard (Pay-As-You-Go / Standard)
# Limit:   instance_limit_seconds = var.qiskit_limit_seconds (default 600 s ≈ $1,000 USD)
#
# Supported regions: us-east, eu-de
####################################

resource "ibm_resource_instance" "qiskit" {
  name              = var.qiskit_instance_name
  service           = "quantum-computing"
  plan              = "paygo-standard"
  location          = var.region
  resource_group_id = data.ibm_resource_group.rg.id

  parameters = {
    instance_limit_seconds = tostring(var.qiskit_limit_seconds)
  }

  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}
