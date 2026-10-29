####################################
# VPC
####################################

output "vpc_id" {
  description = "ID of the provisioned VPC."
  value       = ibm_is_vpc.main.id
}

output "vpc_crn" {
  description = "CRN of the provisioned VPC."
  value       = ibm_is_vpc.main.crn
}

####################################
# Subnets
####################################

output "subnet_ids" {
  description = "List of subnet IDs (zone 1, 2, 3)."
  value = [
    ibm_is_subnet.zone1.id,
    ibm_is_subnet.zone2.id,
    ibm_is_subnet.zone3.id,
  ]
}

####################################
# Secrets Manager
####################################

output "secrets_manager_id" {
  description = "GUID of the Secrets Manager instance (existing or newly created)."
  value       = local.sm_instance_id
}

output "secrets_manager_secret_group_id" {
  description = "ID of the Secrets Manager secret group holding VPN certificates."
  value       = ibm_sm_secret_group.pki_group.secret_group_id
}

####################################
# PKI / Certificates
####################################

output "server_cert_crn" {
  description = "CRN of the imported VPN server certificate in Secrets Manager."
  value       = ibm_sm_imported_certificate.server_cert.crn
  sensitive   = false
}

output "client_cert_crn" {
  description = "CRN of the imported VPN client certificate in Secrets Manager."
  value       = ibm_sm_imported_certificate.client_cert.crn
  sensitive   = false
}

output "pki_output_path" {
  description = "Local directory containing the generated PKI files (ca.crt, server.crt/key, client.crt/key)."
  value       = local.pki_output_dir
}

####################################
# VPN Server
####################################

output "vpn_server_id" {
  description = "ID of the client-to-site VPN server."
  value       = ibm_is_vpn_server.main.id
}

output "vpn_server_hostname" {
  description = "Hostname of the VPN server (use in the OpenVPN client profile)."
  value       = ibm_is_vpn_server.main.hostname
}

output "vpn_server_private_ips" {
  description = "Private IP addresses of the VPN server across all zones."
  value       = ibm_is_vpn_server.main.private_ips
}

####################################
# Qiskit Runtime
####################################

output "qiskit_instance_crn" {
  description = "CRN of the IBM Quantum Platform (Qiskit Runtime) service instance."
  value       = ibm_resource_instance.qiskit.crn
}

output "qiskit_instance_id" {
  description = "GUID of the IBM Quantum Platform service instance."
  value       = ibm_resource_instance.qiskit.guid
}

####################################
# Virtual Private Endpoints
####################################

output "qiskit_vpe_id" {
  description = "ID of the IBM Quantum Platform VPE gateway."
  value       = ibm_is_virtual_endpoint_gateway.qiskit.id
}

output "iam_vpe_id" {
  description = "ID of the IAM VPE gateway."
  value       = ibm_is_virtual_endpoint_gateway.iam.id
}
