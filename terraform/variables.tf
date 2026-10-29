####################################
# Authentication & Region
####################################

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key used to authenticate with the IBM Cloud platform."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "IBM Cloud region to deploy all resources (e.g. us-east, eu-de)."
  type        = string
  default     = "us-east"
}

####################################
# Resource Organisation
####################################

variable "resource_group_name" {
  description = "Name of the existing IBM Cloud resource group to deploy resources into."
  type        = string
  default     = "default"
}

variable "prefix" {
  description = "Short prefix prepended to every resource name to ensure uniqueness."
  type        = string
  default     = "qsk"
}

####################################
# VPC Networking
####################################

variable "vpc_cidr" {
  description = "Informational CIDR block representing the overall VPC address space."
  type        = string
  default     = "10.0.0.0/16"
}

variable "zone1_cidr" {
  description = "CIDR block for the subnet in zone 1 (e.g. us-east-1)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "zone2_cidr" {
  description = "CIDR block for the subnet in zone 2 (e.g. us-east-2)."
  type        = string
  default     = "10.0.2.0/24"
}

variable "zone3_cidr" {
  description = "CIDR block for the subnet in zone 3 (e.g. us-east-3)."
  type        = string
  default     = "10.0.3.0/24"
}

####################################
# Client-to-Site VPN
####################################

variable "vpn_client_ip_pool" {
  description = "CIDR block for the VPN client IP pool. Must not overlap VPC subnets."
  type        = string
  default     = "172.16.0.0/22"
}

variable "vpn_port" {
  description = "UDP/TCP port the VPN server listens on."
  type        = number
  default     = 443
}

variable "vpn_protocol" {
  description = "Protocol used by the VPN server (udp or tcp)."
  type        = string
  default     = "udp"

  validation {
    condition     = contains(["udp", "tcp"], var.vpn_protocol)
    error_message = "vpn_protocol must be 'udp' or 'tcp'."
  }
}

variable "vpn_dns_server_ips" {
  description = "DNS server IP addresses pushed to VPN clients. Defaults to IBM Cloud private DNS resolvers."
  type        = list(string)
  default     = ["161.26.0.7", "161.26.0.8"]
}

variable "vpn_ibm_dns_cidr" {
  description = "CIDR block for IBM Cloud private DNS services. A VPN route for this CIDR ensures clients resolve IBM private hostnames via the tunnel."
  type        = string
  default     = "161.26.0.0/16"
}

####################################
# Secrets Manager
####################################

variable "existing_secrets_manager_name" {
  description = "Name of an existing Secrets Manager instance in the same region. Leave empty to create a new one."
  type        = string
  default     = ""
}

variable "secrets_manager_plan" {
  description = "Plan for a newly created Secrets Manager instance (standard or trial)."
  type        = string
  default     = "trial"

  validation {
    condition     = contains(["standard", "trial"], var.secrets_manager_plan)
    error_message = "secrets_manager_plan must be 'standard' or 'trial'."
  }
}

####################################
# Qiskit Runtime
####################################

variable "qiskit_instance_name" {
  description = "Name for the IBM Quantum Platform (Qiskit Runtime) service instance."
  type        = string
  default     = "qiskit-paygo"
}

variable "qiskit_limit_seconds" {
  description = "QPU cost limit in seconds for the Qiskit Runtime Pay-As-You-Go instance (~$1,000 USD at 600 s)."
  type        = number
  default     = 600
}
