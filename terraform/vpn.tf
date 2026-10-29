####################################
# Client-to-Site VPN Server
#
# Uses certificate-based authentication:
#   - certificate_crn: the VPN server's own certificate (from SM)
#   - client_ca_crn:   the CA cert the server uses to verify clients
#     (same CA signs both server and client certs in this setup)
####################################

resource "ibm_is_vpn_server" "main" {
  name = "${var.prefix}-vpn-server"

  # Server TLS certificate (stored in Secrets Manager)
  certificate_crn = ibm_sm_imported_certificate.server_cert.crn

  # Certificate-based client authentication
  client_authentication {
    method        = "certificate"
    client_ca_crn = ibm_sm_imported_certificate.server_cert.crn
  }

  # IP pool assigned to connecting VPN clients
  client_ip_pool = var.vpn_client_ip_pool

  # IBM Cloud private DNS resolvers pushed to VPN clients
  # 161.26.0.7 and 161.26.0.8 are the IBM Cloud DNS server IPs
  client_dns_server_ips = var.vpn_dns_server_ips

  # Disconnect idle VPN clients after 600 seconds
  client_idle_timeout = 600

  # Split tunnelling: only VPC-bound traffic goes through the VPN
  enable_split_tunneling = true

  # Deploy the VPN server across 2 subnets for HA (IBM Cloud supports up to 2 subnets)
  subnets = [
    ibm_is_subnet.zone1.id,
    ibm_is_subnet.zone2.id,
  ]

  port     = var.vpn_port
  protocol = var.vpn_protocol

  resource_group = data.ibm_resource_group.rg.id
}

####################################
# VPN Routes — steer VPC subnet traffic
# through the VPN tunnel (needed when
# split tunnelling is enabled)
####################################

resource "ibm_is_vpn_server_route" "zone1" {
  vpn_server  = ibm_is_vpn_server.main.id
  name        = "${var.prefix}-route-zone1"
  destination = var.zone1_cidr
  action      = "deliver"
}

resource "ibm_is_vpn_server_route" "zone2" {
  vpn_server  = ibm_is_vpn_server.main.id
  name        = "${var.prefix}-route-zone2"
  destination = var.zone2_cidr
  action      = "deliver"
}

resource "ibm_is_vpn_server_route" "zone3" {
  vpn_server  = ibm_is_vpn_server.main.id
  name        = "${var.prefix}-route-zone3"
  destination = var.zone3_cidr
  action      = "deliver"
}

# Route IBM Cloud private DNS CIDR (161.26.0.0/16) through the VPN tunnel.
# This ensures VPN clients resolve IBM Cloud private hostnames (including
# VPE FQDNs like private.us-east.quantum.cloud.ibm.com) via the IBM DNS
# resolvers pushed via client_dns_server_ips above.
resource "ibm_is_vpn_server_route" "ibm_dns" {
  vpn_server  = ibm_is_vpn_server.main.id
  name        = "${var.prefix}-route-ibm-dns"
  destination = var.vpn_ibm_dns_cidr
  action      = "deliver"
}
