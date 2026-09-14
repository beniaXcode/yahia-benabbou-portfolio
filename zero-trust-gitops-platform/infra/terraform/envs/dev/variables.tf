# github_org/github_repo are fixed for this deployment (this is that repo)
# and so get real defaults. Everything below that genuinely can't be known
# in advance — the account being deployed into, which EKS version AWS
# currently supports, which CIDRs should reach the API — has no default:
# supply it yourself (a local, uncommitted *.tfvars, or -var on the CLI).

variable "github_org" {
  type    = string
  default = "beniaXcode"
}

variable "github_repo" {
  type    = string
  default = "yahia-benabbou-portfolio"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "account_id" {
  description = "The AWS account these resources are created in."
  type        = string
}

variable "kubernetes_version" {
  description = "Check AWS's current EKS-supported version list before setting this."
  type        = string
}

variable "availability_zones" {
  type = list(string)
}

variable "allowed_public_cidrs" {
  description = "CIDR blocks allowed to reach the EKS public API endpoint. Never 0.0.0.0/0."
  type        = list(string)
}

variable "deploy_environments" {
  type    = list(string)
  default = ["dev", "staging", "prod"]
}
