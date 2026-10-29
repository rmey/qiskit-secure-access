####################################
# Resource Group
####################################

data "ibm_resource_group" "rg" {
  name = var.resource_group_name
}

####################################
# VPC
####################################

resource "ibm_is_vpc" "main" {
  name                      = "${var.prefix}-vpc"
  resource_group            = data.ibm_resource_group.rg.id
  address_prefix_management = "manual"
}

####################################
# Address Prefixes (one per zone)
####################################

resource "ibm_is_vpc_address_prefix" "zone1" {
  name = "${var.prefix}-prefix-zone1"
  zone = "${var.region}-1"
  vpc  = ibm_is_vpc.main.id
  cidr = var.zone1_cidr
}

resource "ibm_is_vpc_address_prefix" "zone2" {
  name = "${var.prefix}-prefix-zone2"
  zone = "${var.region}-2"
  vpc  = ibm_is_vpc.main.id
  cidr = var.zone2_cidr
}

resource "ibm_is_vpc_address_prefix" "zone3" {
  name = "${var.prefix}-prefix-zone3"
  zone = "${var.region}-3"
  vpc  = ibm_is_vpc.main.id
  cidr = var.zone3_cidr
}

####################################
# Subnets (one per zone)
####################################

resource "ibm_is_subnet" "zone1" {
  name            = "${var.prefix}-subnet-1"
  vpc             = ibm_is_vpc.main.id
  zone            = "${var.region}-1"
  ipv4_cidr_block = var.zone1_cidr
  resource_group  = data.ibm_resource_group.rg.id

  depends_on = [ibm_is_vpc_address_prefix.zone1]
}

resource "ibm_is_subnet" "zone2" {
  name            = "${var.prefix}-subnet-2"
  vpc             = ibm_is_vpc.main.id
  zone            = "${var.region}-2"
  ipv4_cidr_block = var.zone2_cidr
  resource_group  = data.ibm_resource_group.rg.id

  depends_on = [ibm_is_vpc_address_prefix.zone2]
}

resource "ibm_is_subnet" "zone3" {
  name            = "${var.prefix}-subnet-3"
  vpc             = ibm_is_vpc.main.id
  zone            = "${var.region}-3"
  ipv4_cidr_block = var.zone3_cidr
  resource_group  = data.ibm_resource_group.rg.id

  depends_on = [ibm_is_vpc_address_prefix.zone3]
}

