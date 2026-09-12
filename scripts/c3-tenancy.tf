# Onboarding pattern for a tenant organization onto the shared C3 platform — the repeatable
# process built after the first, manual, Oracle-assisted bring-up.

terraform {
  required_version = ">= 1.5"
  required_providers {
    oci = { source = "oracle/oci" }
  }
}

variable "tenant_name" {
  type        = string
  description = "Name of the organization being onboarded"
}

variable "c3_compartment_id" {
  type        = string
  description = "Parent compartment for the shared Compute Cloud@Customer platform"
}

resource "oci_identity_compartment" "tenant" {
  compartment_id = var.c3_compartment_id
  name           = "tenant-${var.tenant_name}"
  description    = "Isolated compartment for ${var.tenant_name}"
}

resource "oci_core_vcn" "tenant_vcn" {
  compartment_id = oci_identity_compartment.tenant.id
  cidr_blocks    = ["192.168.0.0/20"]
  display_name   = "${var.tenant_name}-vcn"
  dns_label      = replace(var.tenant_name, "-", "")
}

resource "oci_identity_policy" "tenant_isolation" {
  compartment_id = var.c3_compartment_id
  name           = "${var.tenant_name}-isolation-policy"
  description    = "Restricts tenant admins to their own compartment only"
  statements = [
    "Allow group ${var.tenant_name}-admins to manage all-resources in compartment id ${oci_identity_compartment.tenant.id}"
  ]
}

output "tenant_compartment_id" {
  value = oci_identity_compartment.tenant.id
}
