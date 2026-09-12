# The OCI half of the multi-cloud landing zone — stood up and validated before any workload
# actually migrated onto it.

terraform {
  required_version = ">= 1.5"
  required_providers {
    oci = { source = "oracle/oci" }
  }
}

variable "compartment_id" {
  type = string
}

resource "oci_core_vcn" "landing_zone" {
  compartment_id = var.compartment_id
  cidr_blocks    = ["10.20.0.0/16"]
  display_name   = "banking-landing-zone"
  dns_label      = "bankinglz"
}

resource "oci_core_subnet" "app_tier" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.landing_zone.id
  cidr_block                 = "10.20.1.0/24"
  display_name               = "app-tier-private"
  prohibit_public_ip_on_vnic = true
}

resource "oci_core_subnet" "data_tier" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.landing_zone.id
  cidr_block                 = "10.20.2.0/24"
  display_name               = "data-tier-private"
  prohibit_public_ip_on_vnic = true
}

resource "oci_containerengine_cluster" "oke" {
  compartment_id     = var.compartment_id
  kubernetes_version = "v1.29.1"
  name               = "banking-oke-cluster"
  vcn_id             = oci_core_vcn.landing_zone.id

  options {
    service_lb_subnet_ids = [oci_core_subnet.app_tier.id]
  }
}

resource "oci_identity_policy" "least_privilege_app_tier" {
  compartment_id = var.compartment_id
  name           = "app-tier-least-privilege"
  description    = "Restricts app-tier compute to only the resources it needs"
  statements = [
    "Allow dynamic-group AppTierInstances to use secret-family in compartment id ${var.compartment_id}",
    "Allow dynamic-group AppTierInstances to read objects in compartment id ${var.compartment_id} where target.bucket.name='app-config'"
  ]
}
