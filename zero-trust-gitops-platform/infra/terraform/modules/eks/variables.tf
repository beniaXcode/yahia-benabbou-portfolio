variable "cluster_name" {
  type = string
}

# No default on purpose: AWS's list of EKS-supported Kubernetes versions
# shifts over time and isn't reachable to check from wherever this is
# planned, so a hardcoded default here would either go stale or be a guess.
# Check AWS's current supported-version list before setting this.
variable "kubernetes_version" {
  description = "An AWS EKS-supported Kubernetes minor version (e.g. \"1.34\") at the time this is applied. No default — check AWS's current list first."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key used for EKS secrets envelope encryption."
  type        = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

# Plain input rather than data "aws_availability_zones": that data source
# makes a real EC2 API call, which would break planning anywhere this
# module's plan needs to run without live AWS access.
variable "availability_zones" {
  description = "Exactly two AZ names to spread public/private subnets across."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "This module's subnet CIDR math assumes exactly two availability zones."
  }
}

# No default, and deliberately not 0.0.0.0/0: BRIEF.md calls for the public
# endpoint's CIDR allowlist to be restricted even in the demo, and
# documented — the caller must supply real, specific ranges.
variable "allowed_public_cidrs" {
  description = "CIDR blocks allowed to reach the EKS public API endpoint. Never 0.0.0.0/0 outside of a genuinely public demo — this is the one knob that turns a private-by-design cluster into an internet-facing one."
  type        = list(string)
}

variable "cluster_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_admin_principal_arns" {
  description = "Map of a static label (e.g. a GitHub Environment name) to the IAM principal ARN granted an EKS access entry with cluster-admin access, instead of the legacy aws-auth ConfigMap. A map, not a list: for_each needs its keys known at plan time, and these ARNs are often still unknown-until-apply."
  type        = map(string)
  default     = {}
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "tags" {
  type    = map(string)
  default = {}
}
